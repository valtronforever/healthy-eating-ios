The private, honest dashboard for people who log food by talking to their AI assistant. The iPhone app never logs new food: it shows trends, lets people fix or delete a meal, and proves the connection to their assistant works. Everything here serves three ideas: **neutral feedback, honest data, trends over single numbers.**

## Principles (hard rules)

1. **Neutral feedback.** A value above its target and a value below it look identical. Targets are always ranges (`RangeBand`). No red for data, no warning icons, no celebration, no streaks, badges, trophies, confetti, flames or scores. No "good", "bad", "over", "left", "cheat", "guilt-free".
2. **Honest data.** Every meal shows where its numbers came from (`ProvenanceBadge`: "Your numbers" or "Estimated"), how sure the estimate is (`ConfidenceIndicator`: Low, Medium, High) and which assistant saved it ("via Claude").
3. **Trends over single numbers.** Averages use complete days only, and the screen says so: "Averages use 18 of 30 days (12 partial or not logged days left out)."
4. **Calm, private, trustworthy.** Lots of `bg`, one accent, few words. Friendly, never childish, clinical or gym-like.
5. **Native iOS 18+.** SwiftUI standard components: `TabView` with 4 tabs (Today, History, Trends, Settings), `NavigationStack` with large titles, inset grouped `List`, sheets, `Toggle`, segmented `Picker`, Swift Charts, WidgetKit. SF Pro and SF Symbols only.
6. **Accessible.** WCAG AA in light and dark (checked for every token pair named below). Color is never the only signal. Every screen survives AX5 Dynamic Type.

## Color

Neutral base, one calm teal (`accent`) taken from the approved icon background `#24675D`. Use tokens, never hex, in code (an Asset Catalog color set per token with Any and Dark appearances).

- Screens sit on `bg`; cards, list cells, sheets and widgets on `surface`. Tracks, wells, skeletons and the neutral badge use `surface-sunken`. Hairlines are `line`.
- Text is `ink`, secondary text `ink-muted`. Both hold 4.5:1 on `bg`, `surface` and `surface-sunken` in both themes.
- `accent` is for the one primary action per screen, links, the selected tab and day, band edges and the weight trend. Text on an accent fill is `on-accent` (white in light, near-black in dark). `accent-soft` tints the "Your numbers" badge, the selected calendar day and info banners.
- `band` fills target ranges; its edges are always drawn in `accent`, so the band reads even where its fill is faint.
- Macros: `protein` (blue), `fat` (amber), `carbs` (magenta), from the Okabe and Ito color-blind-safe set. They are marks, never text, and always sit next to their word ("Protein 77 g"). Never use them to mean good or bad.
- `destructive` appears only on the labels of irreversible actions (Delete meal, Revoke, Delete all weight data, Delete account) and always leads to a confirmation. It never touches data, targets or weight.
- `chart-faded` is the quiet layer in charts: raw weigh-ins and partial days.
- `line-strong` is for anything that must be seen as a boundary: field and toggle outlines, the empty "not logged" ring, chart axes (3:1 in both themes).

The icon's ivory `#F7F5EE` and dark-mode mint `#B7DFCB` stay icon colors. Do not use them as UI fills.

## Type

SF Pro via Dynamic Type text styles (`type` groups). Never fixed point sizes: use `.font(.headline)` and friends so everything scales to AX5.

- Navigation titles: `large-title`. Onboarding and sheet headings: `title-2`. Card and section headings: `title-3`.
- Meal names, row titles, button labels: `headline`. Reading text: `body`; explanations: `callout`; secondary row text: `subheadline`; status line, section footers and the days-counted line: `footnote`; badges and chart labels: `caption-1`; axis and weekday labels: `caption-2`.
- Every number uses SF Pro Rounded with monospaced digits (`.fontDesign(.rounded).monospacedDigit()`), echoing the icon's rounded strokes: `metric-xl` for the one hero number on a screen, `metric` for averages and widgets, `metric-sm` in rows.
- URLs use `code` (SF Mono).
- Numbers: US locale grouping ("1,200"), unit after a space ("77 g", "610 kcal"), ranges with an en dash and no spaces ("1,900–2,200 kcal").

## Space, shape, elevation

- 4 pt base: `space-1` 4 to `space-8` 32. Screen margins and card padding `space-4`, gaps between cards `space-5`, onboarding blocks `space-6`. Every control has at least a `tap-target` (44 pt) hit area.
- Corners are continuous (`RoundedRectangle(cornerRadius:style: .continuous)`): `radius-sm` badges, `radius-md` fields, buttons and list sections, `radius-lg` cards and chart cards. `radius-full` only for dots, pips and toggles.
- Flat: separation comes from `surface` on `bg`. `shadow-float` only for things that float (Copied toast, segmented thumb).
- Motion: system defaults only. The waiting pulse (A5) and skeleton pulse stop under Reduce Motion. No celebratory animation anywhere.

## Components

Live previews and guidelines are in Components. In order of importance:

