from flask import request
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

db = SQLAlchemy()
jwt = JWTManager()
cors = CORS()


def rate_limit_key():
    """Key rate limits on the authenticated user when present, else the client IP.

    Authenticated routes are keyed per user so one account cannot be throttled
    by, or throttle, another sharing an IP (common on NAT/mobile). Auth routes
    (login/register/reset) are unauthenticated and fall back to the
    (proxy-aware) remote address.

    The identity is read from an already-verified request context when one
    exists; otherwise the token is decoded *without* verification (JWTs are
    self-describing and the route verifies it properly). This avoids running
    the blocklist/user lookup twice per request, which is what
    ``verify_jwt_in_request`` would cause here.
    """
    from flask_jwt_extended import decode_token

    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        raw = auth_header[7:].strip()
        if raw:
            try:
                payload = decode_token(raw, allow_expired=True)
                sub = payload.get("sub")
                if sub:
                    return f"user:{sub}"
            except Exception:
                pass
    return f"ip:{get_remote_address()}"



# Rate limiting: memory storage is per-process, which is fine for the
# single-worker gunicorn setup on Render. Disabled entirely in tests via
# RATELIMIT_ENABLED=false. default_limits is left unset so the value from
# Config.RATELIMIT_DEFAULT is applied by init_app.
limiter = Limiter(key_func=rate_limit_key)
