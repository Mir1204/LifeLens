# Tasks

## Completed

### Mobile App

- Flutter Android project created
- Dashboard screen implemented
- Productivity, Financial Health, and Stress Risk score cards added
- Expense entry screen added
- Planner/task entry screen added
- Sleep, steps, and screen-time input screen added
- Profile screen added for Mir
- Local in-memory state added through `LifeLensStore`
- Local rule-based score calculation added
- Recommendation display added
- Flutter app pushed to GitHub

### Backend

- FastAPI app added
- CORS middleware added
- `/health` route added
- `/predict/daily-score` route added
- SQLAlchemy database setup added
- `daily_entries` model added
- Request/response schemas added
- Rolling feature engineering added
- Rule-based scoring service added
- Prediction service with model fallback added
- Synthetic data generation script added
- Overspending training script added

### Documentation

- Vision document
- System architecture
- API specification
- Database design
- AI architecture
- Federated learning future scope
- Deployment guide
- Security notes
- Task list
- Known issues

## Next Tasks

### High Priority

- Connect Flutter `PredictionApiService` to FastAPI using HTTP POST.
- Add `http` or `dio` dependency to Flutter.
- Add backend response parsing into `LifestyleScores`.
- Add `user_id` and `total_workload` to Flutter API payload.
- Fill `backend/requirements.txt`.
- Complete `train_burnout_model.py`.
- Add `.env` to `.gitignore`.
- Remove or rotate any real credentials committed in `backend/.env`.

### Medium Priority

- Add persistent local storage in Flutter using SQLite, Drift, or SharedPreferences.
- Add charts for weekly trends.
- Add validation messages on forms.
- Add backend error/loading states in Flutter.
- Add notification support for high stress or overspending risk.
- Add SQLite fallback configuration for quick local backend demo.

### Later

- Health Connect integration for sleep and steps.
- UsageStatsManager integration for real screen time.
- Authentication.
- Supabase/PostgreSQL hosted database.
- Render backend deployment.
- Release APK build.

## Suggested Demo Milestone

For the next project check:

1. Run backend locally.
2. Open FastAPI docs.
3. Send sample `/predict/daily-score` payload.
4. Show Flutter dashboard.
5. Explain that Flutter API connection is the next integration step.

## Role Split

### Mir

- Flutter screens
- Form validation
- API service integration
- Dashboard UI polish
- APK build/demo

### Mark

- Backend dependency setup
- Database setup
- ML training scripts
- Model artifacts
- Backend deployment
