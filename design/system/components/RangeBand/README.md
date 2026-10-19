# RangeBand

A target shown as a range on a track, with the day's value as a thin bar that simply ends where it ends.

- Props: `label`, `value`, `min`, `max`, `unit` (`'g'` default, or `'kcal'`), `color` (a macro token name: `protein`, `fat`, `carbs`; omitted = `ink`), `scaleMax` (track end; default 130% of `max`), `compact` (hides the head line).
- Track `surface-sunken`; band `band` with 2 px `accent` edges; value bar in the macro color or `ink`.
- Over and under look identical: no color change, no icon, no "over" or "left" wording. The second example (Fat 86 g against 55-80 g) is the reference for "outside the band".
- Always print the target as text under the track ("Target 110-140 g"), so the band is never the only carrier of meaning.
- SwiftUI: a `GeometryReader`-free `Canvas` or `Gauge` with a custom style; accessibility value "77 grams, target 110 to 140 grams".
