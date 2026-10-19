# SummaryCard

The top of Today: calories so far as the one hero number, then protein, fat and carbohydrates, each against its target range.

- Props: `kcal`, `kcalMin`, `kcalMax`, `macros` (`[{label, value, min, max, color}]` in the order Protein, Fat, Carbohydrates), `calm` (hides the calorie block for Calm mode), `footer` (one factual line).
- Hero number in `metric-xl` (SF Pro Rounded, monospaced digits), unit "kcal so far" in `ink-muted`.
- Every bar is a `RangeBand`; nothing on the card changes color with the value.
- Calm mode: drop the calorie block, keep the macros, and the footer reports consistency ("Logged 5 of the last 7 days").
- At AX sizes the card stays one column; numbers wrap below labels rather than truncate.
