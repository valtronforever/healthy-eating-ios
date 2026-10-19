# App icon

The approved icon is **R4 "Fork + knife conversation"** (owner decision, 2026-10-18): a fork on the left and a kitchen knife on the right, centered as a pair inside a speech bubble. The bubble means logging through the assistant people already use; it does not imply an in-app chat. Use the files in Assets › AppIcon as supplied; never redraw, recolor or replace them.

## Appearances

| Appearance | Background | Mark | Mark on background |
| --- | --- | --- | --- |
| Default | Deep teal `#24675D` | Warm ivory `#F7F5EE` | 6.07:1 |
| Dark | Evergreen `#172D29` | Pale mint `#B7DFCB` | 10.00:1 |
| Tinted | Transparent | Mid gray `#808080` | set by the system tint |

These are icon colors. The UI `accent` reuses the default background `#24675D` in light mode; nothing else from the icon is a UI token.

## Geometry (1024 × 1024 masters)

- Bubble ring: even-odd filled path, approximately x 210–814, y 218–812, 60-unit ring, tail at the lower left. The interior (x 270–754, y 278–674, center 512, 476) is transparent in the tinted master.
- Fork: 44-unit round-capped stroke with rounded prong tips. Knife: filled path, broad blade facing the fork, narrow handle.
- The utensil pair (x 376–648, y 336–616) shares the bubble interior's center; 106 units clearance left and right, 58 top and bottom. Fork and knife share the same top and baseline.
- No text, gradients, raster embeds or rounded corners: the system applies the mask.

## Files

| File | Use |
| --- | --- |
| `app-icon.svg`, `app-icon-dark.svg`, `app-icon-tinted.svg` | Editable masters |
| `app-icon-1024.png`, `app-icon-dark-1024.png`, `app-icon-tinted-1024.png` | Asset catalog slots (default and dark opaque, tinted with alpha) |
| `app-icon-180.png`, `-60`, `-29` (and dark, tinted) | Small-size review renders |
| `layer-background.svg`, `layer-foreground.svg` | Separate layers for a future Icon Composer project |
| `selected.png` | Presentation board |

## In the UI

- The icon appears only on Welcome (A1) at 96 pt, on the server's sign-in page (A3) at 56 pt, and on the Home Screen itself, always with the system's continuous corner mask. Never as a decorative pattern, never cropped, never inside a colored container.
- No wordmark exists. Set "Healthy Eating" in SF Pro (`title-2` or larger), sentence case. The name may change, which is why the icon has no text.

## Open checks

Device review at 29 pt and on real wallpapers, Xcode tinted-slot appearance and Liquid Glass / clear variants are still pending (recorded in the icon package's DESIGN.md).
