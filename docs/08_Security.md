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

The current project is an MVP prototype. It does not yet include:

- Authentication
- User authorization
- Encrypted local database
- Fine-grained privacy controls
- Production secret management

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

### No Authentication

The backend currently accepts `user_id` directly from the request body. For production, this should come from authenticated user identity.

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
