# LifeLens

Flutter Android app and FastAPI backend for the SGP 7 LifeLens project.

## Mir's scope

- Build the Android app UI.
- Add manual entry screens for expenses, calendar/tasks, sleep, and screen time.
- Show dashboard scores, trends, and recommendations.
- Connect the Flutter app to Mark's FastAPI backend.
- Add local demo login/signup.
- Add Health Connect and screen-time integrations for Android.

## Flutter Run

For Samsung A15 testing, keep the phone and laptop on the same Wi-Fi/hotspot.

```powershell
cd C:\7thsem\lifelens_mobile
flutter pub get
flutter run
```

The app currently calls the backend at:

```text
http://172.20.10.2:8000
```

Update `lib/services/prediction_api_service.dart` if your laptop IP changes.

## Backend Run

Create a backend virtual environment:

```powershell
cd C:\7thsem\lifelens_mobile\backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Open API docs:

```text
http://localhost:8000/docs
```

## Local Environment

The backend reads `.env.local` first, then `.env`.

Use `.env.local` for real credentials:

```env
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@db.cmfmdusouqphyhnnqsyq.supabase.co:5432/postgres?sslmode=require
BURNOUT_MODEL_PATH=app/ml/artifacts/burnout_model.joblib
OVERSPEND_MODEL_PATH=app/ml/artifacts/overspend_model.joblib
```

Do not push `.env.local`.

## Android Permissions

Health Connect:

- Steps
- Sleep

Screen time:

- Total screen time
- Most used apps

For screen time, open the app's **Usage Access Settings** button and allow LifeLens.

## Local App Data

The Flutter app now uses SQLite through `sqflite`.

Local tables store:

- users
- expenses
- planner tasks
- health records
- most-used apps
- score snapshots
- backend URL settings

This keeps the app usable even before backend sync succeeds.

## Dashboard Features

- Backend sync with local fallback
- Productivity and spending trend charts
- Expense category breakdown
- Sleep and screen-time trend charts
- Local notifications for high stress, overspending, high screen time, and low sleep
