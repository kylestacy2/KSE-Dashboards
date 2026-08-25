# KSE theme gallery

These preview sheets show every theme included with both dashboards. The telemetry values are illustrative; the colors are matched to the current widget source.

## KSE4 themes

[![KSE4 theme preview sheet](assets/kse4-theme-sheet.png)](assets/kse4-theme-sheet.png)

## KSE5 themes

[![KSE5 theme preview sheet](assets/kse5-theme-sheet.png)](assets/kse5-theme-sheet.png)

## Interactive gallery

Open [`index.html`](index.html) locally, or publish the `theme-gallery` folder with GitHub Pages. The interactive version includes widget filters, theme search, palette swatches, and individual full-resolution samples.

The committed images require no build step. Maintainers can regenerate them after changing widget palettes by running:

```bash
python3 theme-gallery/generate_previews.py
```

The generator requires Python 3 and Pillow.

After regenerating, verify that the gallery still matches the widget theme lists and source palettes:

```bash
python3 theme-gallery/validate_gallery.py
```
