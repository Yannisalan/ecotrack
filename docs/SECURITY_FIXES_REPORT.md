# EcoTrack security fixes report

Branch: `security-fixes`
Baseline: `d9e4388` — *Baseline: terms consent, friendly error messages, theme redesign*
Date: 2026-10-21

Every fix below is one commit, applied on top of the baseline. The API shapes
are unchanged unless a fix explicitly says otherwise.

| Fix | Commit | Subject |
| --- | --- | --- |
| F-001 | `e79c66d` | harden secret handling and JWT secret validation |
| F-002 | `772f867` | remove CORS wildcard support, default to no cross-origin access |
| F-003 | `46fb595` | tighten JWT token locations and cookie flags |
| F-004 | `94c9b75` | add strict CSP and HTTPS-only HSTS to API responses |
| F-005 | `7b8d46c` | label the rate limit storage fallback and validate proxy hops |
| F-005b | `f87b51e` | apply each app's own default rate limit |
| F-006 | `36d7ad4` | make duplicate registration answers generic |
| F-007 | `ee27968` | never persist web tokens in localStorage |
| F-008 | `d35c1d6` | add end-to-end checks for the security fixes |

---

## F-001 — secret handling and JWT secret validation

**Problem.** `JWT_SECRET_KEY` was read straight from the environment with no
length or presence check, so a short or missing secret silently produced a
weakly signed token, and nothing told an operator that the value was
unusable.

**Change** (`backend/config.py`)

- `MIN_JWT_SECRET_LENGTH = 32`.
- `validate_jwt_secret()` rejects an empty value and any value shorter than 32
  characters, with a message that says how to generate a good one
  (`python -c "import secrets; print(secrets.token_hex(32))"`).
- `Config.JWT_SECRET_KEY` runs through it, so the app refuses to start with a
  weak secret instead of running insecurely.

**Change** (`backend/.env.example`) — the placeholder now documents the 32
character minimum, and `RATELIMIT_STORAGE_URI=memory://` is listed explicitly
instead of being implied.

**Change** (`scripts/scan_secrets.py`, new) — a redacted scanner for the
repository. It reports file, line and category only, never the value, so it
can be run and pasted safely.

**Before / after**

| | Before | After |
| --- | --- | --- |
| `JWT_SECRET_KEY=short` | starts, signs weak tokens | refuses to start, names the minimum |
| `JWT_SECRET_KEY` unset | starts with an empty secret | refuses to start |
| secret scan | manual | `python scripts/scan_secrets.py` |

**Evidence.** `backend/tests/test_security.py` covers the accepted and the
rejected secret lengths. The scanner was run over the whole repository: the
only hits were `.env` key *names* (values never read), `.env.example`
placeholders, `os.getenv(...)` call sites, and test-only credentials. No real
secret is present in any tracked file.

## F-002 — CORS wildcards removed

**Problem.** `CORS_ORIGINS` accepted `*`, and an unset value fell back to a
wildcard. Any website in the world could then call the API with the user's
cookies.

**Change** (`backend/config.py::_cors_origins`)

- Only exact origins are accepted, e.g. `https://app.example.com`.
- Any entry containing `*` is dropped with a `RuntimeWarning` that names the
  offending entry.
- An unset `CORS_ORIGINS` means **no** cross-origin request is allowed.

**Before / after**

| | Before | After |
| --- | --- | --- |
| `CORS_ORIGINS=*` | every origin allowed | dropped, warning, nothing allowed |
| `CORS_ORIGINS` unset | every origin allowed | nothing allowed |
| `CORS_ORIGINS=https://app.example.com` | allowed | allowed (unchanged) |

**Note.** `supports_credentials=True` is kept on purpose: the refresh token
travels in an HttpOnly cookie, and a credentialed cross-origin request is
rejected by the browser unless that flag is set. The allowlist, not the flag,
is what limits who may call the API.

**Tests updated.** The wildcard test now expects the wildcard to be refused
(the old expectation encoded the insecure behaviour), and a new test covers the
unset case. `backend/tests/conftest.py` sets `CORS_ORIGINS=""` so the suite is
hermetic and does not depend on the developer's local `.env`.

## F-003 — token locations and cookie flags

**Problem.** `JWT_TOKEN_LOCATION` was `["headers", "cookies"]`, so an access
token could be read from a cookie, and the cookie flags were left to the
framework default, which is not secure.

**Change**

- `backend/config.py`: `JWT_TOKEN_LOCATION = ["headers"]` — access tokens are
  only accepted from the `Authorization` header.
