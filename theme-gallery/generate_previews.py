#!/usr/bin/env python3
"""Generate GitHub-ready KSE4/KSE5 theme preview PNGs from themes.js."""

from __future__ import annotations

import json
import math
import re
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
REPO = ROOT.parent
SCALE = 2
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def load_data() -> dict:
    source = (ROOT / "themes.js").read_text(encoding="utf-8")
    payload = source.split("=", 1)[1].strip()
    if payload.endswith(";"):
        payload = payload[:-1]
    data = json.loads(payload)
    assert [widget["id"] for widget in data["widgets"]] == ["kse4", "kse5"]
    for widget in data["widgets"]:
        assert len(widget["themes"]) == 22, f'{widget["id"]} must contain 22 themes'
        assert len({theme["slug"] for theme in widget["themes"]}) == 22
        for theme in widget["themes"]:
            for value in theme["colors"].values():
                assert HEX_COLOR.match(value), f"invalid color {value} in {widget['id']} {theme['name']}"
    return data


def rgb(value: str) -> tuple[int, int, int]:
    return tuple(int(value[index:index + 2], 16) for index in (1, 3, 5))


def mix(first: str, second: str, second_weight: float) -> str:
    a, b = rgb(first), rgb(second)
    channels = [round(a[index] * (1 - second_weight) + b[index] * second_weight) for index in range(3)]
    return "#" + "".join(f"{channel:02x}" for channel in channels)


def kse5_colors(theme: dict) -> dict:
    colors = dict(theme["colors"])
    if theme.get("derived"):
        colors["top"] = mix(colors["bg"], colors["panel"], 1 / 3)
        colors["panelAlt"] = mix(colors["panel"], colors["border"], 1 / 3)
        colors["track"] = mix(colors["panel"], colors["border"], 1 / 2)
    colors.setdefault("panelAlt", colors["panel"])
    colors.setdefault("top", colors["bg"])
    colors.setdefault("track", colors["border"])
    colors.setdefault("dim", "#969696")
    colors.setdefault("accent", "#e6e6e6")
    return colors


def px(value: float) -> int:
    return round(value * SCALE)


