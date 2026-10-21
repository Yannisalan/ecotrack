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
