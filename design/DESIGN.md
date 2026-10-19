# Healthy Eating: design

Design description for [issue #42](https://github.com/valtronforever/healthy-eating-ios/issues/42):
the approved app icon (R4, 2026-10-18) and the approved iOS UI design (2026-10-18). The full
design system is in [`system/`](system/README.md) (brand book, `tokens.json`, copy rules,
component guidelines); the high-fidelity screens are in [`mockups/`](mockups/). This file is
the summary. Where it and `system/` differ, `system/` wins.

Source of the UI design: the Healthy Eating Design System artifact
(https://claude.ai/artifact/8JTaMfHzKZLSWYj5VhYk2r, version `1792321896-e79d`), built from the
issue's brief: grayscale wireframes of every screen first, then high-fidelity screens. The
wireframes stay in the artifact. The app implements the system in
`HealthyEating/DesignSystem/` (see `AGENTS.md`).

## Principles

1. **Neutral feedback.** A value above its target and one below look identical. Targets are
   ranges. No red for data, no warning icons, no celebration, streaks, badges or scores.
2. **Honest data.** Every meal shows where its numbers came from ("Your numbers" or
   "Estimated"), how sure the estimate is (Low, Medium, High) and which assistant saved it.
3. **Trends over single numbers.** Averages use complete days only and say how many days
   they used.
4. **Calm, private, trustworthy.** Lots of background, one accent, few words.
5. **Native iOS 18+.** System `TabView` (Today, History, Trends, Settings), `NavigationStack`
   with large titles, inset grouped lists, sheets, segmented pickers, Swift Charts, WidgetKit.
   SF Pro and SF Symbols only.
6. **Accessible.** WCAG AA in light and dark; color is never the only signal; every screen
   survives AX5 Dynamic Type.

## Color tokens

Neutral base and one calm teal accent taken from the icon background. Code uses tokens, never
hex: each token is an Asset Catalog color set with Any and Dark appearances, generated from
`system/tokens.json` by `tools/generate_design_tokens.py`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#f3f5f2` | `#0d1312` | Screen background behind grouped lists and cards (SwiftUI: a custom groupedBackground) |
| `surface` | `#ffffff` | `#172020` | Cards, list cells, sheets, widgets |
| `surface-sunken` | `#e7ebe7` | `#232d2b` | Range band track, segmented control well, neutral badge fill, skeleton blocks |
| `line` | `#d6ddd8` | `#33403c` | Hairline separators and card outlines |
| `line-strong` | `#7f8a85` | `#7d8a85` | Text field and toggle borders, the empty ring of a not-logged calendar day, chart axis ticks |
| `ink` | `#15201d` | `#edf2ef` | Primary text and numbers, on bg, surface and surface-sunken |
| `ink-muted` | `#56625d` | `#a3b0aa` | Secondary text: times, units, metadata, section footers, on bg, surface and surface-sunken (at least 4.5:1) |
| `accent` | `#24675d` | `#7fcbb5` | The one accent: primary buttons, links, selected tab, selected calendar day, range band edges, the weight trend line |
| `on-accent` | `#ffffff` | `#0d1312` | Label and icon on an accent fill (primary button) |
| `accent-soft` | `#e0eee9` | `#1c3a33` | Tinted fill behind accent text: the Your numbers badge, the selected day, info banners |
| `band` | `#c6e0d7` | `#2b5148` | Target range band on the track and the target band behind chart bars |
| `protein` | `#1f5fa0` | `#86b6ea` | Protein marks in charts and the macro dot |
| `fat` | `#9c6a00` | `#e4b24f` | Fat marks in charts and the macro dot (amber, not orange-red) |
| `carbs` | `#a24c86` | `#e39ccb` | Carbohydrate marks in charts and the macro dot |
| `destructive` | `#b3261e` | `#ff8a80` | Only for the labels of irreversible actions (Delete meal, Delete account, Delete all weight data, Revoke), on surface |
| `chart-faded` | `#9aa5a0` | `#5d6a66` | Raw weigh-in dots behind the smoothed weight line, bars for partial days |
| `link` | `#24675d` | `#7fcbb5` | Alias of `accent`: inline links, Copy and Retry |

- Macros use colors from the Okabe and Ito color-blind-safe set (blue, amber, magenta). They are
  marks, never text, always next to their word ("Protein 77 g"), and never mean good or bad.
- `destructive` appears only on the labels of irreversible actions, always followed by a
  confirmation. It never touches data, targets or weight.
- The icon's ivory `#F7F5EE` and mint `#B7DFCB` are icon colors, not UI fills.

Contrast, lowest value over the listed backgrounds (computed from `tokens.json`; the app's
`DesignTokenTests` check the same pairs on the compiled color sets):

| Pair | Light | Dark | Needed |
|---|---|---|---|
| `ink` on `bg`, `surface`, `surface-sunken` | 13.88:1 | 12.52:1 | 4.5:1 |
| `ink-muted` on `bg`, `surface`, `surface-sunken` | 5.28:1 | 6.31:1 | 4.5:1 |
| `accent` on `bg`, `surface`, `accent-soft` | 5.54:1 | 6.53:1 | 4.5:1 |
| `on-accent` on `accent` | 6.62:1 | 9.93:1 | 4.5:1 |
| `destructive` on `surface` | 6.54:1 | 7.28:1 | 4.5:1 |
| `line-strong` on `bg`, `surface` | 3.26:1 | 4.63:1 | 3:1 |
| `protein` on `bg`, `surface` | 5.98:1 | 7.83:1 | 3:1 |
| `fat` on `bg`, `surface` | 4.28:1 | 8.53:1 | 3:1 |
| `carbs` on `bg`, `surface` | 4.89:1 | 7.82:1 | 3:1 |

## Typography

SF Pro through Dynamic Type text styles only (no fixed sizes, no bundled fonts):

| Element | Style |
|---|---|
| Navigation titles | `largeTitle` bold |
| Onboarding and sheet headings | `title2` bold |
| Card and section headings | `title3` semibold |
| Meal names, row titles, button labels | `headline` |
| Reading text, list values | `body` |
| Explanations, card bodies | `callout` |
| Secondary row text, macro labels | `subheadline` |
| Status line, section footers, days-counted line | `footnote` |
| Badges, chart labels, legends | `caption` medium |
| Axis and weekday labels | `caption2` |
| URLs | `subheadline` monospaced (SF Mono) |

Every number uses SF Pro Rounded with monospaced digits: `metric-xl` (44 pt base, scaled) for the
one hero number on a screen, `metric` (`title` semibold) for averages and widgets, `metric-sm`
(`headline`) in rows. Numbers follow the person's locale; units come after a space ("77 g"),
ranges use an en dash without spaces ("1,900–2,200 kcal").

## Space, shape, elevation

- 4 pt base: 4, 8, 12, 16, 20, 24, 32. Screen margins and card padding 16, gaps between cards
  20, onboarding blocks 24. Every control has at least a 44 pt hit area.
- Continuous corners: 3 (chart bars, track ends), 6 (badges), 12 (fields, buttons, list
  sections, banners), 20 (cards, chart cards, sheet tops); fully round only for dots and pips.
- Flat: cards separate from the background by fill. One soft shadow only for floating chrome
  (Copied toast, segmented thumb). System materials respect Reduce Transparency.
- Motion: system defaults only. The waiting pulse and skeleton pulse stop under Reduce Motion.

## Components

| Component | What and states |
|---|---|
| SummaryCard | Today's hero: calories so far (`metric-xl`) and a RangeBand per macro. Calm mode drops the calorie block and shows a consistency line |
| RangeBand | Target band on a track (`band` fill, 2 pt `accent` edges), value as a thin bar; "Target 110–140 g" printed under every track. Outside the band looks identical |
| ProvenanceBadge | "Your numbers" (`person.fill`, `accent` on `accent-soft`) or "Estimated" (`plusminus`, `ink-muted` on `surface-sunken`). No third variant |
| ConfidenceIndicator | Three rising pips plus Low, Medium or High; same neutral colors for every level; only for estimated values |
| MealRow | Time, dish, kcal, P/F/C, badge, confidence, "via Claude". Whole row opens Meal detail; stacks vertically at accessibility sizes |
| IntegrationStatus | "Last meal saved 2 h ago via Claude": filled dot (ok), hollow (quiet), gray (unknown) |
| CalendarDay | Date plus filled, half or empty dot for complete, partial, not logged; selected day `accent-soft`, today bold `accent`; legend spells the states out |
| KcalBarChart | Bars per day over the target band: complete solid `ink`, partial dashed `chart-faded` (left out of the average), not logged a dot; average as an `ink` rule; text legend and chart descriptor |
| WeightTrendChart | Optional. Smoothed `accent` line over faded weigh-ins, axis not from zero, no goal line, no arrows |
| CopyField | Monospaced URL with Copy that confirms in place; wraps after "/" and ".", never hyphenates |
| Banner | Stale (`surface-sunken`), error (`surface` with outline), info (`accent-soft`); no red, no warning triangle; one action |
| TextField | `line-strong` border, 2 pt `accent` when focused; error is a 2 pt `ink` border, icon and sentence, never red |
| Button | Primary (`accent` fill), secondary (`accent-soft`), plain (`accent` text), destructive (label only, then confirmation); one primary per screen |
| Empty, loading, error | Skeletons keep the final layout; server unreachable is calm and reassures that data is safe; new users get the connection URL and steps |

## SF Symbols

Regular weight, scaled with the adjacent text. No emoji, food photos, scales, tapes, bodies or
flames; assistant names are plain text, never logos.

| Use | Symbol |
|---|---|
| Tabs: Today, History, Trends, Settings | `fork.knife`, `calendar`, `chart.bar`, `gearshape` |
| Your numbers, Estimated | `person.fill`, `plusminus` |
| Log in your chat, connect assistant | `bubble.left` |
| Data on your server, server | `lock.shield`, `server.rack` |
| Copy, retry, offline | `doc.on.doc`, `arrow.clockwise`, `wifi.slash` |
| Edit, delete | `pencil`, `trash` |
| Info, text field error | `info.circle`, `exclamationmark.circle` |
| Calm mode, meals stop arriving | `eye.slash`, `bell` |
| Apple Health, weight and energy, export | `heart.text.square`, `chart.xyaxis.line`, `square.and.arrow.up` |
| First meal received, meal time | `checkmark.circle`, `clock` |

## Copy rules

Calm, precise, private. US English, sentence case, no exclamation marks, no emoji, no em dash.
Full rules: [`system/content.md`](system/content.md).

| Write | Never write |
|---|---|
| 1,200 kcal so far · Target 1,900–2,200 kcal | 700 kcal left · You're under! |
| Fat 86 g · Target 55–80 g | Over your fat limit |
| 70 kcal lower than the previous 30 days | Great job, you cut 70 kcal |
| −0.3 kg per week | You lost weight! |
| Logged 6 of the last 7 days | 6-day streak |
| Estimated, medium confidence | Inaccurate / Bad estimate |
| Can't reach food.example.com. Your data is safe on your server. | Oops! Something went wrong. |

Every average names its days ("Averages use 18 of 30 days (12 partial or not logged days left
out)."). Destructive confirmations list exactly what goes. Copy reminds people that data they
logged elsewhere is not touched.

## Accessibility

- Contrast as in the table above, in both themes.
- Color is never alone: badges have words, calendar states have shapes and a legend, macros have
  labels, charts have legends and `accessibilityChartDescriptor`.
- VoiceOver: range bands read "Protein, 77 grams, target 110 to 140 grams"; days read
  "17, complete"; confidence reads "Medium confidence"; copy buttons announce "Copied".
- Dynamic Type to AX5: rows stack, labels go above values, nothing truncates (screen G2). Dense
  grids (the month calendar) cap at AX2 and chart axis labels at xxxLarge, like system apps;
  their values stay available in text and to VoiceOver.

## Screens

High-fidelity screens, iPhone 6.3" (393 × 852 pt), exported at 3x to [`mockups/`](mockups/) in
flow order (37 PNGs; long screens at full scroll length) and as
[`mockups/mockups.pdf`](mockups/mockups.pdf):

- Onboarding: A1 Welcome, A2 Server and its https error, A3 Sign in (system web sheet), A4
  Connect your AI assistant (light and dark), A5 Waiting and First meal received.
- Today: B1 Today, B2 empty (new user, no meals yet today), B3 Meal detail and delete
  confirmation, B4 Edit meal; B1, B2 new user, B3 and B4 also in dark.
- History and Trends: C1 month, D1 Trends, D2 Weekly review, D3 Weight and energy on and off;
  D1 to D3 also in dark.
- Settings: E1 Settings, E2 Connected assistants with the Revoke alert, E3 Delete account.
- Widgets and states: F1 Home Screen and Lock Screen widgets, G1 loading, server unreachable,
  offline with cached data, G2 largest accessibility size, G3 Calm mode.

The PNGs were rendered from the artifact's screen boards with headless Chrome (device frame and
captions removed). SF Symbols appear as the boards' simple stand-ins; the app uses the real
symbols. All data is synthetic.

## App icon

### Selected direction

**Fork + knife conversation (R4), requested by the owner on 2026-10-18.**
The owner selected concept 08, then requested a kitchen knife beside the fork and the
pair centered inside the conversation bubble. The `app-icon*.svg` masters implement this
refinement. The original bubble and palette remain unchanged.

The fork sits on the left, with the kitchen knife on the right. The rounded handles and
simple silhouettes match the selected icon's style. The speech bubble represents logging
through the user's existing AI assistant; it does not imply an in-app chat.

Ten concepts and four refinements remain in `icon/concepts.pdf` for reference. R4 and the
final page show the current artwork; concept 08 records the original fork-only selection.

### Artwork and colors

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

### Files

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

The 1024 px PNG exports are in the app's asset catalog (`HealthyEating/Resources/Assets.xcassets/
AppIcon.appiconset`): default and dark opaque, tinted with alpha. The compiled `Assets.car`
contains all three renditions (default, `UIAppearanceDark`, `ISAppearanceTintable`, checked with
`assetutil` on 2026-10-19). `AppIconImage.imageset` holds default and dark copies for the Welcome
screen. The default icon was seen on the iOS 27 simulator Home Screen with the system mask. The
dark and tinted Home Screen appearances and a physical device have not been checked yet (the
Home Screen icon style has to be changed by hand: long-press, Edit, Customize).

Current Apple guidance also covers layered icons and Icon Composer. This package meets the
issue's SVG brief, but does not claim to deliver all contemporary Liquid Glass/clear variants.
Sources checked 2026-10-18:
[Apple app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
and [Xcode asset catalog configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

### Review and rights

The supplied 29 px renders retain the fork and knife silhouettes, bubble and speech tail. The scalloped
prong tips become subtle at this size; human recognition and device review remain pending. Review sheets use an approximate corner mask only; exported masters remain square.
The PDF was rendered and visually reviewed. Structural checks cover all 19 SVGs, dimensions,
allowed geometric elements, no external references, opacity and grayscale alpha requirements.
Human recognizability testing and actual home-screen checks remain pending.

Original vector geometry authored for Healthy Eating; licensed under the repository's MIT
license. No third-party icon, SF Symbol, bundled font, food photo or user data is included.
PDF labels use standard PDF fonts; preview labels are rasterized from the local system font.
No image-generation model or Claude Design was used for the icon.
