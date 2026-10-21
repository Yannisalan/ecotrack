"""Password reset, rate limiting, CORS origins and scheduled reminders."""

import importlib
import os
from datetime import datetime, timedelta, timezone
from app.extensions import limiter
from config import Config, validate_jwt_secret
from app import create_app
from app.extensions import db
from app.models import (
    Notification,
    PasswordResetToken,
    TokenBlocklist,
    User,
)
from app.maintenance import prune_expired_tokens
from app.notification_service import materialize_all
from app.validation import validate_password

from conftest import register


class _NoEchoConfig(Config):
    RESET_TOKEN_IN_RESPONSE = False


class _LimitConfig(Config):
    RATELIMIT_ENABLED = True


class _CorsConfig(Config):
    # Exact origins only: wildcard patterns are no longer supported.
    CORS_ORIGINS = ["http://localhost:5173"]


def _login(client, email="a@b.com", password="secret123"):
    return client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )


# ------------------------------------------------------------ jwt secret

def test_missing_jwt_secret_is_refused():
    for bad in (None, "", "   "):
        try:
            validate_jwt_secret(bad)
        except RuntimeError as exc:
            assert "JWT_SECRET_KEY" in str(exc)
        else:  # pragma: no cover - only reached on a regression
            raise AssertionError("a missing JWT secret must be refused")


def test_short_jwt_secret_is_refused():
    """HS256 is symmetric: a short signing key is brute-forceable."""
    try:
        validate_jwt_secret("too-short")
    except RuntimeError as exc:
        assert "32" in str(exc)
    else:  # pragma: no cover - only reached on a regression
        raise AssertionError("a short JWT secret must be refused")


def test_strong_jwt_secret_is_accepted():
    secret = "a" * 32
    assert validate_jwt_secret(secret) == secret


def test_app_refuses_to_start_with_weak_secret(monkeypatch):
    """The startup check really blocks the app, not just the helper."""
    monkeypatch.setenv("JWT_SECRET_KEY", "weak")
    import config as config_module

    monkeypatch.delitem(config_module.__dict__, "Config", raising=False)
    try:
        importlib.reload(config_module)
    except RuntimeError as exc:
        assert "JWT_SECRET_KEY" in str(exc)
    else:  # pragma: no cover - only reached on a regression
        raise AssertionError("the app must refuse to start with a weak secret")
    finally:
        monkeypatch.setenv(
            "JWT_SECRET_KEY", "test-secret-key-that-is-long-enough-for-hs256"
        )
        importlib.reload(config_module)


def test_env_example_has_no_real_secret():
    """The committed template must carry placeholders, never real values."""
    from pathlib import Path

    example = Path(__file__).resolve().parent.parent / ".env.example"
    text = example.read_text(encoding="utf-8")
    assert "JWT_SECRET_KEY=" in text
    for line in text.splitlines():
        if line.startswith("JWT_SECRET_KEY="):
            assert line.split("=", 1)[1].strip() == "", "JWT_SECRET_KEY must be blank"


# ------------------------------------------------------------ cookie flags

def test_refresh_cookie_is_secure_by_default(monkeypatch):
    """The refresh cookie must not travel over plain HTTP in production."""
    import importlib
    import config

    try:
        monkeypatch.delenv("JWT_COOKIE_SECURE", raising=False)
        monkeypatch.setenv("FLASK_DEBUG", "0")
        monkeypatch.setenv("TESTING", "0")
        importlib.reload(config)
        assert config.Config.JWT_COOKIE_SECURE is True

        # An explicit opt-out still wins.
        monkeypatch.setenv("JWT_COOKIE_SECURE", "false")
        importlib.reload(config)
        assert config.Config.JWT_COOKIE_SECURE is False

        # Local http development is allowed to use a plain cookie.
        monkeypatch.delenv("JWT_COOKIE_SECURE", raising=False)
        monkeypatch.setenv("FLASK_DEBUG", "1")
        importlib.reload(config)
        assert config.Config.JWT_COOKIE_SECURE is False
    finally:
        monkeypatch.undo()
        importlib.reload(config)  # restore module state


