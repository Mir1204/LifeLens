# Known Issues

## 1. Backend `.env` Was Previously Tracked

The backend update previously included:

```text
backend/.env
```

This file should be removed from Git tracking:

```powershell
git rm --cached backend/.env
```

Real credentials should stay in ignored `backend/.env.local`.

## 2. Package Resolution Required

After the latest app features, run:

```powershell
flutter pub get
```

Required new packages include SQLite, charts, and local notifications.

## 3. Local Demo Auth Is Not Production Auth

Signup/login is local-only for demo. It does not provide server-side identity verification.

Future production versions should use Firebase Auth, Supabase Auth, or JWT-based FastAPI auth.

## 4. Burnout Training Script Is Empty

```text
backend/app/ml/training/train_burnout_model.py
```

## 5. Open CORS Policy

Backend currently allows all origins. This is okay for development but should be restricted before deployment.

## 6. PostgreSQL Required By Default

The default `DATABASE_URL` expects local PostgreSQL.

This may fail on machines where PostgreSQL is not configured. SQLite can be used for demo by changing the database URL.

## 7. Model Artifacts Not Present

Expected paths:

```text
app/ml/artifacts/burnout_model.joblib
app/ml/artifacts/overspend_model.joblib
```

If artifacts are missing, backend fallback logic keeps predictions working, but ML model demonstration will be incomplete.

## 8. Health Connect Data Availability

Health Connect may not always return sleep records unless the user has sleep data available from a supported app/device. Manual sleep input remains the fallback.
