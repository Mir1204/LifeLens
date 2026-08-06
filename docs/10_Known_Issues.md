# Known Issues

## 1. Flutter App Not Yet Connected To Backend

The Flutter app currently uses local in-memory scoring through:

```text
lib/services/lifelens_store.dart
```

The backend API placeholder exists:

```text
lib/services/prediction_api_service.dart
```

But the actual HTTP POST call is not implemented yet.

## 2. Flutter API Payload Missing Backend Fields

Backend expects:

- `user_id`
- `total_workload`

Current Flutter payload should be updated to include these before integration.

## 3. Backend Requirements File Is Empty

Current file:

```text
backend/requirements.txt
```

It should include at least:

```text
fastapi
uvicorn
sqlalchemy
psycopg2-binary
pydantic-settings
joblib
pandas
scikit-learn
numpy
```

## 4. Burnout Training Script Is Empty

Current file:

```text
backend/app/ml/training/train_burnout_model.py
```

The prediction service references a burnout model artifact, but the training script is not implemented yet.

## 5. `.env` File Was Committed

The backend update includes:

```text
backend/.env
```

This should normally not be tracked in Git.

Recommended fix:

- Add `backend/.env` to `.gitignore`
- Keep `backend/.env.example`
- Rotate any real credentials if needed

## 6. Open CORS Policy

Backend currently allows all origins.

This is okay for development but should be restricted before deployment.

## 7. No Authentication

The backend trusts `user_id` sent in the request body.

Future production versions need authentication so users cannot access or overwrite another user's data.

## 8. PostgreSQL Required By Default

The default `DATABASE_URL` expects local PostgreSQL.

This may fail on machines where PostgreSQL is not configured. SQLite can be used for demo by changing the database URL.

## 9. Model Artifacts Not Present

Expected paths:

```text
app/ml/artifacts/burnout_model.joblib
app/ml/artifacts/overspend_model.joblib
```

If artifacts are missing, backend fallback logic keeps predictions working, but ML model demonstration will be incomplete.

## 10. Manual Inputs Only

Current app does not yet use:

- Health Connect
- UsageStatsManager

Sleep, steps, and screen time are entered manually for MVP testing.
