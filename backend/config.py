import os
import re
from datetime import timedelta
from pathlib import Path
from urllib.parse import quote_plus
from dotenv import load_dotenv

# The project keeps its .env at the repo root (one level above backend/).
# Load that first so `python run.py` works from any working directory, then
# let later assignments in the environment win (load_dotenv never overrides).
_PROJECT_ENV = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_PROJECT_ENV)
load_dotenv()  # backend/.env still wins if someone keeps one there


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

    ``CORS_ORIGINS`` is a comma-separated list. An entry containing ``*`` is
    treated as a wildcard pattern (``http://localhost:*`` matches any port);
    everything else is matched exactly.

    Safety rules:
    - A bare ``*`` (allow every origin) is never returned. It is refused
      regardless of FLASK_DEBUG, so a debug flag can never widen the allowlist
      to every website. Local development still works via the explicit
      localhost entries below (or by listing ``http://localhost:*``).
    - An empty/missing value defaults to localhost on any port.
    """
    raw = os.getenv("CORS_ORIGINS", "").strip()
    if not raw or raw == "*":
        if raw == "*":
            import warnings

            warnings.warn(
                "CORS_ORIGINS='*' is refused; defaulting to localhost. Set "
                "explicit origins (e.g. http://localhost:* for local dev).",
                RuntimeWarning,
            )
        return [
            re.compile(r"^http://localhost:\d+$"),
            re.compile(r"^http://127\.0\.0\.1:\d+$"),
        ]
    origins = []
    for part in raw.split(","):
        entry = part.strip()
        if not entry:
            continue
        if "*" in entry:
            pattern = "^" + re.escape(entry).replace(r"\*", ".*") + "$"
            origins.append(re.compile(pattern))
        else:
            origins.append(entry)
    return origins or [
        re.compile(r"^http://localhost:\d+$"),
        re.compile(r"^http://127\.0\.0\.1:\d+$"),
    ]


class Config:
    SQLALCHEMY_DATABASE_URI = _database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = _engine_options(SQLALCHEMY_DATABASE_URI)

    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "0") == "1"
    TESTING = os.getenv("TESTING", "0") == "1"

    # Fail fast instead of silently signing tokens with a well-known secret.
    # Tests set JWT_SECRET_KEY before importing the app; local dev gets it
    # from the project-root .env.
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
    if not JWT_SECRET_KEY:
        raise RuntimeError(
            "JWT_SECRET_KEY is not set. Add it to the project-root .env file "
            "(see backend/.env.example)."
        )

    # Short-lived access token, longer-lived refresh token (rotated on use).
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    # Refresh tokens are delivered as an HttpOnly cookie on the web (first-party
    # via the same-origin deployment). Mobile clients receive them in the JSON
    # body instead and store them in the OS keychain.
    JWT_REFRESH_COOKIE_PATH = "/api/auth"
    JWT_COOKIE_SAMESITE = "Lax"
    # Double-submit CSRF is unnecessary here: the cookie is HttpOnly, first-party
    # and SameSite=Lax, so cross-site POSTs cannot ride it.
    JWT_COOKIE_CSRF_PROTECT = False
    # Must be True in production (HTTPS). Defaults off so local http dev works.
    JWT_COOKIE_SECURE = os.getenv("JWT_COOKIE_SECURE", "false").lower() == "true"

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
