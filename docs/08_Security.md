# Security

## Sensitive Data

LifeLens may handle sensitive personal data:

- Sleep habits
- Screen-time patterns
- Spending behavior
- Calendar workload
- Stress/burnout risk

Even in a student project, this data should be treated carefully.

## Current Security Status

The current project is an MVP prototype. It includes local demo login, but it does not yet include:

- Production authentication
- User authorization
- Encrypted local database
- Fine-grained privacy controls
- Production secret management

## Privacy-By-Design Controls Added For MVP

LifeLens uses data minimization so developers and backend/database operators do
not receive raw sensitive user data during normal prediction sync.

### Raw Data Stays On Device

The Flutter app stores detailed user records in local SQLite:

- Expense category and notes
- Planner task titles
- Health records
- Most-used app names and package names
- User name and email for local demo login

These raw details are not sent to the backend prediction endpoint.

### Backend Receives Summaries Only

The backend prediction API receives only daily aggregate values required for the
model/rule calculation:

- Sleep hours
- Step count
- Total screen-time hours
- Total daily spending
- Number of calendar/tasks
- High-priority task count
- Total workload
- Optional monthly budget

The backend does not receive expense notes, task titles, app names, package
names, user name, or user email.

### Pseudonymous Backend Identity

The mobile app sends a separate backend ID in the form `anon_<hash>` instead of
the local demo user ID, email, or name. This reduces the ability of a backend
developer to directly identify a person from prediction rows.

### Explicit Sync Consent

Backend prediction sync is disabled until the user enables the privacy consent
toggle in Profile. If consent is off, the app continues using local scores and
does not transmit daily lifestyle summaries to the backend.

### Developer Access Controls For Production

For production, database access should be restricted so developers cannot browse
user data casually:

- Use role-based database accounts with least privilege.
- Give developers read access only to anonymized/debug datasets.
- Require admin approval for production database access.
- Keep audit logs for every production database access.
- Prefer aggregate dashboards over raw row exports.

## Current Risks

### `.env` File Committed

The backend update includes a committed `backend/.env` file.

This should be avoided because `.env` files may contain database credentials or secrets.

Recommended action:

- Add `backend/.env` to `.gitignore`
- Keep only `backend/.env.example` in Git
- Rotate any real credentials if they were committed

### Open CORS

Current backend CORS allows all origins:

```python
allow_origins=["*"]
```

This is acceptable for local development but should be restricted for deployment.

### Local Demo Authentication

The backend currently accepts `user_id` directly from the request body. The Flutter app generates a stable local ID from the signup email. For production, this should come from authenticated user identity.

## Recommended Security Improvements

### Environment Variables

Store secrets in environment variables:

- `DATABASE_URL`
- Model storage paths if needed
- API keys if added later

Do not commit real `.env` files.

### Authentication

For future versions:

- Firebase Auth
- Supabase Auth
- JWT-based FastAPI auth

### Data Privacy

Recommended:

- Store only required daily summaries
- Avoid collecting raw app usage unless necessary
- Give user clear control over what is tracked
- Delete data on request

### Android Permissions

Future Health Connect and UsageStatsManager integrations require clear user permission handling.

The app should explain why permissions are needed:

- Health Connect: sleep and steps
- Usage access: screen-time calculation

### API Hardening

Before deployment:

- Restrict CORS
- Validate payload ranges
- Add rate limits if public
- Use HTTPS
- Add proper error handling
- Avoid exposing stack traces

## Security Position For Presentation

LifeLens currently demonstrates a prototype architecture. Production security improvements are identified and planned, especially authentication, environment secret handling, and privacy-safe data collection.
