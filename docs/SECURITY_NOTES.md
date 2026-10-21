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

```
default-src 'self';
script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval';
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob:;
font-src 'self' data:;
connect-src 'self';
worker-src 'self' blob:;
manifest-src 'self';
frame-ancestors 'none';
base-uri 'self';
object-src 'none'
```

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
proxies sit in front of it. `PROXY_FIX_HOPS` is that number:

| Deployment | `PROXY_FIX_HOPS` |
| --- | --- |
| Local `python run.py` | `0` (default in debug) |
| Render (one load balancer) | `1` (set in `render.yaml`) |

With the wrong value, either the real client IP is hidden behind the proxy
IP (every visitor shares one rate-limit bucket) or `X-Forwarded-For` is
trusted from an untrusted party (a visitor can forge their IP and bypass rate
limiting entirely).

`ProxyFix` is only applied when the count is greater than zero, so a direct
connection never trusts a spoofable header.

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
