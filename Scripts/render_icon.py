#!/usr/bin/env python3
"""Rasterize the MenuGauge app icon without a Swift toolchain.

Geometry matches Scripts/generate_icon.swift. On a Mac, prefer that script
plus iconutil; this one also packs Resources/AppIcon.icns.
"""
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CANVAS = 1024
TILE_ORIGIN = 96
TILE_SIDE = 832
TILE_RADIUS = 186
TEAL = (0x12, 0x90, 0x7A)
DEEP = (0x05, 0x50, 0x5C)
ARC_START = 190.0
ARC_SWEEP = 200.0
TOP_GAP = 18.0
NEEDLE_DEGREES = 37.0
GLYPH_WIDTH_RATIO = 0.63

ICONSET = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
ICNS_TYPES = [
    (16, b"icp4"),
    (32, b"icp5"),
    (32, b"ic11"),
    (64, b"icp6"),
    (64, b"ic12"),
    (128, b"ic07"),
    (256, b"ic08"),
    (256, b"ic13"),
    (512, b"ic09"),
    (512, b"ic14"),
    (1024, b"ic10"),
]


def band_ratio(pixel_size):
    if pixel_size <= 16:
        return 0.40
    if pixel_size <= 32:
        return 0.34
    if pixel_size <= 64:
        return 0.28
    return 0.23


def pil_angle(math_degrees):
    return (-math_degrees) % 360.0


def lerp_color(t):
    t = float(np.clip(t, 0, 1))
    return tuple(round(a + (b - a) * t) for a, b in zip(TEAL, DEEP))


def rounded_mask(size, full_bleed):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if full_bleed:
        inset = 0
        radius = round(TILE_RADIUS * size / TILE_SIDE)
    else:
        inset = round(TILE_ORIGIN * size / CANVAS)
        radius = round(TILE_RADIUS * (size - 2 * inset) / TILE_SIDE)
    draw.rounded_rectangle([inset, inset, size - inset - 1, size - inset - 1], radius=radius, fill=255)
    return mask, inset


def gradient(size):
    yy, xx = np.mgrid[0:size, 0:size]
    t = (xx + yy) / (2 * (size - 1))
    start = np.array(TEAL, dtype=np.float32)
    end = np.array(DEEP, dtype=np.float32)
    rgb = start * (1 - t)[..., None] + end * t[..., None]
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


def draw_arc(draw, center, radius, math_start, math_end, width, fill):
    """Clockwise math arc. PIL angles increase clockwise from east."""
    box = [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius]
    draw.arc(box, start=pil_angle(math_start), end=pil_angle(math_end), fill=fill, width=max(1, round(width)))


def endpoint(center, radius, math_degrees):
    radians = math.radians(math_degrees)
    return (center[0] + radius * math.cos(radians), center[1] - radius * math.sin(radians))


def cap(draw, center, radius, math_degrees, width, fill):
    point = endpoint(center, radius, math_degrees)
    r = width / 2
    draw.ellipse([point[0] - r, point[1] - r, point[0] + r, point[1] + r], fill=fill)