- `JWT_COOKIE_SAMESITE = "Lax"` (pinned, no longer framework default).
- `JWT_COOKIE_SECURE` defaults to true everywhere except debug/test, and an
  explicit environment value still wins.
- `backend/app/auth.py`: `_REFRESH_LOCATIONS = ["cookies", "json"]`. The
  refresh token is accepted from the HttpOnly cookie (web) or from the JSON
  body (mobile). It is **not** accepted from a header.

**Why the refresh token keeps a JSON location.** The Flutter client sends the
refresh token in the request body on mobile and relies on the cookie on the
web (`frontend/lib/services/api_service.dart`); the client never puts it in
an `Authorization` header. Removing the header location therefore removes a
path the client does not use.

**Before / after**

| | Before | After |
| --- | --- | --- |
| access token in a cookie | accepted | rejected |
| refresh token in a header | accepted | rejected |
| refresh token in the body / cookie | accepted | accepted (unchanged) |
| `SameSite` | framework default | `Lax` |
| `Secure` on cookie | framework default | on outside debug/test |

## F-004 — CSP and HSTS

**Problem.** API responses carried no `Content-Security-Policy`, and no HSTS
policy, so a browser had no instruction to keep the connection on HTTPS.

**Change** (`backend/app/__init__.py`)

- `Content-Security-Policy: default-src 'none'; frame-ancestors 'none';
  base-uri 'none'` on every response.
- `Strict-Transport-Security: max-age=31536000; includeSubDomains` **only**
  when the request already arrived over HTTPS (`request.is_secure`). Sending
  HSTS over plain HTTP would be ignored by the browser and would be
  misleading.
- `Referrer-Policy: no-referrer` was already the strictest value and is
  unchanged.

**Before / after**

| Header | Before | After |
| --- | --- | --- |
| `Content-Security-Policy` | absent | `default-src 'none'; frame-ancestors 'none'; base-uri 'none'` |
| `Strict-Transport-Security` | absent | present on HTTPS requests only |

**Documentation.** `docs/SECURITY_NOTES.md` explains what the CSP means for
the Flutter web build, including the `wasm-unsafe-eval` / CanvasKit caveat:
the API responses are API responses and never execute script, but the Flutter
web *index page* has its own CSP requirement, which is a front-end hosting
concern and is listed as a follow-up.

## F-005 — rate limit storage and proxy hops

**Problem.** Two configuration mistakes were silently accepted:

- `PROXY_FIX_HOPS` with a negative value, which makes `ProxyFix` trust
  headers it should not trust.
- A rate limit store of `memory://`, which is per-process. With more than one
  worker the effective limit is multiplied by the number of workers, and the
  operator had no way to know that from the logs.

**Change**

- `backend/config.py`: a negative `PROXY_FIX_HOPS` is refused at startup.
- `backend/app/__init__.py`: the effective storage URI is logged at startup,
  and the `memory://` fallback is labelled as per-process. A warning is
  logged when `WEB_CONCURRENCY > 1` because the limit is then multiplied.
- `docs/SECURITY_NOTES.md` documents the difference between `memory://` and
  `redis://`, and that `redis://` needs the `redis` package, which is not in
  `backend/requirements.txt` yet.

## F-005b — per-app default rate limit

**Problem.** Flask-Limiter is a module-level singleton, so the default limit
configured by the first app that called `init_app` was reused by every later
app in the same process. An app that configured a stricter limit silently got
the earlier, looser one.

**Change** (`backend/app/__init__.py`) — the stored default is cleared and
`init_app` re-reads it from the current app's configuration.

**Test.** `backend/tests/test_rate_limit_defaults.py` builds two apps with
different defaults and asserts that each one applies its own.

## F-006 — registration no longer reveals who has an account

**Problem.** A duplicate registration was answered with `409 Conflict` and a
message naming the conflict, and a different message from every other
rejected registration. That difference is enough to enumerate the accounts
that exist.

**Change**

- `backend/app/auth.py`: a duplicate registration is answered with `400` and
  the same generic `MSG_BAD_REQUEST` body as any other invalid registration.
  The rate limit on the registration route is unchanged, so the endpoint is
  not a free oracle.
- `backend/app/errors.py`: `MSG_CONFLICT` is now generic.
- `frontend/lib/services/error_messages.dart`: the client message for a
  conflict no longer names the reason.

**Before / after**

| | Before | After |
| --- | --- | --- |
| duplicate email | `409` + "email already registered" | `400` + the same generic body as any other invalid registration |
| invalid email | `400` + generic | unchanged |