- **SummaryCard**: Today's hero. Calories (`metric-xl`) plus a `RangeBand` per macro. Calm mode drops the calorie block.
- **RangeBand**: a target as a band on a track, the value as a thin bar. Prints "Target 110–140 g" under every track.
- **ProvenanceBadge** and **ConfidenceIndicator**: provenance and confidence, text first, glyph second.
- **MealRow**: time, name, kcal, protein, badge, confidence, "via Claude". The row opens Meal detail.
- **IntegrationStatus**: the always-visible line "Last meal saved 2 h ago via Claude".
- **CalendarDay**: filled, half and empty dots for complete, partial and not logged.
- **KcalBarChart** and **WeightTrendChart**: Swift Charts with a target band, average rule, faded partial days and raw weigh-ins.
- **Button** (primary, secondary, plain, destructive), **SegmentedControl**, **ListRow** with **Toggle** inside a **Section**, **TextField**, **CopyField**, **Banner** (stale, error, info), **Skeleton**.

## Screens

High-fidelity screens live in Components › Screens, one board per area, every phone at 393 × 852 pt and built from the components above:

- **ScreensOnboarding**: A1 Welcome, A2 Server (and its error state), A3 Sign in, A4 Connect your AI assistant (light and dark; the segmented control switches the steps), A5 Waiting and First meal received.
- **ScreensToday**: B1 Today, B2 both empty states, B3 Meal detail and its delete confirmation, B4 Edit meal. B1, B2 (new user), B3 and B4 also in dark.
- **ScreensHistoryTrends**: C1 History month, D1 Trends, D2 Weekly review, D3 Weight and energy on and off. All Trends screens also in dark.
- **ScreensSettings**: E1 Settings, E2 Connected assistants with the Revoke alert, E3 Delete account.
- **ScreensWidgetsStates**: F1 home and lock screen widgets, G1 loading, server unreachable and offline, G2 the largest accessibility text size, G3 Calm mode.

The approved grayscale wireframes stay under Components › Wireframes for reference. The phone frame, status bar, navigation bar, tab bar and keypad used to draw the boards (`PhoneFrame`, `NavBar`, `TabBar`, `StatusBar`, `Keypad`) are mockup chrome, not app components: in the app these are the system's own.

## Charts

- Bars for calories per day; complete days solid `ink`, partial days a dashed `chart-faded` outline, not-logged days a dot on the baseline.
- The target band sits behind the bars; the average is a solid `ink` rule named in the legend.
- Every chart has a text legend and an accessibility chart descriptor. Values are readable without color.
- Weight: smoothed `accent` line over faded dots, axis not from zero, no goal line, no arrows.

## Iconography

SF Symbols, regular weight, scaled with the text they sit beside (`.imageScale(.medium)`). No emoji, no food photography, no scales, measuring tapes, bodies or flames. Assistant names are plain text, never their logos.

| Use | SF Symbol |
| --- | --- |
| Today tab | `fork.knife` |
| History tab | `calendar` |
| Trends tab | `chart.bar` |
| Settings tab | `gearshape` |
| Your numbers badge | `person.fill` |
| Estimated badge | `plusminus` |
| Log in your chat (A1), connect assistant | `bubble.left` |
| Your data stays on your server (A1), server | `lock.shield`, `server.rack` |
| Copy | `doc.on.doc` |
| Meal time, last saved | `clock` |
| Calm mode | `eye.slash` |
| Offline | `wifi.slash` |
| Retry | `arrow.clockwise` |
| Edit, Delete | `pencil`, `trash` |
| Info banner, How this is calculated | `info.circle` |
| Text field error | `exclamationmark.circle` |
| Notice when meals stop arriving | `bell` |
| Back | system back button (`chevron.left`) |
| Apple Health | `heart.text.square` (system convention) |
| Weight and energy | `chart.xyaxis.line` |
| Export | `square.and.arrow.up` |
| First meal received | `checkmark.circle` |

The web previews draw simple stand-ins for these (the `Icon` component); they are not the real symbols.

## Accessibility

- Contrast: every text token pair above is 4.5:1 or more in both themes; marks, borders and band edges 3:1 or more.
- Color is never alone: badges have words, calendar states have shapes and a legend, macros have labels, charts have legends.
- Dynamic Type to AX5: at accessibility sizes rows stack vertically (time, name, kcal on separate lines), labels go above values, nothing truncates. See wireframe G2.
- VoiceOver: range bands read "Protein, 77 grams, target 110 to 140 grams"; days read "17, complete"; confidence reads "Medium confidence".
- Reduce Motion stops every pulse. Reduce Transparency is respected by system materials.

## Dark mode

Same layout, same rules. Dark `accent` lightens to mint-teal and takes dark `on-accent` text; bars in charts switch to light `ink`. Dark versions exist for A4, B1, B2, B3, B4 and D1 to D3; every other screen follows the same tokens.

## App icon

Use the approved R4 "Fork + knife conversation" files in Assets › AppIcon exactly as supplied. Details in the App icon section.
