"""Build editable tiger_screen_shot projects from real, synthetic-data captures.

Only standard-library modules are needed. This creates projects, not screenshots;
use tiger_screen_shot's render command and visually review its PNG exports.
"""

import argparse
import base64
import hashlib
import json
import struct
from datetime import datetime, timezone
from pathlib import Path


SHOTS = (
    ("01-library", "好きなものを、\nひとつの棚に。", "ファイルをカタログにまとめて、見返しやすく。"),
    ("02-catalog", "まとめた中身を、\nひらいて見返す。", "カタログを開いて、入れた資料を一覧に。"),
    ("03-home", "お気に入りを、\nすぐそばに。", "お気に入りのカタログへ、ホームからすぐに。"),
    ("04-charms", "チャームで、\n見つけやすく。", "テーマをつけて、自分らしく整理。"),
    ("05-settings", "自分の使い方に、\n心地よく。", "テーマや言語を、自分の好みに。"),
)
DEVICES = {
    "iphone": (1320, 2868, "appstore"),
    "ipad": (2064, 2752, "appstore"),
    "android": (1080, 1920, "play"),
}
# Viewports of the original iPad capture, in source pixels. Do not redraw UI.
# Keep the uncropped PNGs in raw/ so the framing is explicit and reversible.
IPAD_CROPS = {
    "01-library": (0, 64, 1120, 1000),
    "02-catalog": (0, 64, 1200, 1200),
    "03-home": (0, 64, 1500, 1450),
    "04-charms": (0, 64, 1120, 1000),
    "05-settings": (0, 64, 1200, 1140),
}


def png_size(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("Capture must be a PNG with an IHDR header")
    return struct.unpack(">II", data[16:24])


def element(key, kind, x, y, width, height, **props):
    return dict(id=key, type=kind, position=dict(x=x, y=y),
                size=dict(width=width, height=height), rotation=0, scale=1, **props)


def text(key, content, x, y, width, height, px, color, weight="500"):
    # tiger_screen_shot stores text size at 0.3 of exported pixels.
    return element(key, "text", x, y, width, height, content=content,
                   fontSize=px * .3, color=color, fontFamily="Noto Sans JP",
                   fontWeight=weight, textAlign="left", lineHeight=1.22)


def png_source(data, size, crop=None):
    source = "data:image/png;base64," + base64.b64encode(data).decode()
    if crop is None:
        return source
    x, y, width, height = crop
    iw, ih = size
    if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > iw or y + height > ih:
        raise ValueError(f"Crop {crop} exceeds source dimensions {size}")
    # SVG changes only the viewport. The nested PNG remains byte-for-byte intact.
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
           f'viewBox="{x} {y} {width} {height}">'
           f'<image width="{iw}" height="{ih}" href="{source}"/></svg>')
    return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()


