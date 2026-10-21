"""End-to-end checks for the security fixes.

Each test here maps to one of the verification steps requested for the
security fix pass, and runs with the production defaults (a 1 MB body cap,
the real per-route rate limits) instead of the relaxed ones the rest of the
suite uses.
"""

import json

import pytest

from app import create_app
from config import Config


class _HardenedConfig(Config):
    """The real limits, with their own counter store."""
    RATELIMIT_ENABLED = True
    RATELIMIT_STORAGE_URI = "memory://"
    MAX_CONTENT_LENGTH = 1024 * 1024
    CORS_ORIGINS = ["https://app.example"]


@pytest.fixture
def hardened_app():
    return create_app(_HardenedConfig)


def _register(client, email, name="User"):
    r = client.post(
        "/api/auth/register",
        json={
            "name": name,
            "email": email,
            "password": "secret123",
            "terms_accepted": True,
        },
    )
    assert r.status_code == 201, r.get_json()
    return {"Authorization": f"Bearer {r.get_json()['access_token']}"}


# 1. Security headers ------------------------------------------------------

def test_security_headers_are_present(hardened_app):
    with hardened_app.test_client() as client:
        r = client.get("/api/health")

    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["X-Frame-Options"] == "DENY"
    assert r.headers["Referrer-Policy"] == "no-referrer"
    assert r.headers["Cache-Control"] == "no-store"
    assert "default-src 'none'" in r.headers["Content-Security-Policy"]

    # HSTS is only sent once the connection is already HTTPS.
    assert "Strict-Transport-Security" not in r.headers


# 2. CORS ------------------------------------------------------------------

def test_cors_blocks_an_unlisted_origin(hardened_app):
    with hardened_app.test_client() as client:
        blocked = client.get(
            "/api/health", headers={"Origin": "https://evil.example"}
        )
        allowed = client.get(
            "/api/health", headers={"Origin": "https://app.example"}
        )

    assert "Access-Control-Allow-Origin" not in blocked.headers
    assert allowed.headers.get("Access-Control-Allow-Origin") == "https://app.example"


# 3. Rate limiting ---------------------------------------------------------

def test_repeated_login_attempts_are_rate_limited(hardened_app):
    with hardened_app.test_client() as client:
        statuses = [
            client.post(
                "/api/auth/login",
                json={"email": "victim@example.com", "password": "wrong-password"},
            ).status_code
            for _ in range(20)
        ]

    assert 429 in statuses
    # The limit must be reached well before 20 attempts.
    assert statuses.index(429) <= 12


# 4. Cross-user access (IDOR) ---------------------------------------------

def test_a_user_cannot_read_another_users_activity(hardened_app):
    with hardened_app.test_client() as client:
        owner = _register(client, "owner@example.com", "Owner")
        intruder = _register(client, "intruder@example.com", "Intruder")

        created = client.post(
            "/api/activities",
            json={"category": "transport", "type": "car_petrol", "quantity": 10},
            headers=owner,
        )
        assert created.status_code == 201, created.get_json()
        activity_id = created.get_json()["activity"]["id"]

        read = client.get(f"/api/activities/{activity_id}", headers=intruder)
        assert read.status_code in (403, 404)
        assert "car_petrol" not in read.get_data(as_text=True)

        listing = client.get("/api/activities", headers=intruder).get_json()
        assert listing["total"] == 0

        patched = client.patch(
            f"/api/activities/{activity_id}",
            json={"quantity": 999},
            headers=intruder,
        )
        assert patched.status_code in (403, 404)

        deleted = client.delete(f"/api/activities/{activity_id}", headers=intruder)
        assert deleted.status_code in (403, 404)

        # The owner still has full access to their own activity.
        assert client.get(
            f"/api/activities/{activity_id}", headers=owner
        ).status_code == 200


# 5. Oversized body -------------------------------------------------------

def test_oversized_body_is_rejected(hardened_app):
    with hardened_app.test_client() as client:
        auth = _register(client, "big@example.com", "Big")

        oversized = {
            "category": "transport",
            "type": "car_petrol",
            "quantity": 1,
            "note": "x" * (1024 * 1024 + 1024),
        }
        r = client.post(
            "/api/activities",
            data=json.dumps(oversized),
            content_type="application/json",
            headers=auth,
        )

    assert r.status_code == 413
    assert "too large" in r.get_json()["error"].lower()


def test_invalid_token_is_rejected(hardened_app):
    with hardened_app.test_client() as client:
        r = client.get(
            "/api/auth/me", headers={"Authorization": "Bearer not-a-real-token"}
        )

    assert r.status_code == 401
    assert set(r.get_json()) == {"error"}