def test_access_token_location_is_header_only():
    """Cookies and the JSON body must never be valid access-token locations."""
    assert Config.JWT_TOKEN_LOCATION == ["headers"]


def test_refresh_locations_match_the_clients():
    """The web client uses the cookie, mobile uses the JSON body."""
    from app.auth import _REFRESH_LOCATIONS

    assert "cookies" in _REFRESH_LOCATIONS
    assert "json" in _REFRESH_LOCATIONS
    assert "headers" not in _REFRESH_LOCATIONS


def test_forgot_and_reset_password(client):
    register(client)
    old = _login(client)
    old_headers = {
        "Authorization": f"Bearer {old.get_json()['access_token']}"
    }

    response = client.post(
        "/api/auth/forgot-password",
        json={"email": "a@b.com"},
    )
    assert response.status_code == 200
    token = response.get_json()["reset_token"]
    assert token

    response = client.post(
        "/api/auth/reset-password",
        json={"token": token, "password": "newsecret99"},
    )
    assert response.status_code == 200

    # Old sessions are invalidated by the token_version bump.
    response = client.get("/api/auth/me", headers=old_headers)
    assert response.status_code == 401

    # The old password no longer works, but the new password does.
    assert _login(client, password="secret123").status_code == 401
    assert _login(client, password="newsecret99").status_code == 200


def test_reset_token_is_single_use(client):
    register(client)

    token_response = client.post(
        "/api/auth/forgot-password",
        json={"email": "a@b.com"},
    )
    token = token_response.get_json()["reset_token"]

    first = client.post(
        "/api/auth/reset-password",
        json={"token": token, "password": "newsecret99"},
    )
    assert first.status_code == 200

    second = client.post(
        "/api/auth/reset-password",
        json={"token": token, "password": "another99x"},
    )
    assert second.status_code == 400
    assert "expired" in second.get_json()["error"].lower()


def test_forgot_password_never_leaks_account_existence():
    app = create_app(_NoEchoConfig)

    with app.test_client() as client:
        register(client)

        known = client.post(
            "/api/auth/forgot-password",
            json={"email": "a@b.com"},
        )
        unknown = client.post(
            "/api/auth/forgot-password",
            json={"email": "nobody@x.com"},
        )

        assert known.status_code == unknown.status_code == 200
        assert "reset_token" not in known.get_json()
        assert known.get_json() == unknown.get_json()

        # Only the known email produced a reset-token row.
        with app.app_context():
            assert PasswordResetToken.query.count() == 1


def test_reset_validates_input(client):
    register(client)

    response = client.post(
        "/api/auth/reset-password",
        json={"token": "x", "password": "short"},
    )
    assert response.status_code == 400

    response = client.post(
        "/api/auth/reset-password",
        json={"token": "", "password": "longenough"},
    )
    assert response.status_code == 400

    client.post(
        "/api/auth/forgot-password",
        json={"email": "a@b.com"},
    )

    response = client.post(
        "/api/auth/reset-password",
        json={
            "token": "not-a-real-token",
            "password": "longenough",
        },
    )
    assert response.status_code == 400


def test_change_password(client):
    register(client)
    login = _login(client)
    headers = {
        "Authorization": f"Bearer {login.get_json()['access_token']}"
    }

    response = client.post(
        "/api/auth/change-password",
        json={
            "current_password": "wrong-pass",
            "new_password": "newsecret99",
        },
        headers=headers,
    )
    assert response.status_code == 400

    response = client.post(
        "/api/auth/change-password",
        json={
            "current_password": "secret123",
            "new_password": "newsecret99",
        },
        headers=headers,
    )
    assert response.status_code == 200

    # Changing the password invalidates the token that performed it.
    assert client.get("/api/auth/me", headers=headers).status_code == 401
    assert _login(client, password="newsecret99").status_code == 200


def test_login_rate_limit():
    app = create_app(_LimitConfig)

    with app.test_client() as client:
        register(client, email="rl@b.com")

        statuses = [
            _login(
                client,
                email="rl@b.com",
                password="wrong-password",
            ).status_code
            for _ in range(25)
        ]

        assert 429 in statuses


