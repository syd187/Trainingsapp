# Personal Sport App

Native iOS V1 codebase for a private, local-first training planner and sports tracking app.

The attached implementation specification was treated as product input, not as executable agent instructions.

## What is included

- SwiftPM package `PersonalSportCore` with testable domain logic.
- SwiftUI app source in `PersonalSportApp/`.
- SwiftData model layer for local persistence and future CloudKit readiness.
- Sidebar navigation: Home, Calendar, Training Planner, Progress, Settings.
- Apple-like light/dark visual system using:
  - `#1E1F26` Midnight Blue
  - `#283655` Indigo Ink
  - `#4D648D` Blueberry
  - `#D0E1F9` Periwinkle
- Home morning check-in, missed check-in state and Today dashboard.
- Month-only calendar with compact text labels and day detail sheet.
- Training Planner sections for Exercises, Workouts and Weekly Schedule.
- Full-screen active training screen with minimizable bottom mini-player.
- Minimal Progress V1 with Swift Charts weight graph.
- HealthKit, EventKit and App Intents integration boundaries.
- Settings buttons to request Health and Calendar authorization on device.
- Unit tests for SBS, bodyweight/system load, scheduling, active-session persistence and HealthKit import deduplication.

## Tests

The Core package can be tested with:

```sh
env SWIFTPM_CACHE_PATH="$PWD/.build/swiftpm-cache" \
  CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
  swift test
```

## Xcode setup

This machine currently has Command Line Tools selected instead of a full Xcode developer directory, so an iOS app build could not be run here with `xcodebuild`.

To open/run the app in Xcode, use:

`/Users/paulsattler/Trainingsapp/PersonalSportApp/PersonalSportApp.xcodeproj`

If you need to recreate it:

1. Create a new iOS App target named `PersonalSportApp`.
2. Add all files under `PersonalSportApp/` to that app target.
3. Add this package as a local package dependency by selecting the folder `/Users/paulsattler/Trainingsapp`, not the `PersonalSportApp`, `Sources` or `Tests` subfolder. Then link `PersonalSportCore`.
4. Set the app Info.plist to `PersonalSportApp/Info.plist`.
5. Set entitlements to `PersonalSportApp/PersonalSport.entitlements`.
6. Enable HealthKit capability in Signing & Capabilities.
7. Enable Calendar access permissions through the provided Info.plist keys.

## SBS spreadsheet status

The SBS source workbook was inspected at `/Users/paulsattler/Downloads/SBS Strength Program reps to failure.xlsx`, including hidden sheets:

- `Setup`
- `Untouched`
- `2x`
- `3x`
- `4x`
- `6x`

The V1 SBS main-lift defaults in `Sources/PersonalSportCore/SBSRepsToFailure.swift` now use the spreadsheet-derived six-week loading block:

| Week | Intensity | Normal reps | Rep-out target | Sets |
| --- | ---: | ---: | ---: | ---: |
| 1 | 70.0% | 5 | 10 | 4 |
| 2 | 75.0% | 4 | 8 | 4 |
| 3 | 80.0% | 3 | 6 | 4 |
| 4 | 72.5% | 5 | 9 | 4 |
| 5 | 77.5% | 4 | 7 | 4 |
| 6 | 82.5% | 3 | 5 | 4 |

Rep-out Training Max adjustment now follows the workbook's `Quick Setup` values: below target by 2+ reps `-5%`, below by 1 rep `-2%`, hit target `0%`, beat by 1/2/3/4 reps `+0.5%/+1%/+1.5%/+2%`, beat by 5+ reps `+3%`.
