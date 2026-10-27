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
# Padded 1024 canvas. Full-bleed artwork scales these with the tile.
ARC_START = 190.0
ARC_END = -10.0
OUTER_RADIUS = 310.0
BAND = 100.0
OUTLINE = 23.0
SEGMENT_GAP = 26.0
NEEDLE_DEGREES = 38.0
NEEDLE_BASE = 44.0
NEEDLE_TIP = 12.0
HUB_RADIUS = 40.0

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


def xy(radius, deg):
    """Image point relative to the hub. 0° is east, positive is counterclockwise."""
    rad = math.radians(deg)
    return (radius * math.cos(rad), -radius * math.sin(rad))


def add(p, q):
    return (p[0] + q[0], p[1] + q[1])


def half_gap_degrees(mid_r, cap_r, gap):
    """Angle from vertical to each cap center so the rounded ends are `gap` apart."""
    target = gap / 2.0
    lo, hi = 0.0, math.pi / 2.5
    for _ in range(48):
        mid = (lo + hi) / 2.0
        opening = mid_r * math.sin(mid) - cap_r * math.cos(mid)
        if opening < target:
            lo = mid
        else:
            hi = mid
    return math.degrees((lo + hi) / 2.0)


def arc_points(radius, start, end, steps):
    span = (start - end) % 360.0
    return [xy(radius, start - span * i / steps) for i in range(steps + 1)]


def cap_points(mid_r, cap_r, deg, tangent, steps):
    """Semicircle from the outer edge to the inner edge, bulging along `tangent`."""
    radial = xy(1.0, deg)
    center = xy(mid_r, deg)
    pts = []
    for i in range(steps + 1):
        t = math.pi * i / steps
        pts.append((
            center[0] + cap_r * (math.cos(t) * radial[0] + math.sin(t) * tangent[0]),
            center[1] + cap_r * (math.cos(t) * radial[1] + math.sin(t) * tangent[1]),
        ))
    return pts


def tangent_cw(deg):
    rad = math.radians(deg)
    return (math.sin(rad), math.cos(rad))


def tangent_ccw(deg):
    rad = math.radians(deg)
    return (-math.sin(rad), -math.cos(rad))


def annular_sector(outer, inner, start, end):
    """Closed annular sector. `start` sweeps clockwise to `end`. Caps are semicircles."""
    span = (start - end) % 360.0
    arc_steps = max(12, int(math.ceil(span * 2)))
    cap_steps = 24
    mid = (outer + inner) / 2.0
    cap = (outer - inner) / 2.0
    pts = arc_points(outer, start, end, arc_steps)
    pts.extend(cap_points(mid, cap, end, tangent_cw(end), cap_steps)[1:])
    inner_arc = list(reversed(arc_points(inner, start, end, arc_steps)))
    pts.extend(inner_arc[1:])
    # Start cap runs from the inner edge back to the outer edge.
    start_cap = list(reversed(cap_points(mid, cap, start, tangent_ccw(start), cap_steps)))
    pts.extend(start_cap[1:-1])
    return pts


def needle_polygon(length, base, tip):
    """Tapered wedge with a semicircular tip. Hub at the origin, image y down."""
    tip_r = tip / 2.0
    reach = max(tip_r + 0.5, length - tip_r)
    rad = math.radians(NEEDLE_DEGREES)
    direction = (math.cos(rad), -math.sin(rad))
    normal = (math.sin(rad), math.cos(rad))
    tip_center = (direction[0] * reach, direction[1] * reach)
    steps = 16
    pts = [(normal[0] * base / 2.0, normal[1] * base / 2.0)]
    # +normal is at needleDegrees-90; the semicircle passes through the tip.
    for i in range(steps + 1):
        a = math.radians(NEEDLE_DEGREES - 90 + 180.0 * i / steps)
        pts.append((tip_center[0] + tip_r * math.cos(a), tip_center[1] - tip_r * math.sin(a)))
    pts.append((-normal[0] * base / 2.0, -normal[1] * base / 2.0))
    return pts


