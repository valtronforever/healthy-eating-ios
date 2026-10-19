# ProvenanceBadge

Says where a meal's numbers came from: the person's own calculation ("Your numbers") or the assistant's estimate ("Estimated").

- Props: `kind` `'user' | 'estimated'`. No other variants; never invent a third label.
- Always text plus a glyph (SF Symbols `person.fill` and `plusminus`). Color is never the only signal.
- `Your numbers` sits on `accent-soft` in `accent`; `Estimated` sits on `surface-sunken` in `ink-muted`. Neither tone means better or worse.
- Place it in the meal row's meta line and next to each estimated value in Meal detail. An edited value drops its `Estimated` badge.
- SwiftUI: a `Label` in `.caption.weight(.medium)` with a `RoundedRectangle(cornerRadius: 6, style: .continuous)` background.
