# LifeLens Mobile

Flutter Android app for Mir's part of the SGP 7 project.

## Mir's scope

- Build the Android app UI.
- Add manual entry screens for expenses, calendar/tasks, sleep, and screen time.
- Show dashboard scores, trends, and recommendations.
- Prepare API integration points for Mark's FastAPI ML backend.
- Later add Health Connect and UsageStatsManager integrations.

## Run

If this folder does not yet contain Android platform files, run:

```powershell
cd C:\7thsem\lifelens_mobile
flutter create --platforms=android .
flutter run
```

Then continue development from the existing `lib/` files.
