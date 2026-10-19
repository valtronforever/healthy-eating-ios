# ConfidenceIndicator

Shows how sure the assistant was about an estimate: three rising pips plus the word Low, Medium or High.

- Props: `level` `'low' | 'medium' | 'high'`; `short` drops the word "confidence" (use in meal rows, keep it in Meal detail).
- Only for estimated values. A meal with `Your numbers` shows no confidence.
- Pips use `ink-muted` filled and `line-strong` outlined, the same for every level: low confidence is information, not a warning. No color ramp.
- Accessibility label is always the full phrase, for example "Medium confidence".
- In Meal detail, pair it with a one-line reason from the backend ("Portion estimated from a photo").
