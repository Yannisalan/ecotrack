import os

# Must happen BEFORE the app/config are imported, so tests can never touch the real database.
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-that-is-long-enough-for-hs256"
# Secure cookies would not be sent over the test client's http transport.
os.environ["JWT_COOKIE_SECURE"] = "false"
# Rate limits would make the suite flaky; a dedicated test re-enables them.
os.environ["RATELIMIT_ENABLED"] = "false"
# Let the password-reset tests read the token from the forgot-password response.
os.environ["RESET_TOKEN_IN_RESPONSE"] = "true"
os.environ["REMINDER_SCHEDULER"] = "false"
# Never start the background scheduler during tests.
os.environ["TESTING"] = "1"
# No trusted proxy in tests, so X-Forwarded-For must not be honored.
os.environ["PROXY_FIX_HOPS"] = "0"
# Cross-origin access is denied in tests unless a test opts in explicitly, so
# the suite never depends on the developer's local .env.
os.environ["CORS_ORIGINS"] = ""

import pytest  # noqa: E402
from app import create_app  # noqa: E402
from config import Config  # noqa: E402

assert Config.SQLALCHEMY_DATABASE_URI.startswith("sqlite"), \
    "Tests must run against SQLite, never the real database"


@pytest.fixture
def client():
    app = create_app()
    with app.test_client() as c:
        yield c


def register(client, email="a@b.com", name="Alex", password="secret123",
             terms_accepted=True):
    return client.post(
        "/api/auth/register",
        json={
            "name": name,
            "email": email,
            "password": password,
            "terms_accepted": terms_accepted,
        },
    )


@pytest.fixture
def auth(client):
    """Auth header for a freshly registered user."""
    r = register(client)
    assert r.status_code == 201
    return {"Authorization": f"Bearer {r.get_json()['access_token']}"}


@pytest.fixture
def other_auth(client):
    """Auth header for a second, different user."""
    r = register(client, email="other@b.com", name="Other")
    assert r.status_code == 201
    return {"Authorization": f"Bearer {r.get_json()['access_token']}"}


def add_activity(client, headers, category="transport", type_="car_petrol",
                 quantity=10, date=None):
    body = {"category": category, "type": type_, "quantity": quantity}
    if date is not None:
        body["date"] = date.isoformat()
    r = client.post("/api/activities", json=body, headers=headers)
    assert r.status_code == 201, r.get_json()
    return r.get_json()["activity"]