# EcoTrack

EcoTrack is a sustainability-tracking app (SDG 6/7/12/13) built as a BCA project. It helps users log transport, electricity, water and waste activities and see their CO2 footprint, an Eco Score and personalised recommendations.

## Architecture
- Backend: Flask (3.x) API with Flask-SQLAlchemy, Flask-JWT-Extended, Flask-Cors, PostgreSQL (Neon) via psycopg 3.
- Frontend: Flutter app (Provider) targeting web/Chrome first; Android/iOS projects included.
- Data model: users, activities (per-user, owner-scoped), eco_scores. CO2 calculated server-side from emission factors.
- State: Provider with ApiService as single HTTP client.

Text diagram:
`
[Flutter App (web/mobile)] --(HTTP JSON, Bearer JWT)--> [Flask API] --SQL--> [PostgreSQL (Neon)]
`

## Tech Stack
- Python 3.12, Flask 3.0.3, SQLAlchemy 2.1.3, Flask-JWT-Extended 4.6.0, Flask-Cors 4.0.1, psycopg[binary], gunicorn (prod)
- Flutter 3.x/Dart, provider, http, shared_preferences
- pytest (backend tests)

## Local Setup (Windows PowerShell)

### Backend
`powershell
cd C:\Users\odjoy\Desktop\ecotrack\backend
python -m venv ..\venv  # first time only
..\venv\Scripts\Activate.ps1  # if you use the venv
pip install -r requirements.txt
# Copy .env if needed and edit DATABASE_URL/JWT_SECRET_KEY/CORS_ORIGINS/FLASK_DEBUG/PORT
python run.py  # runs on http://127.0.0.1:5000
`

### Frontend
`powershell
cd C:\Users\odjoy\Desktop\ecotrack\frontend
flutter pub get
flutter run -d chrome  # or start Chrome and pick it
`

## Environment Variables
Copy `backend/.env.example` to the **project root** as `.env` (the backend loads
it from there). `JWT_SECRET_KEY` is required — the app refuses to start without it.

| Variable | Used by | Purpose |
|---|---|---|
| DATABASE_URL | backend | PostgreSQL connection string (Neon). |
| JWT_SECRET_KEY | backend | **Required** secret for access + refresh tokens. No default. |
| JWT_COOKIE_SECURE | backend | "true" in production (HTTPS) so the refresh cookie is Secure. |
| CORS_ORIGINS | backend | Comma-separated allowed origins; `*` is a wildcard (e.g. `http://localhost:*`). Defaults to localhost on any port. |
| FLASK_DEBUG | backend | 0 in prod, 1 for dev. |
| PORT | backend | Port for gunicorn (Render sets automatically). |
| RATELIMIT_ENABLED | backend | Per-IP/per-user rate limits on auth + other routes (default true). |
| RATELIMIT_DEFAULT | backend | Default limit for routes without their own (default 600/min). |
| PROXY_FIX_HOPS | backend | Trusted reverse proxies (1 on Render, 0 locally). |
| MAX_CONTENT_LENGTH | backend | Max request body bytes (default 1 MB; oversize → 413). |
| RESET_TOKEN_IN_RESPONSE | backend | Echo reset tokens in the forgot-password response. Default false; enable only for a demo. |
| ENABLE_SCHEDULER | backend | Master switch for the in-process scheduler (default false). Enable only on a single worker (`gunicorn run:app --workers 1`). |
| REMINDER_SCHEDULER | backend | Hourly job that materializes reminders for every user (default false; requires ENABLE_SCHEDULER=true). |
| API_BASE_URL | frontend (build) | Backend URL, passed via --dart-define=API_BASE_URL=.... |

## Auth & security
- Access tokens last 15 minutes; refresh tokens last 30 days and rotate on use.
- Rate limiting: register 10/min, login 20/min, forgot-password 5/min, reset/change-password 10/min, a 600/min default everywhere else (per user when authenticated, else per IP).
- Password policy: at least 8 characters, 4+ distinct characters, and not on a common-password denylist.
- Password reset: `POST /api/auth/forgot-password` then `POST /api/auth/reset-password`. There is no SMTP integration, so the token is only returned in the response when `RESET_TOKEN_IN_RESPONSE=true` (demo only). `POST /api/auth/change-password` changes an authenticated user's password.
- A password reset/change bumps `users.token_version`, invalidating **all** outstanding access and refresh tokens.
- Requests are capped at `MAX_CONTENT_LENGTH` (1 MB) and responses carry `X-Content-Type-Options`, `X-Frame-Options`, and `Referrer-Policy` headers.
- Expired blocklist entries and used/expired reset tokens are purged daily and at startup.

> **Rotate leaked secrets.** If a real `JWT_SECRET_KEY` or database password was ever committed or shared, generate a new `JWT_SECRET_KEY` and change the Neon password. Removing the file does not invalidate the leaked values.

## Feature endpoints
Reminders are in-app: reminder-style notifications (daily reminder at the user-chosen hour, streak at risk, log today) are generated server-side on register/login, after activity/goal changes, and by an optional hourly job. `GET /api/notifications` is read-only (it never creates or deletes rows). When `ENABLE_SCHEDULER=true` (single worker) the scheduler also purges expired tokens and, if `REMINDER_SCHEDULER=true`, materializes reminders for every user. There is no email or push (no push credentials configured).
- GET /api/insights?period=week|month - unified insights (summary, trend, weekday pattern, highlights, tips).
- GET /api/challenges (completed_total + history), GET /api/challenges/history, GET /api/challenges/points.
- GET/POST /api/notifications, /read-all, /<id>/read, DELETE /<id>, GET/PUT /api/notifications/preferences (persisted, deduped, per user).
- POST /api/auth/forgot-password, POST /api/auth/reset-password, POST /api/auth/change-password.

## Tests
Backend: from backend/, run python -m pytest -q. Tests force in-memory SQLite and never touch the real DB. Expected: 131 passed (includes password reset, rate limiting, CORS, body-size, token-purge and reminder tests).

Frontend: from frontend/, run flutter analyze and flutter test (27 passed).
