# SCENORA

SCENORA is a Flutter social movie-review Android app. Users can discover movies
through TMDB, create accounts, publish and rate reviews, like and comment,
follow other reviewers, maintain a watchlist, and join the community Shoutbox.

## Architecture

```text
Flutter Android app
        |
        | HTTPS / JSON REST API
        v
Dart Shelf backend (Render/Docker)
        |                         |
        v                         v
Supabase PostgreSQL             TMDB API
users, reviews, social data     movie metadata/posters
```

The database credential and TMDB credentials stay in the backend environment;
they are never embedded in the Android application.

## Features

- Email registration, login, refresh tokens, logout, and guest browsing
- User profiles with review, follower, and following counts
- TMDB movie search, posters, details, ratings, storyline, and trailers
- Create, edit, and delete reviews with 1–5 star movie ratings
- Community ratings on reviews, sorted from highest to lowest
- Review likes, threaded comments, watchlist, and activity notifications
- Follow/unfollow users and a dedicated Following feed
- Live-style Shoutbox community messages
- Configurable backend URL for local demos or hosted deployment

## Technology

- Flutter and Dart for the Android client
- Dart Shelf REST API for the backend
- Supabase PostgreSQL for persistent relational data
- TMDB API for movie information
- Docker and Render Blueprint for cloud deployment
- GitHub Actions for tests and release APK builds

## Run locally

Create `server/.env` from the safe example and enter your own credentials:

```powershell
Copy-Item server/.env.example server/.env
cd server
dart pub get
dart run bin/server.dart
```

In another terminal:

```powershell
flutter pub get
flutter run
```

For a phone on the same network, set the backend URL from **Profile > Settings
> Backend server**. Hosted deployment instructions are in
[docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md).

## Quality checks

```powershell
flutter analyze
flutter test
cd server
dart analyze
dart test
```

## Documentation

- [Privacy policy](PRIVACY_POLICY.md)
- [Final project report (PDF)](docs/group_1.pdf)
- [Final project report (HTML)](docs/SCENORA_Final_Project_Report.html)
- [Backend implementation: tasks 1–8](docs/BACKEND_1_TO_8.md)
- [Backend status](docs/BACKEND_STATUS.md)
- [Deployment guide](docs/DEPLOYMENT_GUIDE.md)
- [Supabase migrations](server/migrations)

## Academic information

**Institution:** Bangladesh University of Professionals

**Course teachers:** Iyolita Islam and Sharad Hasan

| Student ID | Team member |
|---|---|
| 23524202047 | Mainul |
| 23524202051 | Rony |
| 23524202095 | Emon |
| 23524202129 | Shifat |

## Security

`server/.env`, local database data, generated builds, and IDE caches are ignored
by Git. Copy only `server/.env.example`; never commit real database passwords,
TMDB tokens, access tokens, or signing keys.
