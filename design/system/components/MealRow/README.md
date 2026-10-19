# MealRow

One logged meal in a list: time, dish name, kcal, protein, provenance badge, confidence and the assistant that saved it.

- Props: `time` ("08:10", 24 h in the user's time zone; 12 h with AM/PM for en-US system setting), `name`, `kcal`, `protein`, optional `fat` and `carbs`, `provenance` (`'user' | 'estimated'`), `confidence` (only with estimated), `assistant` ("Claude", "ChatGPT"), `hideKcal` (Calm mode).
- The whole row is the tap target and opens Meal detail (B3). Swipe actions: Edit, Delete (Delete asks to confirm).
- Assistant names are plain text ("via Claude"), never third-party logos.
- Lives inside an inset grouped list section on `surface`; separators are `line`.
