# SCENORA Backend — Phase 1 to 8

## ব্যবহৃত Technology

- Language: Dart 3
- HTTP framework: Shelf + Shelf Router
- Development database: persistent JSON file
- Authentication: opaque access token + refresh token
- Password protection: PBKDF2-HMAC-SHA256 with random salt
- Token protection: database-এ raw token নয়, SHA-256 hash রাখা হয়
- Movie provider: optional TMDB REST API proxy
- Tests: Dart Test + real local HTTP server

এই stack নির্বাচন করা হয়েছে কারণ development PC-তে Dart/Flutter আগে থেকেই আছে। তাই
Node.js, Firebase account বা cloud credentials ছাড়াই backend run এবং demonstrate করা যায়।
Production deployment-এর আগে JSON database PostgreSQL/Firestore দিয়ে replace করতে হবে।

## 1. Backend Foundation

- আলাদা `server/` Dart package
- REST API server `0.0.0.0:8080`
- JSON request/response
- CORS support
- HTTP request logging
- `/health` monitoring endpoint
- File-based persistent development database
- Atomic database save (`.tmp` file → final database file)
- Environment variables: `PORT`, `TMDB_API_KEY`, `SCENORA_TOKEN_PEPPER`

## 2. Authentication

### Routes

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`

### Security

- Email format validation
- Username format and uniqueness validation
- Minimum 8-character password
- Password salted PBKDF2 hash হিসেবে save হয়
- 15-minute access token
- 30-day refresh token
- Refresh করলে পুরোনো session rotate হয়
- Database-এ token-এর hash রাখা হয়
- Invalid/expired token protected route ব্যবহার করতে পারে না
- Inactive account login করতে পারে না

## 3. User Profiles

### Routes

- `GET /users/me`
- `PATCH /users/me`
- `GET /users/<id>`

### Profile fields

- Username
- Display name
- Bio
- Location
- Avatar URL
- Cover URL
- Account status
- Created/updated time
- Review/follower/following counts

API response থেকে password hash এবং password salt বাদ দেওয়া হয়। User শুধু নিজের profile
update করতে পারে।

## 4. TMDB/Movie Integration

### Routes

- `GET /movies/search?q=Dune`
- `GET /movies/popular`
- `GET /movies/<tmdb-id>`

`TMDB_API_KEY` থাকলে backend সরাসরি TMDB call করে এবং key Flutter app থেকে গোপন রাখে।
Key না থাকলে built-in cached demo movie data return করে, ফলে classroom demo internet ছাড়াও চলে।

## 5. Reviews

### Routes

- `GET /reviews`
- `POST /reviews`
- `GET /reviews/<id>`
- `PATCH /reviews/<id>`
- `DELETE /reviews/<id>`

### Rules

- Create/update/delete-এর জন্য login প্রয়োজন
- শুধু owner review edit/delete করতে পারে
- Rating 1–5 হতে হবে
- Review text 1–2000 characters
- Spoiler flag এবং image URL list support
- Movie ও reviewer information response-এর সঙ্গে আসে
- Like/comment count calculated হয়
- Movie detail-এ SCENORA average rating calculated হয়
- Delete করলে সংশ্লিষ্ট likes/comments-ও delete হয়

## 6. Likes

### Route

- `POST /reviews/<id>/like`

একই endpoint like এবং unlike toggle করে। Login ছাড়া request `401` পায়। একই user-এর
duplicate like তৈরি হয় না এবং updated like count return হয়।

## 7. Comments

### Routes

- `GET /reviews/<id>/comments`
- `POST /reviews/<id>/comments`
- `PATCH /comments/<id>`
- `DELETE /comments/<id>`

### Rules

- Comments পড়া public
- Create/update/delete-এর জন্য login প্রয়োজন
- শুধু comment owner edit/delete করতে পারে
- Maximum 1000 characters
- `parentCommentId` দিয়ে reply/thread support প্রস্তুত
- Comment response-এ public user information থাকে

## 8. Follow System

### Routes

- `POST /users/<id>/follow`
- `GET /users/<id>/followers`
- `GET /users/<id>/following`

Follow endpoint follow/unfollow toggle করে। User নিজেকে follow করতে পারে না এবং duplicate
relationship হয় না। Profile response-এ follower/following count ও `isFollowing` status থাকে।

## Run এবং Demo

```powershell
cd D:\Flutter\Scenora\server
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe pub get
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe run bin\server.dart
```

অন্য Terminal-এ health check:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

Automated tests:

```powershell
cd D:\Flutter\Scenora\server
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe test -r expanded
```

## এখনো Production Backend নয়

বর্তমান backend local MVP/demo-এর জন্য। Production-এর আগে PostgreSQL/Firestore, HTTPS,
cloud deployment, email verification, Google OAuth credentials, media storage, rate limiting,
notifications, moderation, backups এবং monitoring যোগ করতে হবে। Flutter frontend-এর current
login page demo mode-এ আছে; deployed API URL পাওয়ার পরে সেটি এই authentication API-এর সঙ্গে
connect করতে হবে।
