"""Tests for Flask-Limiter default rate-limit enforcement."""

from config import Config
from app import create_app


def test_default_rate_limit_enforced_on_health():
    """Verify the default limit rejects requests after its threshold."""

    class _DefaultLimitConfig(Config):
        RATELIMIT_ENABLED = True
        RATELIMIT_DEFAULT = "5 per minute"
        RATELIMIT_STORAGE_URI = "memory://"

    app = create_app(_DefaultLimitConfig)

    with app.test_client() as client:
        statuses = [
            client.get("/api/health").status_code
            for _ in range(7)
        ]

    assert statuses == [200, 200, 200, 200, 200, 429, 429]


def test_each_app_uses_its_own_default_rate_limit():
    """A later app must not inherit the first app's default limit.

    Flask-Limiter's limiter is a module-level singleton (the route
    decorators bind to it at import time) and it only reads
    RATELIMIT_DEFAULT the first time it is initialised.
    """

    class _TightConfig(Config):
        RATELIMIT_ENABLED = True
        RATELIMIT_DEFAULT = "2 per minute"
        RATELIMIT_STORAGE_URI = "memory://"

    class _LooseConfig(Config):
        RATELIMIT_ENABLED = True
        RATELIMIT_DEFAULT = "50 per minute"
        RATELIMIT_STORAGE_URI = "memory://"

    with create_app(_TightConfig).test_client() as client:
        tight = [client.get("/api/health").status_code for _ in range(3)]
    assert tight == [200, 200, 429]

    with create_app(_LooseConfig).test_client() as client:
        loose = [client.get("/api/health").status_code for _ in range(3)]
    assert loose == [200, 200, 200]
