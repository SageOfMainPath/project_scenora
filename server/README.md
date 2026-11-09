# SCENORA Backend

Self-contained Dart REST API covering authentication, profiles, movie discovery,
reviews, likes, comments, and follows.

## Run

For the first run, copy `.env.example` to `.env` and put your TMDB credentials
there. The `.env` file is ignored by Git and is loaded automatically, so the
keys do not need to be entered again for every run.

```powershell
Copy-Item .env.example .env
notepad .env
```

To use the migrated Supabase database, open the Supabase Dashboard and choose
**Connect > Session pooler**. Copy its PostgreSQL URI into `.env` as
`SUPABASE_DATABASE_URL`. Keep `sslmode=require`. Never put this URI or its
password in Flutter code. When this variable is present, the backend uses the
private `scenora` PostgreSQL schema. Without it, local JSON remains available
as a development fallback.

```powershell
cd server
dart pub get
dart run bin/server.dart
```

The API starts at `http://0.0.0.0:8080`. Check it with:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

Data persists to Supabase when `SUPABASE_DATABASE_URL` is configured; otherwise
it persists to `server/data/db.json`. Set `TMDB_API_KEY` and/or
`TMDB_READ_ACCESS_TOKEN` in `.env` to enable live TMDB search/detail results;
without either credential, seeded demo movies are returned. Process environment
variables take precedence over `.env` values.

## Authentication

Send the access token returned by register/login as:

```text
Authorization: Bearer <accessToken>
```

## Main routes

- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`
- `GET/PATCH /users/me`, `GET /users/<id>`
- `POST /users/<id>/follow`, `GET /users/<id>/followers`, `GET /users/<id>/following`
- `GET /movies/search?q=...`, `GET /movies/popular`, `GET /movies/<id>`
- `GET/POST /reviews`, `GET/PATCH/DELETE /reviews/<id>`
- `POST /reviews/<id>/like`
- `GET/POST /reviews/<id>/comments`, `PATCH/DELETE /comments/<id>`
- `GET /watchlist`, `POST /watchlist/<movieId>`
- `GET/POST /messages`
- `GET /activity`

## Cloud deployment

The repository includes a production Dockerfile and a Render Blueprint. Render
provides `PORT`; add `SUPABASE_DATABASE_URL`, the TMDB credentials, and
`SCENORA_TOKEN_PEPPER` as secret environment variables in its dashboard. See
`docs/DEPLOYMENT_GUIDE.md` for the complete process. Supabase PostgreSQL is the
hosted persistent store; local JSON is retained only as a development fallback.
