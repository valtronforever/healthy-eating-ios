# Healthy Eating: app icon

Prepared 2026-10-18 for [issue #42](https://github.com/valtronforever/healthy-eating-ios/issues/42).
Scope: icon assets only. This is not the screen design system; typography, macro colors,
components, mockups, and Claude Design deliverables remain outside this package.

## Selected direction

**Fork + knife conversation (R4), requested by the owner on 2026-10-18.**
The owner selected concept 08, then requested a kitchen knife beside the fork and the
pair centered inside the conversation bubble. The `app-icon*.svg` masters implement this
refinement. The original bubble and palette remain unchanged.

The fork sits on the left, with the kitchen knife on the right. The rounded handles and
simple silhouettes match the selected icon's style. The speech bubble represents logging
through the user's existing AI assistant; it does not imply an in-app chat.

Ten concepts and four refinements remain in `icon/concepts.pdf` for reference. R4 and the
final page show the current artwork; concept 08 records the original fork-only selection.

## Artwork and colors

| Appearance | Background | Mark | Measured mark/background contrast |
|---|---|---|---|
| Default | Deep teal `#24675D` | Warm ivory `#F7F5EE` | 6.07:1 |
| Dark | Evergreen `#172D29` | Pale mint `#B7DFCB` | 10.00:1 |
| Tinted source | Transparent | Mid gray `#808080` | Depends on system tint/background |

These are icon colors, not approved app UI tokens. Contrast ratios are supporting
checks of solid colors, not a claim of complete app accessibility compliance.

All masters use a 1024 x 1024 coordinate system. Default and dark sources have an opaque
full-bleed background; the tinted source deliberately has no background. An even-odd filled
path forms the bubble ring with a transparent interior. A 44-unit stroke with rounded caps
and joins forms the fork, and a filled curved path forms the kitchen knife. Geometry is
identical between appearances. There is no text, font, gradient, raster embed, external
reference or rounded app corner. The system supplies the outer mask.

The bubble spans approximately x=210..814, y=218..812. Its interior bounds are x=270..754,
y=278..674, centered at (512, 476). The combined utensil bounds are x=376..648, y=336..616,
with exactly the same center. Their left/right clearance is 106 units, top/bottom clearance
58 units. Centering uses the bubble interior, excluding its tail. The fork and knife share
the same top and baseline, and the knife blade faces inward toward the fork.

Preserve the original fork's rounded prong tips, the knife's broad blade/narrow handle,
the gap between utensils, the bubble opening and lower-left tail. The 44-unit handles are
approximately 1.25 px at 29 px; the 60-unit ring is approximately 1.70 px. Inspect the
small-size artwork on a real device before shipping. Do not change proportions between sizes.

## Files and implementation handoff

- `icon/app-icon.svg`, `app-icon-dark.svg`, `app-icon-tinted.svg`: editable selected masters.
- `icon/exports/`: corresponding 1024 px PNGs; default/dark opaque, tinted with alpha.
- `icon/concepts/`: ten independent original SVGs and 1024 px PNGs.
- `icon/refinements/`: four independent SVGs and 1024 px PNGs.
- `icon/previews/`: 180, 60 and 29 px PNGs of all three appearances and the selected presentation board (`selected.png`).
- `icon/review.html`: self-contained, offline comparison canvas; each concept and refinement
  appears at actual 1024/180/60/29 CSS px on both light and dark wallpaper. Use 100% browser
  zoom; scroll horizontally for the 1024 px sample. CSS pixels do not equal physical Retina pixels.
- `icon/concepts.pdf`: 16-page review book. Masters are fitted to page; small-size samples use
  one pixel per PDF point. Page scaling can change apparent size; use the HTML for pixel review.
- `icon/layers/`: separate foreground/background SVGs for future Icon Composer import.
  These are sources, not a compiled or tested `.icon` project.
- `icon/validation.json`: structural and raster checks. `tools/build_icon_assets.py` rebuilds
  everything using Python, Pillow, ReportLab, pypdf and the `rsvg-convert` command.

For the planned iOS 18 asset catalog, use PNG exports in the appropriate default/dark/tinted
slots when the app target is scaffolded. SVGs are editable source assets, not a ready-made app icon catalog.
The transparent gray tinted source follows the issue's explicit brief; its final appearance
must be checked in Xcode and on a device. No app target exists yet, so asset compilation,
App Store validation, and system tint/masking have not been tested.

Current Apple guidance also covers layered icons and Icon Composer. This package meets the
issue's SVG brief, but does not claim to deliver all contemporary Liquid Glass/clear variants.
Sources checked 2026-10-18:
[Apple app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
and [Xcode asset catalog configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Review and rights

The supplied 29 px renders retain the fork and knife silhouettes, bubble and speech tail. The scalloped
prong tips become subtle at this size; human recognition and device review remain pending. Review sheets use an approximate corner mask only; exported masters remain square.
The PDF was rendered and visually reviewed. Structural checks cover all 19 SVGs, dimensions,
allowed geometric elements, no external references, opacity and grayscale alpha requirements.
Human recognizability testing and actual home-screen checks remain pending.

Original vector geometry authored for Healthy Eating; licensed under the repository's MIT
license. No third-party icon, SF Symbol, bundled font, food photo or user data is included.
PDF labels use standard PDF fonts; preview labels are rasterized from the local system font.
No image-generation model or Claude Design was used.
