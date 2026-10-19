# KcalBarChart

Average calories per day as bars over the target band, for 7, 30 or 90 days.

- Props: `days` (`[{label, kcal, state}]`, state `'complete' | 'partial' | 'none'`), `min`, `max` (target band), `average` (from complete days only), `scaleMax` (default 3,000).
- Complete days: solid `ink` bars. Partial days: dashed `chart-faded` outline, left out of the average. Not logged: a small dot on the baseline.
- Band `band` with dashed `accent` edges; the average is a solid `ink` line, named in the legend.
- Bars above the band look exactly like bars below it.
- Always pair it with the days-counted line ("Averages use 5 of 7 days (2 partial or not logged days left out)").
- SwiftUI: Swift Charts `BarMark` + `RectangleMark` for the band + `RuleMark` for the average; `.accessibilityChartDescriptor`.
