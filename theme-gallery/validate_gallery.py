#!/usr/bin/env python3
"""Check gallery data, generated assets, and widget theme order."""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image

from generate_previews import ROOT, REPO, load_data, rgb


def lua_theme_names(source: str) -> list[str]:
    match = re.search(
        r'\{\s*"Theme"\s*,\s*CHOICE\s*,\s*1\s*,\s*\{(.*?)\}\s*\}',
        source,
        re.DOTALL,
    )
    assert match, "Theme option list was not found"
    return re.findall(r'"([^"]+)"', match.group(1))


def kse4_source_palettes(source: str) -> dict[str, dict[str, tuple[int, int, int]]]:
    pattern = re.compile(
        r'^\s*(\w+)\s*=\s*\{\s*'
        r'bg=\{([^}]*)\},\s*tile=\{([^}]*)\},\s*line=\{([^}]*)\},\s*'
        r'dim=\{([^}]*)\},\s*accent=\{([^}]*)\}',
        re.MULTILINE,
    )

    def triplet(value: str) -> tuple[int, int, int]:
        numbers = tuple(int(part) for part in re.findall(r'\d+', value))
        assert len(numbers) == 3
        return numbers

    return {
        match.group(1): {
            "bg": triplet(match.group(2)),
            "panel": triplet(match.group(3)),
            "border": triplet(match.group(4)),
            "dim": triplet(match.group(5)),
            "accent": triplet(match.group(6)),
        }
        for match in pattern.finditer(source)
    }


def kse5_derived_palettes(source: str) -> dict[str, list[int]]:
    matches = re.finditer(
        r'(?:if|elseif)\s+name\s*==\s*"([^"]+)"\s+then\s+p\s*=\s*\{([^}]+)\}',
        source,
        re.DOTALL,
    )
    return {
        match.group(1): [int(part) for part in re.findall(r'\d+', match.group(2))]
        for match in matches
    }


def main():
    data = load_data()
    by_id = {widget["id"]: widget for widget in data["widgets"]}
    kse4_source = (REPO / "KSE4" / "main.lua").read_text(encoding="utf-8")
    kse5_source = (REPO / "KSE5" / "main.lua").read_text(encoding="utf-8")

    assert lua_theme_names(kse4_source) == [theme["name"] for theme in by_id["kse4"]["themes"]]
    assert lua_theme_names(kse5_source) == [theme["name"] for theme in by_id["kse5"]["themes"]]

    source_palettes = kse4_source_palettes(kse4_source)
    special_kse4 = {"dark", "light", "transparent", "transparent-light"}
    for theme in by_id["kse4"]["themes"]:
        if theme["slug"] in special_kse4:
            continue
        key = theme["slug"].replace("-", "_")
        expected = source_palettes[key]
        for color_name, expected_rgb in expected.items():
            assert rgb(theme["colors"][color_name]) == expected_rgb, (
                f'KSE4 {theme["name"]} {color_name} differs from main.lua'
            )

    derived = kse5_derived_palettes(kse5_source)
    for theme in by_id["kse5"]["themes"]:
        if not theme.get("derived"):
            continue
        values = derived[theme["slug"].replace("-", "_")]
        expected = {
            "bg": tuple(values[0:3]),
            "panel": tuple(values[3:6]),
            "border": tuple(values[6:9]),
            "dim": tuple(values[9:12]),
            "accent": tuple(values[12:15]),
        }
        for color_name, expected_rgb in expected.items():
            assert rgb(theme["colors"][color_name]) == expected_rgb, (
                f'KSE5 {theme["name"]} {color_name} differs from main.lua'
            )

    expected_assets = set()
    for widget in data["widgets"]:
        for theme in widget["themes"]:
            expected_assets.add(f'{widget["id"]}-{theme["slug"]}.png')
        expected_assets.add(f'{widget["id"]}-theme-sheet.png')
    actual_assets = {path.name for path in (ROOT / "assets").glob("*.png")}
    assert actual_assets == expected_assets
    for filename in expected_assets:
        with Image.open(ROOT / "assets" / filename) as image:
            if "theme-sheet" not in filename:
                assert image.size == (480, 272), f"unexpected dimensions for {filename}"

    index = (ROOT / "index.html").read_text(encoding="utf-8")
    for reference in ("styles.css", "themes.js", "gallery.js"):
        assert reference in index
    print("Theme gallery validation passed: 44 themes, 46 preview assets")


if __name__ == "__main__":
    main()
