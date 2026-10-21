import os
from datetime import timedelta
from pathlib import Path
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Minimum length for the JWT signing secret. HS256 is a symmetric signature:
# a short secret is brute-forceable, so anything shorter is refused outright
# rather than silently accepted.
MIN_JWT_SECRET_LENGTH = 32

# The project keeps its .env at the repo root (one level above backend/).
# Load that first so `python run.py` works from any working directory, then
# let later assignments in the environment win (load_dotenv never overrides).
_PROJECT_ENV = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_PROJECT_ENV)
load_dotenv()  # backend/.env still wins if someone keeps one there


def validate_jwt_secret(secret):
    """Return the secret, or raise a clear RuntimeError if it is unusable.

    Called at import time so the app refuses to start rather than issuing
    tokens signed with a missing or guessable key.
    """
    if not secret or not secret.strip():
        raise RuntimeError(
            "JWT_SECRET_KEY is not set. Add it to the project-root .env file "
            "(see backend/.env.example)."
        )
    if len(secret.strip()) < MIN_JWT_SECRET_LENGTH:
        raise RuntimeError(
            "JWT_SECRET_KEY is too short: it must be at least "
            f"{MIN_JWT_SECRET_LENGTH} characters (got {len(secret.strip())}). "
            "Generate a strong one with: "
            'python -c "import secrets; print(secrets.token_hex(32))"'
        )
    return secret


def _database_uri():
    url = os.getenv("DATABASE_URL")
    if url:
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql+psycopg://", 1)
        elif url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+psycopg://", 1)
        return url
    return (
        f"postgresql+psycopg://{os.getenv('DB_USER', 'postgres')}:"
        f"{quote_plus(os.getenv('DB_PASSWORD', ''))}"
        f"@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}"
        f"/{os.getenv('DB_NAME', 'ecotrack')}"
    )


def _engine_options(uri):
    opts = {"pool_pre_ping": True, "pool_recycle": 300}
    if uri.startswith("postgresql+psycopg://"):
        # Safe with Neon's pooled (PgBouncer) endpoint: no server-side prepared statements
        opts["connect_args"] = {"prepare_threshold": None}
    return opts


def _cors_origins():
    """Origins allowed to call the API cross-origin.

    ``CORS_ORIGINS`` is a comma-separated list of *exact* origins, for example
    ``https://app.example.com``.

    Safety rules:
    - Wildcards are not supported at all. An entry containing ``*`` is dropped
      with a warning, because a wildcard allowlist lets any site on the
      internet drive the API with the user's cookies. A bare ``*`` is just
      another dropped entry.
    - An unset or empty value yields an empty list, i.e. no cross-origin
      request is allowed. That is the right default for the recommended
      deployment, where the web app and the API share one origin and no
      CORS configuration is needed at all.
    """
    raw = os.getenv("CORS_ORIGINS", "").strip()
    if not raw:
        return []

    import warnings

    origins = []
    for part in raw.split(","):
        entry = part.strip()
        if not entry:
            continue
        if "*" in entry:
            warnings.warn(
                f"Ignoring wildcard CORS origin {entry!r}: wildcards are not "
                "allowed. List exact origins instead (e.g. "
                "https://app.example.com).",
                RuntimeWarning,
            )
            continue
        origins.append(entry)
    return origins


class Config:
    SQLALCHEMY_DATABASE_URI = _database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options(SQLALCHEMY_DATABASE_URI)

    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "0") == "1"
    TESTING = os.getenv("TESTING", "0") == "1"

    # Fail fast instead of silently signing tokens with a well-known secret.
    # Tests set JWT_SECRET_KEY before importing the app; local dev gets it
    # from the project-root .env. A secret shorter than
    # MIN_JWT_SECRET_LENGTH is refused too: HS256 is symmetric, so a short
    # key is brute-forceable.
    JWT_SECRET_KEY = validate_jwt_secret(os.getenv("JWT_SECRET_KEY"))

    # Short-lived access token, longer-lived refresh token (rotated on use).
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    # Access tokens are accepted from the Authorization header only. Cookies
    # and the JSON body are not access-token locations, so a value that leaks
    # out of those channels cannot be replayed as a bearer token.
    JWT_TOKEN_LOCATION = ["headers"]

    # Refresh tokens are delivered as an HttpOnly cookie on the web (first-party
    # via the same-origin deployment). Mobile clients receive them in the JSON
    # body instead and store them in the OS keychain.
    JWT_REFRESH_COOKIE_PATH = "/api/auth"
    JWT_COOKIE_SAMESITE = "Lax"
    # Double-submit CSRF is unnecessary here: the cookie is HttpOnly, first-party
    # and SameSite=Lax, so cross-site POSTs cannot ride it.
    JWT_COOKIE_CSRF_PROTECT = False

    # Secure by default: browsers only send the refresh cookie over HTTPS.
    # Local http development and the test suite opt out explicitly.
    _cookie_secure_env = os.getenv("JWT_COOKIE_SECURE", "").strip().lower()
    JWT_COOKIE_SECURE = (
        _cookie_secure_env in ("1", "true", "yes", "on")
        if _cookie_secure_env
        else not (FLASK_DEBUG or TESTING)
    )

    CORS_ORIGINS = _cors_origins()

    # Cap request bodies so a client cannot exhaust memory with a huge JSON
    # payload before validation runs (413 is returned by the handler in
    # app/__init__.py). 1 MB is ample for the largest batch sync.
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(1024 * 1024)))

    # Trust the reverse proxy (Render/Vercel) so rate limiting keys on the real
    # client IP. PROXY_FIX_HOPS is the number of trusted proxies in front of the
    # app; 1 is correct for a single Render load balancer. Defaults to 1 in
    # production and 0 in debug/tests, so a direct connection never trusts a
    # spoofable X-Forwarded-For header.
    PROXY_FIX_HOPS = int(os.getenv(
        "PROXY_FIX_HOPS",
        "0" if (FLASK_DEBUG or os.getenv("TESTING", "0") == "1") else "1",
    ))

    # Per-IP rate limiting (Flask-Limiter). Disabled in tests.
    RATELIMIT_ENABLED = os.getenv("RATELIMIT_ENABLED", "true").lower() == "true"
    RATELIMIT_STORAGE_URI = os.getenv("RATELIMIT_STORAGE_URI", "memory://")
    # Default limit applied to every route that does not declare its own.
    RATELIMIT_DEFAULT = os.getenv("RATELIMIT_DEFAULT", "120 per minute")

    # Password reset: no SMTP integration exists, so the freshly minted reset
    # token is only echoed in the forgot-password response when enabled.
    # Defaults OFF everywhere, including debug: the endpoint is unauthenticated,
    # so echoing a working token would let anyone reset any account. Enable it
    # explicitly (demo only) with RESET_TOKEN_IN_RESPONSE=true.
    RESET_TOKEN_IN_RESPONSE = os.getenv(
        "RESET_TOKEN_IN_RESPONSE", "false"
    ).lower() == "true"

    # Hourly background job that materializes reminder notifications for every
    # user (so the inbox is populated even if the client never polls).
    REMINDER_SCHEDULER = os.getenv("REMINDER_SCHEDULER", "false").lower() == "true"

    # Master switch for the in-process APScheduler (token purge + optional
    # reminders). OFF by default because create_app() runs in every gunicorn
    # worker and under the Werkzeug reloader: starting a scheduler per process
    # would double-run jobs. Enable it only on a single-worker deployment
    # (`gunicorn run:app --workers 1`) or move jobs to an external cron.
    ENABLE_SCHEDULER = os.getenv("ENABLE_SCHEDULER", "false").lower() == "true"
