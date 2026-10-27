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


PRIVACY_KEYS = (
    "Privacy.title",
    "Privacy.description",
    "Privacy.heading",
    "Privacy.effective",
    "Privacy.intro",
    "Privacy.readsTitle",
    "Privacy.readsBody",
    "Privacy.readsEditions",
    "Privacy.doesNotTitle",
    "Privacy.doesNotBody",
    "Privacy.settingsTitle",
    "Privacy.settingsBody",
    "Privacy.editionsTitle",
    "Privacy.editionsBody",
    "Privacy.siteTitle",
    "Privacy.siteBody",
    "Privacy.contactTitle",
    "Privacy.contactBody",
    "Privacy.issuesLabel",
)
ISSUES_URL = "https://github.com/badpx/MacFan/issues"


def privacy_href(base, language):
    if language == "en":
        return f"{base}/privacy.html"
    return f"{base}/privacy.html?lang={language}"


def privacy_url(site_url, language):
    if language == "en":
        return site_url + "/privacy.html"
    return site_url + "/privacy.html?lang=" + language


def home_href(base, language):
    return base + ("/" if language == "en" else f"/{language}/")


def js_string(value):
    return json.dumps(value, ensure_ascii=False).replace("<", "\\u003c")


def privacy_markup(text, issues_label):
    placeholders = set(re.findall(r"\{([^{}]+)\}", text))
    unknown = placeholders - {"release", "issues"}
    if unknown:
        raise ValueError(f"Unknown privacy placeholder: {sorted(unknown)}")
    escaped = html.escape(text, quote=True)
    escaped = escaped.replace("{release}", "<code>release.json</code>")
    link = (
        f'<a href="{html.escape(ISSUES_URL, quote=True)}">'
        f"{html.escape(issues_label, quote=True)}</a>"
    )
    escaped = escaped.replace("{issues}", link)
    if "{" in escaped or "}" in escaped:
        raise ValueError("Unreplaced privacy placeholder")
    return escaped


def i18n_class(language):
    if not re.fullmatch(r"[a-zA-Z]{2,3}(?:-[a-zA-Z]+)?", language):
        raise ValueError(f"Unexpected language code: {language}")
    return f"i18n i18n-{language}"