def draw_glyph(image, pixel_size, full_bleed=False):
    # Full-bleed artwork is the tile itself, scaled up to the canvas.
    # The padded icon keeps the 96pt margin, so the glyph stays 63% of the tile.
    if full_bleed:
        tile = float(image.size[0])
    else:
        tile = TILE_SIDE * image.size[0] / CANVAS
    outer = GLYPH_WIDTH_RATIO * tile / 2
    ratio = band_ratio(pixel_size)
    band = max(2.0 * image.size[0] / pixel_size, outer * ratio)
    # Keep the band inside the outer radius.
    band = min(band, outer * 0.55)
    center_r = outer - band / 2
    gap = TOP_GAP
    if pixel_size <= 32:
        gap = 14
    left_end = 90 + gap / 2
    right_start = 90 - gap / 2
    arc_end = ARC_START - ARC_SWEEP
    # Bounding box of the semicircle plus the small dip below the hub.
    dip = outer * math.sin(math.radians(ARC_START - 180))
    top = outer
    bottom = -max(dip, band * 0.35)
    visual_center_offset = (top + bottom) / 2
    hub = (
        image.size[0] / 2,
        image.size[1] / 2 + visual_center_offset,
    )
    white = (255, 255, 255, 255)
    outline_width = max(image.size[0] / pixel_size * (2.2 if pixel_size <= 32 else 1.6), band * 0.16)
    draw = ImageDraw.Draw(image)

    if pixel_size <= 32:
        draw_arc(draw, hub, center_r, right_start, arc_end, outline_width, white)
        cap(draw, hub, center_r, right_start, outline_width, white)
        cap(draw, hub, center_r, arc_end, outline_width, white)
    else:
        inner = outer - band
        draw_arc(draw, hub, outer - outline_width / 2, right_start, arc_end, outline_width, white)
        draw_arc(draw, hub, inner + outline_width / 2, right_start, arc_end, outline_width, white)
        for radius in (outer - outline_width / 2, inner + outline_width / 2):
            cap(draw, hub, radius, right_start, outline_width, white)
            cap(draw, hub, radius, arc_end, outline_width, white)

    draw_arc(draw, hub, center_r, ARC_START, left_end, band, white)
    cap(draw, hub, center_r, ARC_START, band, white)
    cap(draw, hub, center_r, left_end, band, white)

    inner_clear = outer - band
    length = inner_clear * 0.9
    base = band * (0.62 if pixel_size <= 32 else 0.48)
    radians = math.radians(NEEDLE_DEGREES)
    direction = (math.cos(radians), -math.sin(radians))
    normal = (math.sin(radians), math.cos(radians))
    tip = (hub[0] + direction[0] * length, hub[1] + direction[1] * length)
    tail = band * 0.15
    back = (hub[0] - direction[0] * tail, hub[1] - direction[1] * tail)
    left = (back[0] + normal[0] * base / 2, back[1] + normal[1] * base / 2)
    right = (back[0] - normal[0] * base / 2, back[1] - normal[1] * base / 2)
    draw.polygon([tip, left, right], fill=white)
    hub_r = band * (0.42 if pixel_size <= 32 else 0.34)
    draw.ellipse([hub[0] - hub_r, hub[1] - hub_r, hub[0] + hub_r, hub[1] + hub_r], fill=white)


def render(pixel_size, full_bleed=False):
    ss = 4 if pixel_size <= 64 else 2
    if pixel_size >= 1024:
        ss = 2
    big = pixel_size * ss
    mask, _ = rounded_mask(big, full_bleed)
    color = gradient(big).convert("RGBA")
    color.putalpha(mask)
    if not full_bleed:
        shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        shadow_mask = mask.filter(ImageFilter.GaussianBlur(radius=max(1, round(18 * big / CANVAS))))
        shadow_layer = Image.new("RGBA", (big, big), (8, 32, 36, 64))
        shadow.paste(shadow_layer, (0, round(12 * big / CANVAS)), shadow_mask)
        plate = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        plate.alpha_composite(shadow)
        plate.alpha_composite(color)
        color = plate
    draw_glyph(color, pixel_size, full_bleed=full_bleed)
    if ss != 1:
        color = color.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
    return color


def pack_icns(png_by_size):
    body = b""
    seen = set()
    for size, ostype in ICNS_TYPES:
        data = png_by_size[size]
        if (ostype, data) in seen:
            continue
        seen.add((ostype, data))
        body += ostype + struct.pack(">I", 8 + len(data)) + data
    return b"icns" + struct.pack(">I", 8 + len(body)) + body


def main():
    iconset = ROOT / "build" / "AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    png_by_size = {}
    for name, pixels in ICONSET:
        image = render(pixels)
        image.save(iconset / name)
        png_by_size[pixels] = (iconset / name).read_bytes()
        print(f"iconset {name}")
    preview = render(1024)
    preview_path = ROOT / "Design" / "MacFan-UI" / "MenuGauge-AppIcon.png"
    preview.save(preview_path)
    preview.save(ROOT / "build" / "icon_preview.png")
    artwork = render(1024, full_bleed=True)
    artwork_dir = ROOT / "Resources" / "MenuGaugeFlat.icon" / "Assets"
    artwork_dir.mkdir(parents=True, exist_ok=True)
    artwork.save(artwork_dir / "Artwork.png")
    render(64).save(ROOT / "website" / "favicon.png")
    icns = pack_icns(png_by_size)
    (ROOT / "Resources" / "AppIcon.icns").write_bytes(icns)
    print(f"preview {preview_path}")
    print(f"icns {len(icns)} bytes")


if __name__ == "__main__":
    main()
