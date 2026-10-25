"""Prints the -only-testing arguments for one CI shard of the UI tests.

Every XCTestCase class in HealthyEatingUITests/ goes to exactly one shard, so a new test class
runs without editing the workflow. Classes are spread longest first onto the shard with the
least work, using the seconds each class took on CI (unknown classes count as DEFAULT_SECONDS).

    python3 .github/scripts/ui_test_shard.py <shard index> <shard count>
"""

import re
import sys
from pathlib import Path

TARGET = "HealthyEatingUITests"
# Seconds per class on the macos-26 runner (CI run 39998666888); only used to balance shards.
SECONDS = {
    "CalmModeUITests": 136,
    "WeightUITests": 99,
    "SettingsUITests": 82,
    "OnboardingUITests": 71,
    "MealUITests": 52,
    "OptionalNutrientUITests": 32,
    "OfflineUITests": 26,
    "WeeklyReviewUITests": 24,
    "HistoryUITests": 23,
    "UsualMealsUITests": 19,
    "SignInEndToEndUITests": 1,
}
DEFAULT_SECONDS = 40


def test_classes(folder: Path) -> list[str]:
    pattern = re.compile(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b", re.MULTILINE)
    return sorted({name for path in folder.glob("*.swift") for name in pattern.findall(path.read_text())})


def shards(classes: list[str], count: int) -> list[list[str]]:
    bins: list[list[str]] = [[] for _ in range(count)]
    load = [0] * count
    for name in sorted(classes, key=lambda c: (-SECONDS.get(c, DEFAULT_SECONDS), c)):
        lightest = load.index(min(load))
        bins[lightest].append(name)
        load[lightest] += SECONDS.get(name, DEFAULT_SECONDS)
    return bins


def main() -> None:
    index, count = int(sys.argv[1]), int(sys.argv[2])
    root = Path(__file__).resolve().parents[2]
    classes = test_classes(root / TARGET)
    if not classes:
        sys.exit(f"No XCTestCase classes found in {TARGET}/")
    mine = shards(classes, count)[index]
    print(" ".join(f"-only-testing:{TARGET}/{name}" for name in mine))


if __name__ == "__main__":
    main()
