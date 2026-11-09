# SCENORA backend status

## Completed local MVP features

- Registration, login, refresh-token sessions, logout, and secure password hashes
- Persistent encrypted login tokens on the Flutter device
- Editable and persistent backend URL with a health check
- User profiles and profile editing
- TMDB search, popular movies, details, caching, and posters
- Reviews, likes, comments, follows, and activity feed
- Per-user persistent watchlists
- Multi-device Shoutbox messages with polling refresh
- JSON persistence, automatic schema migration, validation, and API tests

## External production integrations still required

- PostgreSQL or a managed cloud database instead of the local JSON file
- Public HTTPS hosting and a stable domain
- Firebase Cloud Messaging or another push notification provider
- Email provider for verification and password reset mail
- Object storage for uploaded avatars and review images
- Admin/moderation dashboard, monitoring, backups, and production rate limits

The local classroom build intentionally uses the PC backend. Its address can be
changed from Profile > Settings > Backend server without rebuilding the APK.

For a classroom demo without local-IP issues, run this from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\start_demo_tunnel.ps1
```

Copy the generated `https://...trycloudflare.com` URL into the app's Backend
server setting and keep the PowerShell window open for the duration of the demo.
