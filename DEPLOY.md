# Deployment Notes

This project is designed to run as a Flask API and Flutter client.

## Local development
- Backend: copy `backend/.env.example` to the project root as `.env`, then run
  `python run.py` from the backend directory
- Frontend: run `flutter run -d chrome`

## Production
- Use environment variables for secret configuration.
- `JWT_SECRET_KEY` is required (no default); generate with
  `python -c "import secrets; print(secrets.token_hex(32))"`.
- **Rotate any secret that was ever committed or shared.** Replacing the file is
  not enough: mint a new `JWT_SECRET_KEY` and change the Neon database password,
  then update `.env` / the Render env vars.
- Set `CORS_ORIGINS` to the exact frontend origin (or use a same-origin rewrite,
  in which case CORS is not exercised). A bare `*` is refused outside debug.
- Set `PROXY_FIX_HOPS=1` on Render so rate limiting keys on the real client IP
  (leave `0` when running without a reverse proxy).
- Rate limiting is on by default (`RATELIMIT_ENABLED=true`) with a
  `RATELIMIT_DEFAULT` of 600/min plus stricter per-route auth limits, using
  in-process memory storage (correct for a single Render worker).
- Request bodies are capped at `MAX_CONTENT_LENGTH` (1 MB).
- Password reset has no SMTP integration: leave `RESET_TOKEN_IN_RESPONSE=false`
  (the default) so no working token is ever returned, or wire email delivery.

## Background jobs
The in-process scheduler is **off by default** (`ENABLE_SCHEDULER=false`). When
enabled it runs a daily purge of expired blocklist/reset-token rows and, if
`REMINDER_SCHEDULER=true`, an hourly reminder materialization for every user.

Because `create_app()` runs once per gunicorn worker, enabling the scheduler on
a multi-worker deployment would start one scheduler per worker and run each job
N times. It is therefore safe to enable only on a single worker:

```
gunicorn run:app --bind 0.0.0.0:$PORT --workers 1 --threads 4
```

`render.yaml` already pins `--workers 1` and sets `ENABLE_SCHEDULER=true`. If you
scale to multiple workers, set `ENABLE_SCHEDULER=false` and move the jobs to an
external cron (e.g. a Render cron job / scheduled task hitting an admin route).

Notifications are also generated on register/login and after activity or goal
changes, so reminders still appear without the scheduler; `GET /api/notifications`
itself is read-only.

## Authentication & persistent login

Access tokens are short-lived (15 min); refresh tokens last 30 days and are
**rotated on every use** (the old one is revoked via the `token_blocklist`
table). The client transparently refreshes on a 401 and retries once.

Refresh-token transport is platform- and topology-aware:

| Client | Refresh token storage | Transport |
|---|---|---|
| Native (Android/iOS/desktop) | OS keychain/keystore (`flutter_secure_storage`) | `refresh_token` in the JSON body |
| Web — same-origin | HttpOnly cookie (never touched by JS) | browser cookie |
| Web — cross-origin (e.g. local dev) | `localStorage` (`shared_preferences`) | `refresh_token` in the JSON body |

The web client picks the mode automatically by comparing the page origin with
`API_BASE_URL`. **Same-origin is the secure mode**; cross-origin web is the
documented fallback and is XSS-exposed, so prefer same-origin in production.

### Deploying web with same-origin cookies
Serve the API under the frontend's origin with a Vercel rewrite so the refresh
cookie is first-party. In `frontend/web/vercel.json`:

```json
{
  "rewrites": [
    { "source": "/api/:path*", "destination": "https://<your-render-service>.onrender.com/api/:path*" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

And set `JWT_COOKIE_SECURE=true` on the backend (already in `render.yaml`) so the
cookie is only sent over HTTPS. Release web builds call the API on the page's own
origin automatically; no `API_BASE_URL` is needed.

### Local development
The backend and Flutter web run on different ports, so cookies are not
first-party and the app uses the `localStorage` fallback. `CORS_ORIGINS` defaults
to localhost on any port, so this works with no extra configuration.