def glyph_geometry(pixel_size, unit):
    """Sizes in the image being drawn. `unit` is pixels per padded-1024 design pixel."""
    outer = OUTER_RADIUS * unit
    band = BAND * unit
    stroke = OUTLINE * unit
    gap = SEGMENT_GAP * unit
    hub_r = HUB_RADIUS * unit
    base = NEEDLE_BASE * unit
    tip = NEEDLE_TIP * unit
    # Below 64px a proportional stroke disappears. Thicken just enough to keep
    # a hollow slot and a readable hub; the 1024 drawing stays on the spec.
    if pixel_size <= 16:
        band = max(band, 3.15 * unit * CANVAS / pixel_size)
        stroke = max(stroke, 1.15 * unit * CANVAS / pixel_size)
        hub_r = max(hub_r, 1.45 * unit * CANVAS / pixel_size)
        base = max(base, 1.9 * unit * CANVAS / pixel_size)
        tip = max(tip, 1.05 * unit * CANVAS / pixel_size)
        gap = max(gap, 1.05 * unit * CANVAS / pixel_size)
    elif pixel_size <= 32:
        band = max(band, 5.2 * unit * CANVAS / pixel_size)
        stroke = max(stroke, 1.7 * unit * CANVAS / pixel_size)
        hub_r = max(hub_r, 2.4 * unit * CANVAS / pixel_size)
        base = max(base, 3.1 * unit * CANVAS / pixel_size)
        tip = max(tip, 1.35 * unit * CANVAS / pixel_size)
        gap = max(gap, 1.7 * unit * CANVAS / pixel_size)
    band = min(band, outer * 0.72)
    stroke = min(stroke, band * 0.38)
    if band - 2 * stroke < stroke * 0.45:
        stroke = band / 3.0
    inner = outer - band
    return outer, inner, band, stroke, gap, hub_r, base, tip


def draw_glyph(image, pixel_size, full_bleed=False):
    # `unit` converts a padded-1024 design pixel into pixels of this bitmap.
    # Full-bleed artwork is the tile with the margin scaled away.
    unit = image.size[0] / CANVAS
    if full_bleed:
        unit *= CANVAS / TILE_SIDE
    outer, inner, band, stroke, gap, hub_r, base, tip = glyph_geometry(pixel_size, unit)
    mid = (outer + inner) / 2.0
    cap = band / 2.0
    beta = half_gap_degrees(mid, cap, gap)
    left_end = 90.0 + beta
    right_start = 90.0 - beta
    sectors = [
        annular_sector(outer, inner, ARC_START, left_end),
        annular_sector(outer - stroke, inner + stroke, right_start, ARC_END),
        annular_sector(outer, inner, right_start, ARC_END),
    ]
    length = max(inner * 0.45, inner - 30.0 * unit)
    parts = sectors + [needle_polygon(length, base, tip)]
    xs = [p[0] for part in parts for p in part] + [-hub_r, hub_r]
    ys = [p[1] for part in parts for p in part] + [-hub_r, hub_r]
    shift = (
        image.size[0] / 2.0 - (min(xs) + max(xs)) / 2.0,
        image.size[1] / 2.0 - (min(ys) + max(ys)) / 2.0,
    )
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([add(p, shift) for p in sectors[0]], fill=255)
    # Outline is the same annular sector with a smaller copy punched out,
    # so the stroke sits inside the band and the caps stay semicircles.
    outline = Image.new("L", image.size, 0)
    odraw = ImageDraw.Draw(outline)
    odraw.polygon([add(p, shift) for p in sectors[2]], fill=255)
    odraw.polygon([add(p, shift) for p in sectors[1]], fill=0)
    mask = Image.fromarray(np.maximum(np.array(mask), np.array(outline)))
    ndraw = ImageDraw.Draw(mask)
    ndraw.polygon([add(p, shift) for p in needle_polygon(length, base, tip)], fill=255)
    ndraw.ellipse([shift[0] - hub_r, shift[1] - hub_r, shift[0] + hub_r, shift[1] + hub_r], fill=255)
    white = Image.new("RGBA", image.size, (255, 255, 255, 255))
    image.paste(white, mask=mask)


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