def render_privacy(base, site_url, asset_versions, catalogs):
    """One privacy.html. ?lang= selects one of the 11 policies; anything else is English."""
    css = (ROOT / "website/style.css").read_text()
    for code in LANGUAGES:
        needle = f'html[data-policy="{code}"] .i18n:not(.i18n-{code})'
        if needle not in css:
            raise ValueError(f"Privacy CSS does not hide inactive {code}")
    template = (ROOT / "website/privacy.html").read_text()
    brands = []
    footer_brands = []
    nav_features = []
    nav_how = []
    skip = []
    language_labels = []
    footer_blurbs = []
    privacy_labels = []
    feedback_labels = []
    articles = []
    nav_labels = []
    titles = {}
    descriptions = {}
    english_heading = catalogs["en"]["Privacy.heading"]
    for language, values in catalogs.items():
        missing = [key for key in PRIVACY_KEYS if not str(values.get(key, "")).strip()]
        if missing:
            raise ValueError(f"Incomplete privacy translation: {language} {missing}")
        if language != "en" and values["Privacy.heading"] == english_heading:
            raise ValueError(f"Privacy heading still falls back to English: {language}")
        for key in ("Privacy.doesNotBody", "Privacy.siteBody"):
            if "{release}" not in values[key]:
                raise ValueError(f"{language} {key} must mention {{release}}")
        if values["Privacy.contactBody"].count("{issues}") != 1:
            raise ValueError(f"{language} contact must link {{issues}} once")
        klass = i18n_class(language)
        home = home_href(base, language)
        icon = (
            f'<span class="app-icon"><img src="{html.escape(base, quote=True)}/assets/app-icon.png" '
            'width="40" height="40" alt=""></span>'
        )
        brands.append(
            f'<a class="brand {klass}" href="{html.escape(home, quote=True)}" aria-label="MenuGauge">'
            f"{icon}<span>MenuGauge<span class=\"brand-period\">.</span></span></a>"
        )
        footer_brands.append(
            f'<a class="footer-brand {klass}" href="{html.escape(home, quote=True)}">'
            "MenuGauge<span>.</span></a>"
        )
        nav_features.append(
            f'<a class="{klass}" href="{html.escape(home, quote=True)}#features">'
            f"{html.escape(values['Website.features'])}</a>"
        )
        nav_how.append(
            f'<a class="{klass}" href="{html.escape(home, quote=True)}#how-it-works">'
            f"{html.escape(values['Website.how'])}</a>"
        )
        skip.append(f'<span class="{klass}">{html.escape(values["Website.skip"])}</span>')
        language_labels.append(
            f'<span class="sr-only {klass}">{html.escape(values["Website.language"])}</span>'
        )
        footer_blurbs.append(f'<p class="{klass}">{html.escape(values["Website.footer"])}</p>')
        privacy_labels.append(f'<span class="{klass}">{html.escape(values["Website.privacy"])}</span>')
        feedback_labels.append(f'<span class="{klass}">{html.escape(values["Website.feedback"])}</span>')
        nav_labels.append(
            f'data-label-{language}="{html.escape(values["Website.navigation"], quote=True)}"'
        )
        issues_label = values["Privacy.issuesLabel"]
        issues = privacy_markup(values["Privacy.contactBody"], issues_label)

        def paragraph(key, values=values, issues_label=issues_label):
            return privacy_markup(values[key], issues_label)
        articles.append(
            f'<article class="privacy-page wrap {klass}" lang="{html.escape(language, quote=True)}">'
            '<p class="eyebrow">MenuGauge</p>'
            f"<h1>{html.escape(values['Privacy.heading'])}</h1>"
            f'<p class="effective">{html.escape(values["Privacy.effective"])}</p>'
            f"<p>{paragraph('Privacy.intro')}</p>"
            f"<h2>{html.escape(values['Privacy.readsTitle'])}</h2>"
            f"<p>{paragraph('Privacy.readsBody')}</p>"
            f"<p>{paragraph('Privacy.readsEditions')}</p>"
            f"<h2>{html.escape(values['Privacy.doesNotTitle'])}</h2>"
            f"<p>{paragraph('Privacy.doesNotBody')}</p>"
            f"<h2>{html.escape(values['Privacy.settingsTitle'])}</h2>"
            f"<p>{paragraph('Privacy.settingsBody')}</p>"
            f"<h2>{html.escape(values['Privacy.editionsTitle'])}</h2>"
            f"<p>{paragraph('Privacy.editionsBody')}</p>"
            f"<h2>{html.escape(values['Privacy.siteTitle'])}</h2>"
            f"<p>{paragraph('Privacy.siteBody')}</p>"
            f"<h2>{html.escape(values['Privacy.contactTitle'])}</h2>"
            f"<p>{issues}</p>"
            "</article>"
        )
        titles[language] = values["Privacy.title"]
        descriptions[language] = values["Privacy.description"]

    replacements = {
        "_base": base,
        "_canonical": site_url + "/privacy.html",
        "_style_version": asset_versions["style.css"],
        "_script_version": asset_versions["site.js"],
        "_issues": ISSUES_URL,
        "en.Privacy.title": catalogs["en"]["Privacy.title"],
        "en.Privacy.description": catalogs["en"]["Privacy.description"],
        "en.Website.navigation": catalogs["en"]["Website.navigation"],
    }
    raw = {
        "_languages": "".join(
            f'<option value="{html.escape(privacy_href(base, code), quote=True)}"'
            f'{" selected" if code == "en" else ""}>{html.escape(label)}</option>'
            for code, label in LANGUAGES.items()
        ),
        "_alternates": "\n  ".join(
            f'<link rel="alternate" hreflang="{code}" href="{html.escape(privacy_url(site_url, code), quote=True)}">'
            for code in LANGUAGES
        ) + f'\n  <link rel="alternate" hreflang="x-default" href="{html.escape(site_url + "/privacy.html", quote=True)}">',
        "_lang_json": js_string(list(LANGUAGES)),
        "_titles_json": js_string(titles),
        "_descriptions_json": js_string(descriptions),
        "_skip": "".join(skip),
        "_brands": "\n    ".join(brands),
        "_nav_labels": " ".join(nav_labels),
        "_nav_features": "\n      ".join(nav_features),
        "_nav_how": "\n      ".join(nav_how),
        "_language_labels": "".join(language_labels),
        "_articles": "\n    ".join(articles),
        "_footer_brands": "\n    ".join(footer_brands),
        "_footer_blurbs": "\n    ".join(footer_blurbs),
        "_privacy_labels": "".join(privacy_labels),
        "_feedback_labels": "".join(feedback_labels),
    }

    def replace(match, replacements=replacements, raw=raw):
        key = match.group(1)
        if key not in raw and key not in replacements:
            raise ValueError(f"Missing privacy template value: {key}")
        return raw[key] if key in raw else html.escape(str(replacements[key]), quote=True)

    page = TOKEN.sub(replace, template)
    if "{{" in page or "}}" in page:
        raise ValueError("Unreplaced template token in privacy.html")
    if page.count("<article") != len(LANGUAGES):
        raise ValueError("Privacy page must contain one article per language")
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
    website_keys = {key for key in expected if key.startswith("Website.")}
    privacy_keys = {key for key in expected if key.startswith("Privacy.")}
    other_keys = expected - website_keys - privacy_keys
    if other_keys:
        raise ValueError(f"Unexpected locale keys: {sorted(other_keys)}")
    if required != website_keys:
        raise ValueError(f"Template/catalog key mismatch: {sorted(required ^ website_keys)}")
    if privacy_keys != set(PRIVACY_KEYS):
        raise ValueError(f"Privacy key mismatch: {sorted(privacy_keys ^ set(PRIVACY_KEYS))}")
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
    urls += "".join(
        f"<url><loc>{html.escape(privacy_url(site_url, code))}</loc></url>" for code in LANGUAGES
    )
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