FONT_PATHS = {
    "regular": [
        "/System/Library/Fonts/SFNS.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ],
    "bold": [
        "/System/Library/Fonts/SFCompact.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ],
    "mono": [
        "/System/Library/Fonts/SFNSMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ],
}


@lru_cache(maxsize=None)
def font(size: int, style: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in FONT_PATHS[style]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, px(size))
    return ImageFont.load_default()


def rounded(draw: ImageDraw.ImageDraw, box, radius: int, fill: str, outline: str | None = None, width: int = 1):
    draw.rounded_rectangle(tuple(px(value) for value in box), radius=px(radius), fill=fill,
                           outline=outline, width=px(width) if outline else 1)


def line(draw: ImageDraw.ImageDraw, points, fill: str, width: int = 1):
    draw.line([(px(x), px(y)) for x, y in points], fill=fill, width=px(width))


def write(draw: ImageDraw.ImageDraw, position, text: str, size: int, fill: str,
          style: str = "regular", anchor: str = "la"):
    draw.text((px(position[0]), px(position[1])), text, font=font(size, style), fill=fill, anchor=anchor)


def checkerboard(image: Image.Image):
    draw = ImageDraw.Draw(image)
    step = 18
    for row in range(math.ceil(272 / step)):
        for col in range(math.ceil(480 / step)):
            fill = "#20242b" if (row + col) % 2 == 0 else "#303641"
            draw.rectangle((px(col * step), px(row * step), px((col + 1) * step), px((row + 1) * step)), fill=fill)


@lru_cache(maxsize=4)
def helicopter_tint(color: str, width: int, height: int) -> Image.Image:
    source = Image.open(REPO / "KSE5" / "default.png").convert("RGBA")
    source.thumbnail((px(width), px(height)), Image.Resampling.LANCZOS)
    alpha = source.getchannel("A")
    tinted = Image.new("RGBA", source.size, rgb(color) + (0,))
    tinted.putalpha(alpha)
    return tinted


def paste_helicopter(image: Image.Image, box, color: str):
    x, y, width, height = box
    helicopter = helicopter_tint(color, width, height)
    target_x = px(x) + max(0, (px(width) - helicopter.width) // 2)
    target_y = px(y) + max(0, (px(height) - helicopter.height) // 2)
    image.alpha_composite(helicopter, (target_x, target_y))


def draw_signal(draw: ImageDraw.ImageDraw, x: int, bottom: int, color: str):
    for index, height in enumerate((4, 7, 10, 14)):
        draw.rounded_rectangle((px(x + index * 7), px(bottom - height), px(x + index * 7 + 4), px(bottom)),
                               radius=px(1), fill=color)


def draw_battery(draw: ImageDraw.ImageDraw, x: int, y: int, color: str, fill_color: str):
    draw.rounded_rectangle((px(x), px(y), px(x + 12), px(y + 19)), radius=px(2), outline=color, width=px(1))
    draw.rectangle((px(x + 4), px(y - 3), px(x + 8), px(y - 1)), fill=color)
    draw.rounded_rectangle((px(x + 2), px(y + 6), px(x + 10), px(y + 17)), radius=px(1), fill=fill_color)


def render_kse4(theme: dict) -> Image.Image:
    colors = theme["colors"]
    image = Image.new("RGBA", (px(480), px(272)), rgb(colors["bg"]) + (255,))
    if theme.get("transparent"):
        checkerboard(image)
    draw = ImageDraw.Draw(image)
    panel, border = colors["panel"], colors["border"]
    text, dim, accent = colors["text"], colors["dim"], colors["accent"]
    green, yellow = "#22c55e", "#f0b429"

    write(draw, (9, 14), "KSE DEMO", 12, text, "bold", "lm")
    write(draw, (214, 14), "04:32", 16, text, "mono", "mm")
    write(draw, (365, 14), "Profile 3 / Rate 2", 8, text, "regular", "mm")
    draw_signal(draw, 426, 21, green)
    draw_battery(draw, 462, 6, dim, green)
    line(draw, ((0, 30), (480, 30)), border)

    rounded(draw, (8, 38, 108, 183), 5, panel, border)
    paste_helicopter(image, (13, 43, 90, 107), dim)
    line(draw, ((15, 153), (101, 153)), border)
    write(draw, (58, 168), "128 FLIGHTS", 9, text, "bold", "mm")

    rounded(draw, (8, 189, 108, 261), 5, panel, border)
    write(draw, (58, 205), "GOVERNOR", 8, accent, "bold", "mm")
    write(draw, (58, 233), "ACTIVE", 15, green, "bold", "mm")

    rounded(draw, (114, 38, 472, 118), 5, panel, border)
    write(draw, (126, 51), "HEADSPEED", 8, dim, "bold", "la")
    write(draw, (126, 84), "2140", 30, text, "bold", "lm")
    write(draw, (458, 62), "MAX  2198", 10, yellow, "mono", "ra")
    write(draw, (458, 92), "TAIL  9630", 10, text, "mono", "ra")

    rounded(draw, (114, 124, 472, 183), 5, panel, border)
    tile_data = (("AMPS", "38.4"), ("CELL V", "3.92"), ("BEC V", "7.5"), ("ESC °C", "61"))
    tile_width = 358 / 4
    for index, (label, value) in enumerate(tile_data):
        left = 114 + index * tile_width
        if index:
            line(draw, ((left, 132), (left, 175)), border)
        write(draw, (left + tile_width / 2, 137), label, 7, dim, "bold", "mm")
        write(draw, (left + tile_width / 2, 160), value, 15, text, "bold", "mm")

    write(draw, (114, 198), "BATT · P3 · 12S · 47.0V · 1120 mAh used", 8, dim, "bold", "la")
    rounded(draw, (114, 207, 472, 259), 5, panel, border)
    draw.rounded_rectangle((px(117), px(210), px(370), px(256)), radius=px(3), fill=green)
    write(draw, (293, 233), "72%", 20, "#000000", "bold", "mm")
    return image.resize((480, 272), Image.Resampling.LANCZOS).convert("RGB")


def draw_ring(draw: ImageDraw.ImageDraw, center, radius: int, track: str, color: str, progress: float, width: int = 6):
    x, y = center
    box = (px(x - radius), px(y - radius), px(x + radius), px(y + radius))
    draw.ellipse(box, outline=track, width=px(width))
    draw.arc(box, start=-90, end=-90 + round(360 * progress), fill=color, width=px(width))


def render_kse5(theme: dict) -> Image.Image:
    colors = kse5_colors(theme)
    image = Image.new("RGBA", (px(480), px(272)), rgb(colors["bg"]) + (255,))
    draw = ImageDraw.Draw(image)
    text, dim, accent = colors["text"], colors["dim"], colors["accent"]
    panel, panel_alt = colors["panel"], colors["panelAlt"]
    border, track = colors["border"], colors["track"]
    green, yellow, blue, orange = "#1ce877", "#ffc430", "#3788ff", "#ff701c"

    draw.rectangle((0, 0, px(480), px(32)), fill=colors["top"])
    write(draw, (8, 15), "KSE DEMO", 11, text, "bold", "lm")
    write(draw, (216, 15), "04:32", 15, text, "mono", "mm")
    write(draw, (365, 15), "Profile 3 / Rate 2", 8, text, "regular", "mm")
    draw_signal(draw, 426, 22, green)
    draw_battery(draw, 462, 7, dim, green)
    line(draw, ((5, 31), (475, 31)), border)

    ring_specs = (
        ("BATTERY", "72", "%", "P3  12S  47.0V", green, 0.72),
        ("HEAD RPM", "2140", "RPM", "MAX 2198", accent, 0.84),
        ("CURRENT", "38", "AMPS", "MAX 62", blue, 0.43),
        ("ESC TEMP", "61", "°C", "MAX 68", orange, 0.49),
    )
    margin, gap, card_width = 8, 5, (480 - 16 - 15) / 4
    for index, (label, value, unit, footer, ring_color, progress) in enumerate(ring_specs):
        left = margin + index * (card_width + gap)
        rounded(draw, (left, 38, left + card_width, 153), 5, panel, border)
        draw.rectangle((px(left + 3), px(39), px(left + card_width - 3), px(40)), fill=accent if index == 1 else dim)
        write(draw, (left + card_width / 2, 49), label, 7, dim, "bold", "mm")
        draw_ring(draw, (left + card_width / 2, 96), 31, track, ring_color, progress)
        value_size = 18 if len(value) < 4 else 15
        write(draw, (left + card_width / 2, 91), value, value_size, text, "bold", "mm")
        write(draw, (left + card_width / 2, 109), unit, 7, dim, "bold", "mm")
        write(draw, (left + card_width / 2, 142), footer, 6, dim, "regular", "mm")

    rounded(draw, (8, 160, 227, 264), 5, panel, border)
    rounded(draw, (12, 164, 223, 239), 3, colors.get("panelAlt", panel), None)
    paste_helicopter(image, (18, 168, 199, 66), dim)
    line(draw, ((14, 241), (221, 241)), border)
    write(draw, (117, 252), "128 FLIGHTS", 9, text, "bold", "mm")

    tile_specs = (("GOV MODE", "ACTIVE", green), ("BEC OUTPUT", "7.5 V", text),
                  ("CELL VOLT", "3.92 V", text), ("USED CAPACITY", "1120", text))
    tile_left, tile_top, tile_gap = 234, 160, 5
    tile_width = (480 - tile_left - 8 - tile_gap) / 2
    tile_height = (104 - tile_gap) / 2
    for index, (label, value, value_color) in enumerate(tile_specs):
        col, row = index % 2, index // 2
        left = tile_left + col * (tile_width + tile_gap)
        top = tile_top + row * (tile_height + tile_gap)
        rounded(draw, (left, top, left + tile_width, top + tile_height), 5, panel_alt, border)
        draw.rectangle((px(left + 2), px(top + 4), px(left + 4), px(top + tile_height - 4)), fill=accent)
        write(draw, (left + 9, top + 12), label, 6, dim, "bold", "la")
        write(draw, (left + tile_width - 8, top + 31), value, 11, value_color, "bold", "ra")
    return image.resize((480, 272), Image.Resampling.LANCZOS).convert("RGB")


def render_sheet(widget: dict, previews: list[tuple[dict, Image.Image]]):
    columns, gap, outer = 3, 20, 24
    preview_width, preview_height, caption_height = 480, 272, 43
    rows = math.ceil(len(previews) / columns)
    header_height = 104
    sheet_width = outer * 2 + columns * preview_width + (columns - 1) * gap
    row_height = preview_height + caption_height + gap
    sheet_height = header_height + rows * row_height + outer
    sheet = Image.new("RGB", (sheet_width, sheet_height), "#090b10")
    draw = ImageDraw.Draw(sheet)
    draw.text((outer, 24), f'{widget["name"]} theme gallery', font=font(17, "bold"), fill="#f5f7fb", anchor="la")
    draw.text((outer, 67), f'{len(previews)} themes · {widget["description"]}', font=font(7), fill="#9aa5b5", anchor="la")
    for index, (theme, preview) in enumerate(previews):
        col, row = index % columns, index // columns
        x = outer + col * (preview_width + gap)
        y = header_height + row * row_height
        sheet.paste(preview, (x, y))
        draw.rounded_rectangle((x, y + preview_height, x + preview_width, y + preview_height + caption_height),
                               radius=7, fill="#151923")
        draw.text((x + 13, y + preview_height + 22), theme["name"], font=font(8, "bold"),
                  fill="#f5f7fb", anchor="lm")
        draw.text((x + preview_width - 13, y + preview_height + 22), f'THEME {index + 1:02d}', font=font(5, "mono"),
                  fill="#8390a3", anchor="rm")
    sheet.save(ASSETS / f'{widget["id"]}-theme-sheet.png', optimize=True)


def main():
    data = load_data()
    ASSETS.mkdir(parents=True, exist_ok=True)
    expected_assets = set()
    for widget in data["widgets"]:
        previews = []
        renderer = render_kse4 if widget["id"] == "kse4" else render_kse5
        for theme in widget["themes"]:
            preview = renderer(theme)
            filename = f'{widget["id"]}-{theme["slug"]}.png'
            preview.save(ASSETS / filename, optimize=True)
            expected_assets.add(filename)
            previews.append((theme, preview))
        render_sheet(widget, previews)
        expected_assets.add(f'{widget["id"]}-theme-sheet.png')
    for stale in ASSETS.glob("*.png"):
        if stale.name not in expected_assets:
            stale.unlink()
    print(f"Generated {len(expected_assets)} preview assets in {ASSETS}")


if __name__ == "__main__":
    main()
