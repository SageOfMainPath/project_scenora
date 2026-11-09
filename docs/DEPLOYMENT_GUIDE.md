# SCENORA Deployment Guide

This project keeps the Flutter app, Dart API, Supabase migrations, and project
documents in one repository. Secrets are deliberately excluded from Git.

## 1. Supabase

The API uses Supabase PostgreSQL when `SUPABASE_DATABASE_URL` is present. Apply
the SQL files in `server/migrations` in numeric order. Use the Session/Shared
Pooler URI and keep `sslmode=require`. If the database password contains `@`,
`#`, `%`, `/`, or another reserved URL character, percent-encode it.

Never add the real URI to Flutter code, a Markdown file, or GitHub.

## 2. Deploy the API on Render

1. In Render, choose **New > Blueprint** and connect this GitHub repository.
2. Select the repository's `render.yaml`.
3. Enter these secret environment variables when Render prompts:
   - `SUPABASE_DATABASE_URL`
   - `TMDB_API_KEY`
   - `TMDB_READ_ACCESS_TOKEN`
   - `SCENORA_TOKEN_PEPPER` (a new, long random value)
4. Deploy and wait for the health check to pass.
5. Open `https://YOUR-SERVICE.onrender.com/health` and confirm it returns a
   healthy response.

Render supplies `PORT` automatically. The Docker image compiles the Dart server
to a native executable and listens on `0.0.0.0`.

## 3. Connect the Android app

For an already installed app, open **Profile > Settings > Backend server**, paste
the Render HTTPS URL, then select **Test & save**.

For a release APK with the hosted URL built in:

```powershell
flutter build apk --release --dart-define=SCENORA_API_URL=https://YOUR-SERVICE.onrender.com
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## 4. GitHub Actions

- `CI` analyzes and tests both Flutter and the Dart backend on each push.
- `Android release APK` builds an APK manually or on a `v*` tag.
- Add a repository variable named `SCENORA_API_URL` containing the Render URL
  before running the APK workflow.
- A tagged build (for example `v1.0.0`) creates a GitHub Release and attaches
  the APK. APK binaries are not committed to the source tree.

## 5. Free-tier presentation note

A free Render service may sleep when idle. Open its `/health` URL a few minutes
before presenting, then test login and movie search from the phone.
