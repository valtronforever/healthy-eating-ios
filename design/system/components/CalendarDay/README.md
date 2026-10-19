# CalendarDay

A day cell in the History month: the date and one dot whose shape says complete, partial or not logged.

- Props: `day`, `state` `'complete' | 'partial' | 'none' | 'future'`, `selected`, `today`.
- Shapes, not colors: filled dot = complete, half-filled = partial, empty ring (`line-strong`) = not logged. The legend under the month spells all three out.
- Selected day: `accent-soft` fill. Today: bold number in `accent`.
- Hit area 44 x 52 pt. VoiceOver reads "17, complete".
- No streak counting, no highlighting of runs of complete days.