**Test.** The backend test asserts that the duplicate response body is
byte-identical to the body of another rejected registration, and the Flutter
test asserts the client message does not leak the reason.

## F-007 — web tokens are never written to localStorage

**Problem.** The web client fell back to `shared_preferences` (which is
`localStorage` on the web) for the session when no first-party cookie was
available. Anything in `localStorage` is readable by every script that runs
on the page, so a single XSS payload would be enough to steal a 30 day refresh
token and keep using it after the tab was closed.

**Change**

- `frontend/lib/services/token_store.dart`: the `localStorage`-backed store
  is removed. The web client keeps tokens in memory only; mobile is
  unchanged and still uses `flutter_secure_storage` (OS keychain/keystore)
  for both tokens.
- `frontend/lib/services/api_service.dart`: the store is chosen by platform,
  not by cookie mode.
- `docs/SECURITY_NOTES.md` gains a "Token storage in the clients" section
  with the trade-off.

**Before / after**

| | Before | After |
| --- | --- | --- |
| web, same origin | access token in memory | unchanged |
| web, cross origin | refresh token in `localStorage` | refresh token in memory |
| mobile | `flutter_secure_storage` | unchanged |

**The trade-off, stated plainly.** The refresh cookie is first-party, so it is
only sent when the web app and the API share an origin. A cross-origin web
deployment (web on `app.example.com`, API on `api.example.com`) cannot use the
cookie flow, and the refresh token cannot be persisted anywhere safe. The
client therefore keeps it in memory only and the user signs in again after a
page reload. That is the deliberate trade: a shorter session, instead of a
refresh token stored where any script can read it. Serving the web app behind
the same origin as the API (the Vercel `/api/:path*` rewrite) avoids the
trade-off entirely and also means CORS is not needed.

`shared_preferences` stays in `pubspec.yaml`: it is still used for settings
and for the offline activity queue, which hold no tokens.

**Test.** `frontend/test/token_store_test.dart` asserts the store used on the
web writes nothing to `shared_preferences`, and that clearing leaves nothing
behind.

## F-008 — end-to-end checks

`backend/tests/test_security_fixes.py` (new, 6 tests) runs the verification
steps with production defaults — a 1 MB body cap and the real per-route rate
limits — instead of the relaxed settings the rest of the suite uses:

1. the security headers are present, and HSTS stays off over plain HTTP;
2. an unlisted `Origin` is not reflected, a listed one is allowed;
3. repeated login attempts are answered with `429`;
4. a user cannot read, list, patch or delete another user's activity, while
   the owner keeps full access;
5. a body over 1 MB is answered with `413`;
6. a malformed token is answered with `401`.

---

## Test results

| Suite | Result |
| --- | --- |
| `backend`: `python -m pytest` | **165 passed**, 1 warning |
| `frontend`: `flutter analyze` | **No issues found** |
| `frontend`: `flutter test` | **39 passed** |
| Local dummy-data run over real HTTP | **8/8 checks passed** |

The single backend warning is intentional: it is the `RuntimeWarning` raised
when a test feeds a wildcard CORS origin to confirm that it is refused.

### Local dummy-data verification

Run against a locally started server with a throwaway SQLite database and
dummy `dummy-*@example.com` accounts — no production data, no external
services, no real secrets.

| # | Check | Result |
| --- | --- | --- |
| 1 | security headers on a normal response | PASS — CSP `default-src 'none'; frame-ancestors 'none'; base-uri 'none'`, no HSTS over HTTP |
| 2a | unlisted origin gets no `Access-Control-Allow-Origin` | PASS |
| 2b | listed origin is allowed | PASS — `https://app.example` |
| 3 | repeated login attempts | PASS — `429` from the 11th attempt on |
| 4 | cross-user access | PASS — read/list/patch/delete all `404`, the other user sees `total: 0`, the owner still gets `200` |
| 5 | body over 1 MB | PASS — `413` |
| 6 | invalid token | PASS — `401`, body has only `error` |
| 7 | refresh token in an `Authorization` header | PASS — `401` |

---

## Environment variables

Names only; no values are recorded here.

