# App icon review package

Start with `icon/previews/selected.png`, then `icon/concepts.pdf` (16 pages).
Open `icon/review.html` in a browser at 100% zoom for the full-size comparison canvas.
Read `DESIGN.md` for the rationale, colors, source inventory, limitations and handoff.
`PROJECT_CONTEXT.md` records the verified baseline and product constraints.

The current icon is **R4 / Fork + knife conversation**: the owner-selected concept 08
with a kitchen knife added and both utensils centered, as requested on 2026-10-18.
There are 10 initial concepts and 4 refinements. Sources are original, MIT-licensed SVGs.
The adjacent LICENSE is copied from the repository for standalone distribution.

Rebuild from the repository root with Python 3 plus Pillow, ReportLab and pypdf,
and librsvg's `rsvg-convert` available on PATH:

```sh
python3 design/tools/build_icon_assets.py
```

The preview generator uses `/System/Library/Fonts/Helvetica.ttc` for raster labels on macOS.
SVG sources contain no font dependency. Asset checks are recorded in `icon/validation.json`.

The three 1024 px exports are used as supplied in the app's asset catalog
(`HealthyEating/Resources/Assets.xcassets/AppIcon.appiconset`: default, dark and tinted slots;
`AppIconImage.imageset` for the Welcome screen). If the exports change, copy them there again.

The approved design system (tokens, copy rules, component guidelines) is in `system/`;
see `system/SOURCE.md`.
