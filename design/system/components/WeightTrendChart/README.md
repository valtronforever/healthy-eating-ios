# WeightTrendChart

The optional weight view: a smoothed trend line in `accent` with the raw weigh-ins as faded dots behind it.

- Props: `points` (`[{raw, trend}]`, `raw` may be null), `yMin`, `yMax`, `yStep`, `xLabels` (`[{i, text}]`).
- Raw dots `chart-faded`; trend 3 px `accent`, last point marked. The axis never starts at zero and never shows a goal line.
- No arrows, no colors for up or down, no celebration. The number beside it reads "78.4 kg trend · −0.3 kg per week".
- Only shown when weight tracking is on (off by default).
