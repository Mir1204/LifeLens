# Deployment

## Current Development Setup

LifeLens has two runnable parts:

1. Flutter Android app
2. FastAPI backend

## Flutter App

Project root:

```text
C:\7thsem\lifelens_mobile
```

Run:

```powershell
flutter pub get
flutter run
```

Build APK:

```powershell
flutter build apk
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Backend Setup

Backend root:

```text
C:\7thsem\lifelens_mobile\backend
```

Recommended virtual environment:

```powershell
cd C:\7thsem\lifelens_mobile\backend
python -m venv .venv
.\.venv\Scripts\activate
pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic-settings joblib pandas scikit-learn numpy
```

Backend dependencies are listed in `backend/requirements.txt`.

Run backend:

```powershell
uvicorn main:app --reload
```

Open API docs:

```text
http://localhost:8000/docs
```

## Database

Default backend config expects PostgreSQL:

```text
postgresql://lifelens_user:lifelens_pass@localhost:5432/lifelens_db
```

For faster local testing, SQLite can be used by changing `DATABASE_URL`:

```text
sqlite:///./lifelens.db
```

## Flutter To Backend URLs

Android emulator:

```text
http://10.0.2.2:8000
```

Physical Android phone on same Wi-Fi:

```text
http://<laptop-ip-address>:8000
```

Example:

```text
http://192.168.1.10:8000
```

## Production Deployment Plan

### Backend

Possible hosting:

- Render
- Railway
- Supabase Edge/hosted backend alternative
- VPS

Recommended for semester:

- Render web service
- PostgreSQL database
- Environment variables for secrets

### Database

Possible hosting:

- Supabase PostgreSQL
- Render PostgreSQL
- Neon PostgreSQL

### Mobile App

For submission/demo:

- Android APK
- GitHub repository
- Backend deployed URL or local backend demo

## Deployment Checklist

- Remove committed `.env` file from Git history or rotate credentials
- Add `.env.example`
- Configure production `DATABASE_URL`
- Train and save ML artifacts
- Connect Flutter API service to deployed backend URL
- Build release APK
- Test on physical Android device
