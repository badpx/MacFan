#!/usr/bin/env python3
"""Build the static product site for every language MenuGauge ships."""
import argparse
import hashlib
import html
import json
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {
    "en": "English",
    "zh-Hans": "简体中文",
    "zh-Hant": "繁體中文",
    "ja": "日本語",
    "ko": "한국어",
    "hi": "हिन्दी",
    "es": "Español",
    "fr": "Français",
    "bn": "বাংলা",
    "ru": "Русский",
    "pt": "Português",
}
TOKEN = re.compile(r"\{\{\s*([\w.]+)\s*\}\}")
TABLE_KEY = re.compile(r'^        "([^"]+)": \[', re.M)


def catalog(language):
    source = ROOT / "website/locales" / f"{language}.json"
    result = json.loads(source.read_text())
    if not isinstance(result, dict):
        raise ValueError(f"Locale must be an object: {language}")
    return result


def app_languages():
    source = (ROOT / "Sources/MenuGauge/L10n.swift").read_text()
    return set(TABLE_KEY.findall(source))


def release_download(release, tag):
    """Prefer the notarized MenuGauge disk image.

    The GitHub repository is still badpx/MacFan. Releases published before
    the rename are MacFan-<tag>.dmg or .zip; keep accepting those so the
    current release can still build the site.
    """
    prefix = f"https://github.com/badpx/MacFan/releases/download/{tag}/"
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValueError("Release is missing assets")
    names = (
        f"MenuGauge-{tag}.dmg",
        f"MenuGauge-{tag}.zip",
        f"MacFan-{tag}.dmg",
        f"MacFan-{tag}.zip",
    )
    for name in names:
        matches = [item for item in assets if item.get("name") == name]
        if len(matches) > 1:
            raise ValueError(f"Expected at most one {name} in the latest release")
        if len(matches) != 1:
            continue
        download = matches[0].get("browser_download_url", "")
        if not isinstance(download, str) or not download.startswith(prefix) or not download.endswith(name):
            raise ValueError("Unexpected download URL")
        return download
    raise ValueError(
        "Expected MenuGauge-" + tag + ".dmg (preferred), then a MenuGauge zip, "
        "or the older MacFan dmg/zip name, in the latest release"
    )


def privacy_href(base, language):
    if language == "en":
        return f"{base}/privacy.html"
    return f"{base}/privacy.html?lang={language}"


def render_privacy(base, site_url, asset_versions, catalogs):
    """One privacy.html. zh-Hans shows Chinese; every other locale shows English."""
    template = (ROOT / "website/privacy.html").read_text()
    replacements = {
        "_base": base,
        "_canonical": site_url + "/privacy.html",
        "_canonical_zh": site_url + "/privacy.html?lang=zh-Hans",
        "_home_en": base + "/",
        "_home_zh": base + "/zh-Hans/",
        "_style_version": asset_versions["style.css"],
        "_script_version": asset_versions["site.js"],
        "_issues": "https://github.com/badpx/MacFan/issues",
    }
    for prefix, language in (("en", "en"), ("zh", "zh-Hans")):
        for key, value in catalogs[language].items():
            replacements[f"{prefix}.{key}"] = value
    raw = {
        "_languages": "".join(
            f'<option value="{html.escape(privacy_href(base, code), quote=True)}"'
            f'{" selected" if code == "en" else ""}>{label}</option>'
            for code, label in LANGUAGES.items()
        ),
    }

    def replace(match, replacements=replacements, raw=raw):
        key = match.group(1)
        if key not in raw and key not in replacements:
            raise ValueError(f"Missing privacy template value: {key}")
        return raw[key] if key in raw else html.escape(str(replacements[key]), quote=True)

    page = TOKEN.sub(replace, template)
    if "{{" in page or "}}" in page:
        raise ValueError("Unreplaced template token in privacy.html")
    return page


