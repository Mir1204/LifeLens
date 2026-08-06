# System Architecture

## Current Architecture

LifeLens currently uses a two-part architecture:

1. Flutter Android mobile app
2. FastAPI backend with database and ML services

```text
Flutter Android App
  |
  | Daily lifestyle payload
  v
FastAPI Backend
  |
  | Persist daily entry
  v
PostgreSQL / SQLite-compatible SQLAlchemy layer
  |
  | Historical records
  v
Feature Engineering
  |
  | Rolling 3-day and 7-day features
  v
Scoring + ML Prediction Services
  |
  | Scores, risk labels, recommendations
  v
Flutter Dashboard
```

## Mobile App

Path: `lib/`

The Flutter app contains:

- `features/dashboard`: score cards, daily summary, recommendations
- `features/expenses`: manual expense entry
- `features/planner`: manual task/workload entry
- `features/insights`: manual health input, Health Connect reading, screen-time usage reading, and trend cards
- `features/profile`: simple Mir profile/demo screen
- `services/local_database_service.dart`: SQLite persistence for local source-of-truth data
- `services/lifelens_store.dart`: app state, local score calculation, backend sync, and trend history
- `services/prediction_api_service.dart`: FastAPI integration
- `services/device_data_service.dart`: Health Connect and UsageStats access
- `services/notification_service.dart`: local lifestyle risk alerts

The app keeps local score fallback for demo reliability, but can sync with FastAPI and display backend scores when the backend is available.

## Backend

Path: `backend/`

The backend contains:

- `main.py`: FastAPI app setup and CORS
- `app/api/routes.py`: API routes
- `app/database.py`: SQLAlchemy engine/session setup
- `app/models/daily_entry.py`: daily lifestyle history table
- `app/schemas/prediction.py`: request/response schemas
- `app/services/feature_engineering.py`: rolling features
- `app/services/scoring.py`: rule-based scores and recommendations
- `app/services/prediction.py`: ML model loading and fallback prediction
- `app/ml/training`: synthetic data and model training scripts

## Data Flow

1. User enters or collects lifestyle data in Flutter.
2. Flutter builds a daily payload.
3. Backend receives payload at `/predict/daily-score`.
4. Backend upserts one daily record per user/date.
5. Backend builds rolling features from recent daily history.
6. Backend calculates productivity and financial health using rules.
7. Backend predicts burnout and overspending risk using trained models if available.
8. If model artifacts are missing, backend uses fallback formula logic.
9. Backend returns scores, risk labels, and recommendations.
10. Flutter displays the response on the dashboard.

## Android Integrations

### Health Connect

Current use:

- Sleep duration
- Steps

### UsageStatsManager

Current use:

- Daily screen time
- App usage trends

Manual input remains available as a fallback when permissions or data sources are unavailable.

## Architecture Decisions

- Flutter is used because the project requires Android mobile development and fast UI iteration.
- FastAPI is used because it is lightweight, Python-based, and suitable for ML integration.
- Rule-based scoring is kept for explainability.
- ML is used for risk classification where historical trends matter.
- Database history is required because burnout/overspending risk depends on trends, not only same-day data.