def board(device, index, slug, headline, subhead, data):
    width, height, _ = DEVICES[device]
    iw, ih = png_size(data)
    crop = IPAD_CROPS[slug] if device == "ipad" else None
    ratio = width / 1320
    if crop:
        margin, label_y, title_y, sub_y = 112, 62, 180, 600
        headline_px, sub_px, title_h = 148, 54, 380
        image_w = width - margin * 2
        image_h = image_w * crop[3] / crop[2]
        header = 790
        brand_px, brand_h = 64, 85
    else:
        margin = 85 * ratio
        header = 490 if device == "iphone" else 370
        label_y, title_y = 44 * ratio, 128 * ratio
        sub_y = (375 if device == "iphone" else 350) * ratio
        image_h = height - header - 85 * ratio
        image_w = image_h * iw / ih
        headline_px, sub_px = 103 * ratio, 34 * ratio
        title_h = (260 if device == "iphone" else 250) * ratio
        brand_px, brand_h = 38 * ratio, 65 * ratio
    x = (width - image_w) / 2
    prefix = f"{device}-{index + 1}"
    elements = [
        text(prefix + "-brand", "CharmShelf", margin, label_y,
             width - margin * 2, brand_h, brand_px, "#5578A8", "700"),
        text(prefix + "-title", headline, margin, title_y,
             width - margin * 2, title_h, headline_px, "#17314E", "800"),
        text(prefix + "-sub", subhead, margin, sub_y,
             width - margin * 2, 150 if crop else 90 * ratio, sub_px, "#475569"),
        element(prefix + "-frame", "shape", x - 4, header - 4, image_w + 8,
                image_h + 8, shapeType="rectangle", fillColor="#CFDBEA",
                strokeColor="transparent", strokeWidth=0, borderRadius=26 * ratio,
                shadow=dict(color="rgba(30,58,95,0.14)", blur=36 * ratio, x=0, y=18 * ratio)),
        element(prefix + "-screen", "image", x, header, image_w, image_h,
                imageSrc=png_source(data, (iw, ih), crop), objectFit="contain",
                borderRadius=24 * ratio),
    ]
    if crop:
        elements.append(text(prefix + "-crop-note", "実画面の一部を拡大表示", margin,
                             2675, width - margin * 2, 55, 38, "#64748B"))
    return dict(id=prefix, name=slug, position=dict(x=index * (width + 100), y=0),
                size=dict(width=width, height=height), backgroundColor="#EEF3FA",
                backgroundType="gradient", backgroundGradient=dict(
                    color1="#EEF3FA", color2="#FAF8F4", angle=155), zoom=1,
                elements=elements, localization=dict(baseLocale="ja", locales=[]))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True,
                        help="Existing screenshot pack with raw/<device>/<shot>.png")
    parser.add_argument("--devices", nargs="+", choices=DEVICES, default=list(DEVICES))
    args = parser.parse_args()
    root = args.pack.resolve()
    captures = {}
    # Check the complete capture plan before replacing any project/config.
    for device in args.devices:
        for slug, _, _ in SHOTS:
            path = root / "raw" / device / f"{slug}.png"
            data = path.read_bytes()
            if png_size(data) != DEVICES[device][:2]:
                raise ValueError(f"Unexpected capture dimensions: {path}")
            captures[device, slug] = data
    projects = root / "projects"
    projects.mkdir(parents=True, exist_ok=True)
    provenance_path = projects / "capture-provenance.json"
    previous = json.loads(provenance_path.read_text()) if provenance_path.exists() else []
    provenance = [entry for entry in previous if entry["device"] not in args.devices]
    for device in args.devices:
        width, height, store = DEVICES[device]
        boards = []
        for index, (slug, headline, subhead) in enumerate(SHOTS):
            data = captures[device, slug]
            boards.append(board(device, index, slug, headline, subhead, data))
            provenance.append(dict(device=device, raw=f"raw/{device}/{slug}.png",
                                   sha256=hashlib.sha256(data).hexdigest(),
                                   crop=IPAD_CROPS[slug] if device == "ipad" else None))
        project = projects / f"charmshelf-{device}.json"
        write_json(project, dict(id=f"charmshelf-store-{device}", name=f"CharmShelf 日本語 {device}",
                                 timestamp=datetime.now(timezone.utc).isoformat(), projectData=boards))
        output = root / "02_images" / "screenshots" / ("google-play" if store == "play" else "apple") / (
            "phone" if device == "android" else device)
        config = dict(name="CharmShelf", project=str(project), out=str(output),
                      formats=["as-is"], locales=["ja"], baseLocale="ja", store=store)
        write_json(projects / f"{device}.config.json", config)
        if device == "iphone":
            write_json(projects / "iphone-medium.config.json", {
                **config, "out": str(output.parent / "iphone-medium"), "formats": ["ios-6-3"]})
        print(f"{device}: {len(boards)} artboards, {width}x{height}")
    write_json(provenance_path, provenance)


if __name__ == "__main__":
    main()