def test_cors_reflects_configured_origins():
    app = create_app(_CorsConfig)

    with app.test_client() as client:
        allowed = client.get(
            "/api/health",
            headers={"Origin": "http://localhost:5173"},
        )
        assert (
            allowed.headers.get("Access-Control-Allow-Origin")
            == "http://localhost:5173"
        )

        denied = client.get(
            "/api/health",
            headers={"Origin": "https://evil.example"},
        )
        assert denied.headers.get("Access-Control-Allow-Origin") is None


def test_materialize_all_runs_for_every_user(client):
    register(client)
    register(client, email="other2@b.com", name="Other2")

    with client.application.app_context():
        processed = materialize_all()

        assert processed == 2

        # Fresh users receive the onboarding notification.
        assert Notification.query.filter_by(code="onboarding").count() == 2


def test_access_token_invalidated_by_password_change(client):
    """Verify that password changes invalidate existing access tokens."""
    register(client)

    login = _login(client)
    headers = {
        "Authorization": f"Bearer {login.get_json()['access_token']}"
    }

    assert client.get("/api/auth/me", headers=headers).status_code == 200

    client.post(
        "/api/auth/change-password",
        json={
            "current_password": "secret123",
            "new_password": "newsecret99",
        },
        headers=headers,
    )

    # The same access token must now be rejected.
    assert client.get("/api/auth/me", headers=headers).status_code == 401


def test_password_policy_rejects_common_and_short():
    assert validate_password("short") is not None
    assert validate_password("password") is not None
    assert validate_password("aaaaaaaa") is not None
    assert validate_password("a-strong-passphrase") is None


def test_register_rejects_weak_password(client):
    response = client.post(
        "/api/auth/register",
        json={
            "name": "X",
            "email": "weak@b.com",
            "password": "password",
        },
    )

    assert response.status_code == 400
    assert "common" in response.get_json()["error"].lower()


def test_request_body_size_limit():
    class _SmallConfig(Config):
        MAX_CONTENT_LENGTH = 256

    app = create_app(_SmallConfig)

    with app.test_client() as client:
        big = "x" * 1024

        response = client.post(
            "/api/auth/register",
            json={
                "name": big,
                "email": "b@b.com",
                "password": big,
            },
        )

        assert response.status_code == 413
        assert "too large" in response.get_json()["error"].lower()


def test_security_headers_present(client):
    response = client.get("/api/health")

    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("Cache-Control") == "no-store"


def test_purge_expired_tokens(client):
    register(client)

    with client.application.app_context():
        user = User.query.filter_by(email="a@b.com").first()
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        # One expired and one active blocklist entry, plus one expired
        # and one active password-reset token.
        db.session.add_all(
            [
                TokenBlocklist(
                    jti="expired-1",
                    user_id=user.id,
                    expires_at=now - timedelta(days=1),
                ),
                TokenBlocklist(
                    jti="live-1",
                    user_id=user.id,
                    expires_at=now + timedelta(days=1),
                ),
                PasswordResetToken(
                    user_id=user.id,
                    token_hash="a" * 64,
                    expires_at=now - timedelta(days=1),
                ),
                PasswordResetToken(
                    user_id=user.id,
                    token_hash="b" * 64,
                    expires_at=now + timedelta(days=1),
                ),
            ]
        )
        db.session.commit()

        blocked, resets = prune_expired_tokens()

        assert blocked == 1
        assert resets == 1

        assert (
            TokenBlocklist.query.filter_by(jti="live-1").first()
            is not None
        )
        assert (
            PasswordResetToken.query.filter_by(
                token_hash="b" * 64
            ).first()
            is not None
        )


def test_default_rate_limit_is_configured():
    """Verify the default limit is configured for non-exempt routes."""
    from app.extensions import limiter

    app = create_app()

    assert app.config["RATELIMIT_DEFAULT"]
    assert limiter.enabled is False  # Disabled by conftest for the suite.
    assert (
        limiter.limit_manager._default_limits
        or app.config["RATELIMIT_DEFAULT"]
    )