def build(output, base, site_url, release_file):
    if base and (not base.startswith("/") or base.endswith("/") or ".." in base):
        raise ValueError("Base must be empty or an absolute path without a trailing slash")
    if urlparse(site_url).scheme != "https":
        raise ValueError("The canonical site URL must use HTTPS")
    release = json.loads(release_file.read_text())
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("The website must link to a public stable release")
    tag = release.get("tag_name", "")
    # New MenuGauge tags are vX.Y (v1.0 is the first). Older three-part
    # tags, including the MacFan release still named in website/release.json,
    # stay valid so the site can build before that snapshot is replaced.
    if not re.fullmatch(r"v\d+\.\d+(?:\.\d+)?", tag):
        raise ValueError("Unexpected release tag")
    download = release_download(release, tag)
    if release["html_url"] != f"https://github.com/badpx/MacFan/releases/tag/{tag}":
        raise ValueError("Unexpected release URL")

    template = (ROOT / "website/index.template.html").read_text()
    required = {key for key in TOKEN.findall(template) if key.startswith("Website.")}
    catalogs = {language: catalog(language) for language in LANGUAGES}
    if app_languages() != set(LANGUAGES):
        raise ValueError("Website languages must match the tables in L10n.swift")
    expected = set(catalogs["en"])
    if required != expected:
        raise ValueError(f"Template/catalog key mismatch: {sorted(required ^ expected)}")
    for language, values in catalogs.items():
        if set(values) != expected or any(not str(values[key]).strip() for key in expected):
            raise ValueError(f"Incomplete website translations: {language}")

    # Only the generated build directory is replaced; source files are never removed.
    if output.resolve() != (ROOT / "build/website").resolve():
        raise ValueError("Output must be build/website")
    if output.exists():
        shutil.rmtree(output)
    (output / "assets").mkdir(parents=True)
    asset_versions = {}
    for name in ("style.css", "site.js"):
        shutil.copyfile(ROOT / "website" / name, output / "assets" / name)
        asset_versions[name] = hashlib.sha256((output / "assets" / name).read_bytes()).hexdigest()[:12]
    for destination, source in {
        "favicon.png": "website/favicon.png",
        "app-icon.png": "Design/MacFan-UI/MenuGauge-AppIcon.png",
        "preview-light-en.png": "website/preview/preview-light-en.png",
        "preview-dark-en.png": "website/preview/preview-dark-en.png",
        "preview-settings-en.png": "website/preview/preview-settings-en.png",
        "preview-light-zh-Hans.png": "website/preview/preview-light-zh-Hans.png",
        "preview-dark-zh-Hans.png": "website/preview/preview-dark-zh-Hans.png",
        "preview-settings-zh-Hans.png": "website/preview/preview-settings-zh-Hans.png",
        "preview-light-zh-Hant.png": "website/preview/preview-light-zh-Hant.png",
        "preview-dark-zh-Hant.png": "website/preview/preview-dark-zh-Hant.png",
        "preview-settings-zh-Hant.png": "website/preview/preview-settings-zh-Hant.png",
    }.items():
        shutil.copyfile(ROOT / source, output / "assets" / destination)

    def suffix(language):
        return "/" if language == "en" else f"/{language}/"

    for language, values in catalogs.items():
        replacements = dict(values)
        replacements.update({
            "_lang": language,
            "_base": base,
            "_home": base + suffix(language),
            "_canonical": site_url + suffix(language),
            "_site_url": site_url,
            "_download": download,
            "_release": release["html_url"],
            "_version": tag,
            "_privacy_href": privacy_href(base, language),
            "_preview_language": language if language in ("zh-Hans", "zh-Hant") else "en",
            "_style_version": asset_versions["style.css"],
            "_script_version": asset_versions["site.js"],
        })
        raw = {
            "_alternates": "\n  ".join(
                f'<link rel="alternate" hreflang="{code}" href="{html.escape(site_url + suffix(code), quote=True)}">'
                for code in LANGUAGES
            ) + f'\n  <link rel="alternate" hreflang="x-default" href="{html.escape(site_url, quote=True)}/">',
            "_languages": "".join(
                f'<option value="{html.escape(base + suffix(code), quote=True)}"{" selected" if code == language else ""}>{label}</option>'
                for code, label in LANGUAGES.items()
            ),
        }

        def replace(match, replacements=replacements, raw=raw):
            key = match.group(1)
            if key not in raw and key not in replacements:
                raise ValueError(f"Missing template value: {key}")
            return raw[key] if key in raw else html.escape(str(replacements[key]), quote=True)

        page = TOKEN.sub(replace, template)
        if "{{" in page or "}}" in page:
            raise ValueError(f"Unreplaced template token in {language}")
        destination = output if language == "en" else output / language
        destination.mkdir(exist_ok=True)
        (destination / "index.html").write_text(page)
    privacy = render_privacy(base, site_url, asset_versions, catalogs)
    (output / "privacy.html").write_text(privacy)
    urls = "".join(f"<url><loc>{html.escape(site_url + suffix(code))}</loc></url>" for code in LANGUAGES)
    urls += f"<url><loc>{html.escape(site_url + '/privacy.html')}</loc></url>"
    urls += f"<url><loc>{html.escape(site_url + '/privacy.html?lang=zh-Hans')}</loc></url>"
    (output / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{urls}</urlset>\n'
    )
    (output / ".nojekyll").touch()
    print(f"Built {len(LANGUAGES)} languages → {output.relative_to(ROOT)} ({tag})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="/MacFan")
    parser.add_argument("--site-url", default="https://badpx.github.io/MacFan")
    parser.add_argument("--release-json", type=Path, default=ROOT / "website/release.json")
    arguments = parser.parse_args()
    build(ROOT / "build/website", arguments.base, arguments.site_url.rstrip("/"), arguments.release_json)
