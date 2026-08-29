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

The app now uses encrypted local storage, Android Keystore-backed secret
storage, authenticated backend APIs, opt-in backend sync, HTTPS-only endpoint
configuration, restrictive CORS, payload validation, private notifications,
and permanent account/data deletion. Deployment must set `DATABASE_URL` and
`JWT_SECRET_KEY` through its secret manager before the backend can start.

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

Backend prediction sync is disabled by default and the sync implementation
enforces the setting before any network call. If consent is off, the app keeps
calculating scores locally and does not transmit daily lifestyle summaries.

### Developer Access Controls For Production

For production, database access should be restricted so developers cannot browse
user data casually:

- Use role-based database accounts with least privilege.
- Give developers read access only to anonymized/debug datasets.
- Require admin approval for production database access.
- Keep audit logs for every production database access.
- Prefer aggregate dashboards over raw row exports.

## Current Risks

### Historic Secret Exposure

`backend/.env` was committed in older history. It is ignored now, but any
credential that was ever committed must be rotated and removed from Git history
before a public release.

### Deployment Configuration

Set `ALLOWED_ORIGINS` to a comma-separated list of trusted web origins. Native
mobile requests use bearer authentication; the API does not permit arbitrary
browser origins.

### Authentication

The backend derives the user identity from a short-lived signed bearer token,
not from a request-supplied user ID. Passwords are stored only as Argon2id
hashes on the backend; the mobile device stores an access token in Android
Keystore-backed encrypted storage and never stores the password.

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
