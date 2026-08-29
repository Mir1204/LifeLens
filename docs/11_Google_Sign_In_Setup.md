# Google Sign-In Setup

LifeLens uses Google Sign-In only to confirm identity. The app sends the Google
ID token to the LifeLens backend, which validates it and issues its own
short-lived LifeLens token. Google passwords are never handled or stored by
LifeLens.

## One-time Google Cloud configuration

1. In Google Cloud Console, create or select the project for LifeLens.
2. Configure the OAuth consent screen and add the test users while the app is
   in testing.
3. Enable the **Google Calendar API** under **APIs & Services → Library**.
4. Create an **Android OAuth client** with package name
   `com.example.lifelens_mobile` and the SHA-1 fingerprint for the signing key
   used on the phone.
5. Create a **Web OAuth client**. Copy its client ID; it ends in
   `.apps.googleusercontent.com`.
6. In Render, set `GOOGLE_WEB_CLIENT_ID` to that Web client ID, then redeploy
   the backend.
7. Run Flutter with the same ID:

## Google Calendar task events

The Tasks screen asks for Calendar permission only when a user enables **Add to
Google Calendar** for a task. In the same Google Cloud project, configure the
OAuth consent screen and add the
`https://www.googleapis.com/auth/calendar.events` scope, save the consent
screen, and add the account as a test user while the app is in Testing. This
gives LifeLens permission to create events in the user's primary calendar; it
does not read existing events. The app creates a one-hour event at the time
selected in LifeLens.

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Never put a client secret in the mobile app. Android and Web OAuth client IDs
are public identifiers; client secrets belong only on trusted servers.

## Release builds

Add the SHA-1 for the release signing certificate as another Android OAuth
client (or add it to the existing one) before building the release APK. Debug
and release certificates normally have different fingerprints.
