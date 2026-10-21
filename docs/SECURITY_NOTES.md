# Security notes

Deployment-facing notes for EcoTrack. The API's own headers are set in
`backend/app/__init__.py`; this file covers what the **hosting layer** must do.

## 1. Content-Security-Policy for the Flutter web app

The API sets a strict CSP on its own JSON responses:

```
default-src 'none'; frame-ancestors 'none'; base-uri 'none'
```

That is safe because the API never returns a document. It does **not** protect
the Flutter web app itself, which is served as a real HTML document by the
hosting layer (Vercel, in `frontend/web/vercel.json`). The app's CSP must be
set there.

### Recommended policy
### Recommended policy (rollout: Report-Only first)

Build the web app with `flutter build web --no-web-resources-cdn` so CanvasKit
is served from your own origin. Flutter may still fetch fallback fonts from
`fonts.gstatic.com`; the policy below allows that, so check the browser console
in Report-Only mode and remove it if nothing is blocked without it.

```
default-src 'self';
script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval';
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob:;
font-src 'self' data: https://fonts.gstatic.com;
connect-src 'self' https://fonts.gstatic.com;
worker-src 'self' blob:;
manifest-src 'self';
frame-ancestors 'none';
base-uri 'self';
object-src 'none'
```

`'unsafe-eval'` is left out on purpose. If the release build fails to load,
add it back, and note that in this file.

Rollout steps:
1. Deploy with the header key `Content-Security-Policy-Report-Only`.
2. Load every screen and check the browser console for violations.
3. Fix or allow only what is genuinely needed.
4. Switch the key to `Content-Security-Policy`.

### Why `'wasm-unsafe-eval'` is required

Flutter Web renders with **CanvasKit**, which is a WebAssembly module. The
browser refuses to compile the WebAssembly module unless the CSP explicitly
allows it, and `'wasm-unsafe-eval'` is the only CSP source token that permits
WASM compilation. Without it the app shows a blank page.

`'unsafe-inline'` and `'unsafe-eval'` are also needed by the Flutter bootstrap
in debug builds. They weaken the policy, so:

- Use the policy above as a **baseline**, then tighten it.
- Test the deployed build in a browser console before enforcing a stricter
  variant, and roll it out behind `Content-Security-Policy-Report-Only` first.
- A stricter long-term target is to move Flutter to a build without
  `'unsafe-eval'` and to serve the bootstrap script from a hash-based
  allowlist.

### Vercel example (`frontend/web/vercel.json`)

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Content-Security-Policy", "value": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; object-src 'none'" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains" }
      ]
    }
  ]
}
```

`Referrer-Policy` for the web app can be `strict-origin-when-cross-origin`:
the app is a document, so it is useful to keep the origin in the referrer.
The API itself stays on `no-referrer` because it has no reason to leak its
paths at all.

## 2. HSTS

The API sets `Strict-Transport-Security` **only** when the request already
arrived over HTTPS (`request.is_secure`). A `Strict-Transport-Security` header
on a plain-http response is ignored by browsers, and it can lock a developer
out of a local `http://localhost` deployment. The hosting layer (Vercel)
should set HSTS unconditionally, because it terminates TLS.

## 3. ProxyFix and the trusted-proxy count

Rate limiting keys on the client IP, so the app must know how many reverse
proxies sit in front of it. `PROXY_FIX_HOPS` is that number.

| Deployment | `PROXY_FIX_HOPS` |
| --- | --- |
| Local `python run.py` | `0` |
| Render directly (one load balancer) | `1` |
| Vercel rewrite → Render | `1` or `2`: **verify, do not assume** |

### How to verify after deploying

1. Temporarily log `request.remote_addr` and the raw `X-Forwarded-For` header
   on `/api/health` (remove the logging afterwards).
2. Call the endpoint from two different networks, for example home Wi-Fi and
   mobile data.
3. If the logged `remote_addr` differs per network and matches each real
   client IP, the hop count is correct.
4. If both networks show the same IP (a Vercel or Render address), raise the
   count by one and test again.
5. Never set a number higher than the real proxy count. With too many hops,
   a visitor can forge `X-Forwarded-For` and bypass rate limiting.

Re-verify whenever the hosting setup changes.

### Production flags that must be set on Render

- `JWT_COOKIE_SECURE=true` (otherwise the refresh cookie is not marked Secure)
- `CORS_ORIGINS` empty (same-origin deployment) or the exact web origin
- `PROXY_FIX_HOPS` set to the value verified above

### Known limitation

`memory://` rate-limit counters also reset when Render restarts or spins down
an idle service, not only on deploys. Acceptable for this deployment size;
use a shared Redis store before scaling out.

## 4. Rate limit storage

Flask-Limiter keeps its counters in `RATELIMIT_STORAGE_URI`:

| Value | Behaviour |
| --- | --- |
| `memory://` (default) | Counters live in the process. They reset on every restart, and every worker keeps its own set. |
| `redis://HOST:PORT/0` | Counters live in a shared store. Correct for more than one worker. Requires the `redis` package (`pip install redis`). |

`memory://` is acceptable for the current deployment, because `render.yaml`
pins `gunicorn --workers 1`. The app logs this at startup, and logs a
**warning** instead of an informational message when `WEB_CONCURRENCY` is
greater than one, because with N workers a client can make N times the
attempt rate the limit was meant to allow.

Before scaling out, set `RATELIMIT_STORAGE_URI` to a shared store and add the
driver package to `backend/requirements.txt`.

## 5. CORS

`CORS_ORIGINS` takes a comma-separated list of **exact** origins. Wildcards
are refused, and an unset value means no cross-origin request is allowed.

The recommended deployment serves the web app and the API from one origin
(the Vercel `/api/:path*` rewrite in `frontend/web/vercel.json`), so CORS is
not needed at all and `CORS_ORIGINS` can stay empty. This is also what keeps
the refresh cookie first-party, so `SameSite=Lax` applies and the cookie is
never sent on a cross-site request.

## 6. Token storage in the clients

| Client | Access token | Refresh token |
| --- | --- | --- |
| Native (Android/iOS/desktop) | `flutter_secure_storage` (OS keychain/keystore) | `flutter_secure_storage` (OS keychain/keystore) |
| Web | In memory only | HttpOnly cookie, managed by the browser |

The web client never writes a token to `localStorage`/`shared_preferences`.
Anything stored there is readable by every script that runs on the page, so one
XSS payload would be enough to steal a long-lived refresh token and keep using
it after the tab is closed. The in-memory access token is short-lived (15
minutes) and never outlives the tab.

### The trade-off

The refresh cookie is first-party, so it is only sent when the web app and the
API share an origin. A **cross-origin** web deployment (the web app on
`app.example.com`, the API on `api.example.com`) therefore cannot use the
cookie flow, and the refresh token cannot be persisted anywhere safe. The
client keeps it in memory only, so the user signs in again after a page
reload. That is the deliberate trade: a shorter session, instead of a refresh
token in a place any script can read.

To keep the same-origin flow, deploy the web app behind the same origin as
the API (the Vercel rewrite) and leave `CORS_ORIGINS` empty.

Note that the refresh cookie is also `SameSite=Lax`, so a cross-site XHR
request would not carry it even if the domains were configured to allow it.
