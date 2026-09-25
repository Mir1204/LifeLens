# Production security configuration

LifeLens uses FastAPI and its own JWT authentication. Do not add Firebase Auth
unless the app is deliberately migrated to Firebase as the sole identity
provider; operating two identity systems would weaken account controls.

## Required Render settings

- `DATABASE_URL`: a managed PostgreSQL connection URL with `sslmode=require`.
  The database must have encryption at rest enabled by its provider.
- `JWT_SECRET_KEY`: a unique, CSPRNG-generated secret, stored only in Render.
- `JWT_SECRET_KEYS` and `JWT_ACTIVE_KEY_ID`: use these for planned signing-key
  rotation. Retain the old key only until all access and refresh tokens signed
  by it have expired, then remove it.
- `ALLOWED_ORIGINS`: exact production web origins only; leave empty for the
  native-only app rather than using `*`.
- `GOOGLE_WEB_CLIENT_ID`: set only if Google sign-in is enabled.

## Access controls

The mobile client connects to the Render HTTPS URL. Do not expose the Postgres
port publicly and do not put database credentials in Flutter, Git, or logs.
Only the FastAPI service should own database credentials. Refresh sessions are
stored server-side, rotated at every refresh, and revoked at logout; each access
token is bound to that server-side session, so a revoked session is rejected
immediately.

## Data protections

- Device database: SQLCipher encryption.
- Device encryption key and tokens: Android Keystore / iOS Keychain through
  secure storage.
- Passwords: Argon2id hashes only.
- Exports: passphrase-derived AES-256-GCM encryption.
- Transport: HTTPS/TLS enforced by the production endpoint.

Test the deployed service after every key rotation: login, refresh, logout, and
a protected prediction request must all behave as expected.