| Variable | Used for | Notes |
| --- | --- | --- |
| `JWT_SECRET_KEY` | token signing | must be at least 32 characters, otherwise the app refuses to start |
| `CORS_ORIGINS` | allowed cross-origin callers | comma separated **exact** origins; `*` is refused; unset means none |
| `JWT_COOKIE_SECURE` | refresh cookie `Secure` flag | defaults to on outside debug/test; `render.yaml` already sets it to `true` |
| `PROXY_FIX_HOPS` | trusted proxy hops for `X-Forwarded-For` | `0` disables; a negative value is refused; `render.yaml` sets `1` |
| `RATELIMIT_STORAGE_URI` | rate limit store | `memory://` is per-process, `redis://` needs the `redis` package |
| `RATELIMIT_DEFAULT` | fallback limit for the whole API | `render.yaml` sets `600 per minute` |
| `RATELIMIT_ENABLED` | turns the limiter on | on in production |
| `MAX_CONTENT_LENGTH` | request body cap | 1 MB by default; a larger body is answered with `413` |
| `RESET_TOKEN_IN_RESPONSE` | returns the refresh token in the body | must stay `false` in production so the cookie flow is used |
| `DATABASE_URL` | database | unchanged |

**Action required before deploying.** The local `.env` still contains
wildcard CORS origins (`http://localhost:*`, `http://127.0.0.1:*`). They are
now dropped with a warning, which means the local dev server will reject
cross-origin browser calls until the value is replaced with the exact origins
in use, e.g. `http://localhost:5173,http://127.0.0.1:5173`.

---

## Remaining risks and follow-ups

1. **Shared rate limit store.** `memory://` is per-process. With more than one
   worker the effective limit is multiplied by the worker count, and the
   counters reset on every restart. Add the `redis` package and set
   `RATELIMIT_STORAGE_URI=redis://...` for a multi-worker deployment.
2. **Front-end hosting headers.** The CSP in F-004 is applied to the API
   responses. The Flutter web *index page* needs its own CSP
   (`script-src 'self' 'unsafe-eval'` for the CanvasKit build) and a
   `Referrer-Policy`; add it to `frontend/web/index.html` and to the
   `vercel.json` headers.
3. **No CSRF token on the cookie flow.** The refresh cookie is HttpOnly,
   first-party and `SameSite=Lax`, so a cross-site request cannot use it.
   `JWT_COOKIE_CSRF_PROTECT` is deliberately left off; turning it on would
   require the client to read a `csrf_refresh_token` cookie and send the
   matching header, which is a front-end change.
4. **Cross-origin web deployments lose the session on reload.** See the
   trade-off in F-007. Serving the web app from the same origin as the API
   removes the trade-off and the CORS configuration with it.
5. **`.env` in the working tree.** It is git-ignored and was never read, but
   it still holds the local wildcard CORS value mentioned above.
6. **Secret rotation.** `JWT_SECRET_KEY` is validated for length, not
   entropy. Rotate it periodically, and every rotation invalidates all issued
   tokens.

---

## Retest checklist

Run from the repository root.

**Backend**

```
cd backend
python -m pytest -q
```

Expect `165 passed, 1 warning` (the warning is the intentional wildcard
refusal). Newest checks:

```
python -m pytest tests/test_security_fixes.py -v
python -m pytest tests/test_security.py -v
python -m pytest tests/test_rate_limit_defaults.py -v
```

**Frontend**

```
cd frontend
flutter analyze
flutter test
```

Expect `No issues found` and `39 passed`.

**Secret scan**

```
python scripts/scan_secrets.py
```

Expect no finding with a real credential. The output is redacted on purpose:
file, line and category only, never a value.

**Local dummy-data run**

Start the backend with a throwaway database and dummy accounts, then check
over real HTTP:

1. `GET /api/health` — `Content-Security-Policy`,
   `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` present, and
   no `Strict-Transport-Security` over plain HTTP.
2. `GET /api/health` with `Origin: https://evil.example` — no
   `Access-Control-Allow-Origin`.
3. `GET /api/health` with a listed origin — the origin is reflected.
4. `POST /api/auth/login` with wrong credentials, 20 times — `429` appears.
5. Register two dummy users, create an activity as the first one, then read,
   list, patch and delete it as the second one — `404` each time, and the
   second user sees no activities.
6. `POST /api/activities` with a body over 1 MB — `413`.
7. `GET /api/auth/me` with a made-up token — `401`.
8. `POST /api/auth/refresh` with the access token in an `Authorization`
   header — `401`.

**After deploying**

1. Set `CORS_ORIGINS` to the exact origins in use, or leave it empty for a
   same-origin deployment.
2. Confirm `JWT_COOKIE_SECURE=true` and `PROXY_FIX_HOPS=1` in the
   environment.
3. Check the startup log for the rate limit storage line, and confirm it does
   not say `memory://` in a multi-worker deployment.
4. Confirm the refresh response sets an `HttpOnly`, `Secure`, `SameSite=Lax`
   cookie and that the body carries no refresh token.
5. Repeat checks 1, 2, 4 and 6 against the deployed origin.
