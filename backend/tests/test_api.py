from datetime import date, timedelta

import pytest

from conftest import add_activity, register

TODAY = date.today()


# ---------------------------------------------------------------- auth

def test_register_success(client):
    r = register(client, email="New@Example.com")
    assert r.status_code == 201
    data = r.get_json()
    assert data["user"]["email"] == "new@example.com"  # normalised to lowercase
    assert data["access_token"]
    assert "password" not in str(data).lower().replace("password_hash", "")


def test_register_duplicate_email_is_generic(client):
    """A duplicate email must not be distinguishable from any other failure."""
    assert register(client, email="a@b.com").status_code == 201

    duplicate = register(client, email="A@B.com")
    assert duplicate.status_code == 400
    body = duplicate.get_json()
    assert set(body) == {"error"}

    # The wording must not confirm that the address is taken.
    lowered = body["error"].lower()
    for leak in ("already", "registered", "exists", "taken", "duplicate", "email"):
        assert leak not in lowered, f"response leaks account existence: {body}"


def test_register_duplicate_response_matches_a_generic_failure(client):
    """The duplicate answer is the same as any other rejected registration."""
    from app.errors import MSG_BAD_REQUEST

    assert register(client, email="dup@b.com").status_code == 201
    duplicate = register(client, email="dup@b.com")
    assert duplicate.get_json()["error"] == MSG_BAD_REQUEST


def test_register_duplicate_keeps_the_rate_limit(client):
    """Anti-enumeration must not weaken the rate limit."""
    from app import create_app
    from config import Config

    class _LimitConfig(Config):
        RATELIMIT_ENABLED = True

    app = create_app(_LimitConfig)
    with app.test_client() as c:
        first = c.post(
            "/api/auth/register",
            json={"name": "A", "email": "rl-dup@b.com",
                  "password": "secret123", "terms_accepted": True},
        )
        assert first.status_code == 201

        statuses = [
            c.post(
                "/api/auth/register",
                json={"name": "A", "email": "rl-dup@b.com",
                      "password": "secret123", "terms_accepted": True},
            ).status_code
            for _ in range(15)
        ]

    assert 429 in statuses


def test_register_requires_terms_acceptance(client):
    """Missing or falsy consent must never create an account."""
    for accepted in (None, False):
        payload = {"name": "No Consent", "email": "no-consent@b.com",
                   "password": "secret123"}
        if accepted is not None:
            payload["terms_accepted"] = accepted
        r = client.post("/api/auth/register", json=payload)
        assert r.status_code == 400
        assert "Terms" in r.get_json()["error"]
    # And the rejected attempts left nothing behind.
    r = client.post("/api/auth/login",
                    json={"email": "no-consent@b.com", "password": "secret123"})
    assert r.status_code == 401


def test_register_persists_terms_consent(client):
    """A successful registration records the flag, UTC timestamp and version."""
    from app.models import User

    r = register(client, email="consent@b.com")
    assert r.status_code == 201
    assert r.get_json()["user"]["terms_accepted"] is True
    assert r.get_json()["user"]["policy_version"] == "2026-10-21"

    with client.application.app_context():
        user = User.query.filter_by(email="consent@b.com").first()
        assert user.terms_accepted is True
        assert user.terms_accepted_at is not None
        assert user.policy_version == "2026-10-21"


@pytest.mark.parametrize("payload", [
    {"email": "a@b.com", "password": "secret123"},                  # no name
    {"name": "A", "email": "not-an-email", "password": "secret123"},
    {"name": "A", "email": "a@b.com", "password": "short"},
    {},
])
def test_register_validation(client, payload):
    r = client.post("/api/auth/register", json=payload)
    assert r.status_code == 400
    assert "error" in r.get_json()


def test_login_success_and_failures(client):
    register(client)
    ok = client.post("/api/auth/login", json={"email": "a@b.com", "password": "secret123"})
    assert ok.status_code == 200 and ok.get_json()["access_token"]
    bad = client.post("/api/auth/login", json={"email": "a@b.com", "password": "wrong-pass"})
    assert bad.status_code == 401
    unknown = client.post("/api/auth/login", json={"email": "x@y.com", "password": "secret123"})
    assert unknown.status_code == 401


def test_me(client, auth):
    assert client.get("/api/auth/me").status_code == 401
    assert client.get("/api/auth/me", headers={"Authorization": "Bearer garbage"}).status_code == 401
    r = client.get("/api/auth/me", headers=auth)
    assert r.status_code == 200 and r.get_json()["user"]["email"] == "a@b.com"


# ---------------------------------------------------------- activities

def test_options_are_public(client):
    r = client.get("/api/activities/options")
    assert r.status_code == 200
    cats = r.get_json()["categories"]
    assert set(cats) == {"transport", "electricity", "water", "waste"}
    assert cats["transport"]["unit"] == "km"


def test_create_calculates_co2_and_defaults_date(client, auth):
    a = add_activity(client, auth, "transport", "car_petrol", 10)
    assert a["co2_kg"] == 1.92
    assert a["unit"] == "km"
    assert a["date"] == TODAY.isoformat()


@pytest.mark.parametrize("body", [
    {"category": "transport", "type": "car_petrol", "quantity": -1},
    {"category": "transport", "type": "car_petrol", "quantity": 0},
    {"category": "transport", "type": "car_petrol", "quantity": "abc"},
    {"category": "transport", "type": "car_petrol", "quantity": True},
    {"category": "transport", "type": "car_petrol", "quantity": 1000001},
    {"category": "transport", "type": "car_petrol", "quantity": 5, "date": "2999-01-01"},
    {"category": "transport", "type": "car_petrol", "quantity": 5, "date": "01/02/2026"},
    {"category": "nonsense", "type": "car_petrol", "quantity": 5},
    {"category": "water", "type": "bus", "quantity": 5},
    {},
])
def test_create_validation(client, auth, body):
    r = client.post("/api/activities", json=body, headers=auth)
    assert r.status_code == 400
    assert "error" in r.get_json()


def test_activities_require_token(client):
    assert client.get("/api/activities").status_code == 401
    assert client.post("/api/activities", json={}).status_code == 401


def test_list_filter_and_date_range(client, auth):
    add_activity(client, auth, "transport", "bus", 5, TODAY)
    add_activity(client, auth, "water", "tap", 100, TODAY - timedelta(days=3))
    add_activity(client, auth, "transport", "bus", 5, TODAY - timedelta(days=10))

    all_rows = client.get("/api/activities", headers=auth).get_json()
    assert all_rows["total"] == 3
    dates = [a["date"] for a in all_rows["activities"]]
    assert dates == sorted(dates, reverse=True)  # newest first

    only_transport = client.get("/api/activities?category=transport", headers=auth).get_json()
    assert only_transport["total"] == 2

    recent = client.get(
        f"/api/activities?from={(TODAY - timedelta(days=5)).isoformat()}", headers=auth
    ).get_json()
    assert recent["total"] == 2

    assert client.get("/api/activities?category=zzz", headers=auth).status_code == 400
    assert client.get("/api/activities?from=bad", headers=auth).status_code == 400


def test_pagination(client, auth):
    for i in range(5):
        add_activity(client, auth, "waste", "recycling", i + 1)
    page1 = client.get("/api/activities?limit=2&offset=0", headers=auth).get_json()
    assert len(page1["activities"]) == 2 and page1["total"] == 5
    last = client.get("/api/activities?limit=2&offset=4", headers=auth).get_json()
    assert len(last["activities"]) == 1
    clamped = client.get("/api/activities?limit=500", headers=auth).get_json()
    assert clamped["limit"] == 200
    assert client.get("/api/activities?limit=abc", headers=auth).status_code == 400


def test_patch_recalculates_co2(client, auth):
    a = add_activity(client, auth, "transport", "car_petrol", 10)
    r = client.patch(f"/api/activities/{a['id']}", json={"quantity": 20}, headers=auth)
    assert r.status_code == 200 and r.get_json()["activity"]["co2_kg"] == 3.84
    r = client.patch(f"/api/activities/{a['id']}", json={"type": "bus"}, headers=auth)
    assert r.get_json()["activity"]["co2_kg"] == round(20 * 0.089, 4)
    r = client.patch(f"/api/activities/{a['id']}", json={"category": "water"}, headers=auth)
    assert r.status_code == 400  # 'bus' is not a water type
    r = client.patch(
        f"/api/activities/{a['id']}",
        json={"category": "water", "type": "tap", "quantity": 100},
        headers=auth,
    )
    assert r.status_code == 200 and r.get_json()["activity"]["unit"] == "litres"


def test_delete(client, auth):
    a = add_activity(client, auth)
    assert client.delete(f"/api/activities/{a['id']}", headers=auth).status_code == 200
    assert client.get(f"/api/activities/{a['id']}", headers=auth).status_code == 404
    assert client.delete(f"/api/activities/{a['id']}", headers=auth).status_code == 404


def test_users_cannot_touch_each_others_data(client, auth, other_auth):
    a = add_activity(client, auth)
    url = f"/api/activities/{a['id']}"
    assert client.get(url, headers=other_auth).status_code == 404
    assert client.patch(url, json={"quantity": 99}, headers=other_auth).status_code == 404
    assert client.delete(url, headers=other_auth).status_code == 404
    assert client.get("/api/activities", headers=other_auth).get_json()["total"] == 0
    # still intact for the owner
    assert client.get(url, headers=auth).get_json()["activity"]["quantity"] == 10


# --------------------------------------------------------------- stats

@pytest.mark.parametrize("path", ["summary", "score", "recommendations"])
def test_stats_require_token(client, path):
    assert client.get(f"/api/stats/{path}").status_code == 401


def test_stats_empty_state(client, auth):
    score = client.get("/api/stats/score", headers=auth).get_json()
    assert score["eco_score"] is None and score["total_co2_kg"] == 0

    summary = client.get("/api/stats/summary", headers=auth).get_json()
    assert summary["total_co2_kg"] == 0 and summary["active_days"] == 0
    assert len(summary["daily"]) == 7
    assert set(summary["by_category"]) == {"transport", "electricity", "water", "waste"}

    recs = client.get("/api/stats/recommendations", headers=auth).get_json()["recommendations"]
    assert len(recs) == 1 and recs[0]["title"] == "Start logging"


def test_stats_with_data(client, auth):
    add_activity(client, auth, "transport", "car_petrol", 10)
    add_activity(client, auth, "transport", "car_petrol", 10)

    summary = client.get("/api/stats/summary", headers=auth).get_json()
    assert summary["total_co2_kg"] == 3.84
    assert summary["by_category"]["transport"]["quantity"] == 20
    assert summary["by_category"]["transport"]["entries"] == 2
    assert summary["daily"][-1]["date"] == TODAY.isoformat()
    assert summary["daily"][-1]["co2_kg"] == 3.84

    score = client.get("/api/stats/score", headers=auth).get_json()["eco_score"]
    assert 0 <= score["score"] <= 100
    assert score["avg_daily_co2_kg"] == 3.84
    assert score["grade"] in {"Excellent", "Good", "Fair", "Needs work"}

    recs = client.get("/api/stats/recommendations", headers=auth).get_json()["recommendations"]
    assert recs[0]["category"] == "transport"
    assert recs[0]["estimated_saving_co2_kg"] > 0


def test_stats_periods(client, auth):
    add_activity(client, auth, "transport", "car_petrol", 10, TODAY)
    add_activity(client, auth, "transport", "car_petrol", 10, TODAY - timedelta(days=20))
    week = client.get("/api/stats/summary?period=week", headers=auth).get_json()
    month = client.get("/api/stats/summary?period=month", headers=auth).get_json()
    assert week["total_co2_kg"] == 1.92 and len(week["daily"]) == 7
    assert month["total_co2_kg"] == 3.84 and len(month["daily"]) == 30
    assert client.get("/api/stats/summary?period=year", headers=auth).status_code == 400


def test_stats_are_per_user(client, auth, other_auth):
    add_activity(client, auth, "transport", "car_petrol", 10)
    other = client.get("/api/stats/summary", headers=other_auth).get_json()
    assert other["total_co2_kg"] == 0


# -------------------------------------------------------------- errors

def test_unknown_route_returns_json_404(client):
    r = client.get("/api/does-not-exist")
    assert r.status_code == 404
    body = r.get_json()
    assert set(body) == {"error"}
    # Friendly, jargon-free copy — never a raw/technical string.
    assert "couldn't find" in body["error"].lower()


def test_wrong_method_returns_json_405(client):
    r = client.delete("/api/health")
    assert r.status_code == 405
    body = r.get_json()
    assert set(body) == {"error"}
    assert "isn't supported" in body["error"].lower()


def test_unhandled_error_returns_json_500():
    from app import create_app

    app = create_app()
    app.config["PROPAGATE_EXCEPTIONS"] = False

    @app.get("/api/boom")
    def boom():
        raise RuntimeError("boom")

    r = app.test_client().get("/api/boom")
    assert r.status_code == 500
    body = r.get_json()
    assert set(body) == {"error"}
    # The exception detail must never reach the client.
    assert "boom" not in body["error"].lower()
    assert "traceback" not in body["error"].lower()


def test_cors_origins_default_and_override(monkeypatch):
    import importlib
    import config

    monkeypatch.setenv("CORS_ORIGINS", "https://a.example, https://b.example")
    assert config._cors_origins() == ["https://a.example", "https://b.example"]

    # Wildcard entries are dropped outright: an allowlist that can match any
    # host would let any site drive the API with the user's cookies.
    monkeypatch.setenv("CORS_ORIGINS", "http://localhost:*,https://ok.example")
    with pytest.warns(RuntimeWarning):
        origins = config._cors_origins()
    assert origins == ["https://ok.example"]
    assert all(not hasattr(o, "search") for o in origins)

    # Unset means "no cross-origin caller at all" - not localhost.
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    assert config._cors_origins() == []

    # A bare "*" is refused too, and leaves the allowlist empty.
    monkeypatch.setenv("CORS_ORIGINS", "*")
    with pytest.warns(RuntimeWarning):
        origins = config._cors_origins()
    assert origins == []
    importlib.reload(config)  # restore module state


def test_cors_wildcard_origin_gets_no_allow_header(client):
    """A request from an unlisted origin must not be granted access."""
    r = client.get(
        "/api/health",
        headers={"Origin": "https://evil.example"},
    )
    assert r.status_code == 200
    assert "Access-Control-Allow-Origin" not in r.headers


def test_cors_exact_origin_is_allowed(client, monkeypatch):
    import importlib
    import config
    from app import create_app

    monkeypatch.setenv("CORS_ORIGINS", "https://good.example")
    importlib.reload(config)
    app = create_app(config.Config)
    with app.test_client() as c:
        r = c.get(
            "/api/health",
            headers={"Origin": "https://good.example"},
        )
        assert r.headers.get("Access-Control-Allow-Origin") == "https://good.example"
    importlib.reload(config)  # restore module state


# ------------------------------------------------------------ streak

def test_streak_starts_at_zero(client, auth):
    r = client.get('/api/stats/streak', headers=auth)
    assert r.status_code == 200
    assert r.get_json() == {'current_streak': 0, 'longest_streak': 0}


def test_streak_counts_consecutive_days(client, auth):
    add_activity(client, auth, date=TODAY)
    add_activity(client, auth, date=TODAY - timedelta(days=1))
    add_activity(client, auth, date=TODAY - timedelta(days=3))
    j = client.get('/api/stats/streak', headers=auth).get_json()
    assert j['current_streak'] == 2
    assert j['longest_streak'] == 2


def test_streak_survives_unlogged_today(client, auth):
    add_activity(client, auth, date=TODAY - timedelta(days=1))
    add_activity(client, auth, date=TODAY - timedelta(days=2))
    j = client.get('/api/stats/streak', headers=auth).get_json()
    assert j['current_streak'] == 2


def test_streak_breaks_when_yesterday_missing(client, auth):
    add_activity(client, auth, date=TODAY - timedelta(days=2))
    j = client.get('/api/stats/streak', headers=auth).get_json()
    assert j['current_streak'] == 0 and j['longest_streak'] == 1


def test_streak_requires_auth(client):
    assert client.get('/api/stats/streak').status_code == 401


# --------------------------------------------------------------- goals

def test_goal_crud(client, auth):
    r = client.post('/api/goals', json={
        'title': 'Cycle 50 km', 'metric': 'transport',
        'target_value': 50, 'unit': 'km',
    }, headers=auth)
    assert r.status_code == 201
    gid = r.get_json()['id']

    goals = client.get('/api/goals', headers=auth).get_json()
    assert len(goals) == 1 and goals[0]['target_value'] == 50
    assert goals[0]['status'] == 'active'

    p = client.patch(f'/api/goals/{gid}',
                     json={'current_value': 20, 'status': 'completed'},
                     headers=auth)
    assert p.status_code == 200
    j = p.get_json()
    assert j['current_value'] == 20 and j['status'] == 'completed'

    bad = client.patch(f'/api/goals/{gid}', json={'status': 'weird'}, headers=auth)
    assert bad.status_code == 400
    bad2 = client.patch(f'/api/goals/{gid}', json={'current_value': -1}, headers=auth)
    assert bad2.status_code == 400

    assert client.delete(f'/api/goals/{gid}', headers=auth).status_code == 200
    assert client.get('/api/goals', headers=auth).get_json() == []
    assert client.delete(f'/api/goals/{gid}', headers=auth).status_code == 404


def test_goal_create_validation(client, auth):
    assert client.post('/api/goals', json={'title': '   '}, headers=auth).status_code == 400
    assert client.post('/api/goals', json={'title': 'x', 'target_value': 0},
                       headers=auth).status_code == 400
    assert client.post('/api/goals', headers=auth).status_code == 400


def test_goals_are_per_user(client, auth, other_auth):
    gid = client.post('/api/goals', json={'title': 'x', 'target_value': 1},
                      headers=auth).get_json()['id']
    assert client.patch(f'/api/goals/{gid}', json={'current_value': 5},
                        headers=other_auth).status_code == 404
    assert client.delete(f'/api/goals/{gid}', headers=other_auth).status_code == 404
    assert client.get('/api/goals', headers=other_auth).get_json() == []


# ------------------------------------------------------ delete account

def test_delete_account(client, auth):
    add_activity(client, auth)
    r = client.delete('/api/auth/account', headers=auth)
    assert r.status_code == 200
    assert r.get_json()['message'] == 'Account deleted'
    assert client.get('/api/auth/me', headers=auth).status_code == 404


# -------------------------------------------------------- achievements

def _ach(client, headers):
    r = client.get('/api/achievements', headers=auth)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def _earned_codes(data):
    return {a['code'] for a in data['achievements'] if a['earned']}


def test_achievements_require_auth(client):
    assert client.get('/api/achievements').status_code == 401
    assert client.get('/api/achievements/me').status_code == 401


def test_achievements_start_empty(client, auth):
    j = client.get('/api/achievements', headers=auth).get_json()
    assert j['streak'] == {'current': 0, 'longest': 0}
    assert all(not a['earned'] for a in j['achievements'])
    # every definition exposes a target and a progress value
    assert all(a['target'] >= 1 and a['progress'] == 0 for a in j['achievements'])


def test_first_activity_unlocks_on_create(client, auth):
    assert not _earned(client, auth, 'first_activity')
    add_activity(client, auth)
    assert _earned(client, auth, 'first_activity')


def test_editing_activity_does_not_duplicate_achievements(client, auth):
    a = add_activity(client, auth)
    codes = unlocked_codes(client, auth)
    assert codes.count('first_activity') == 1
    # edit the same activity several times
    for q in (5, 10, 15):
        r = client.patch(f"/api/activities/{a['id']}", json={'quantity': q}, headers=auth)
        assert r.status_code == 200
    codes = unlocked_codes(client, auth)
    assert codes.count('first_activity') == 1


def test_logged_days_achievement(client, auth):
    add_activity(client, auth, date=TODAY)
    assert not _earned(client, auth, 'first_week')
    add_activity(client, auth, date=TODAY - timedelta(days=1))
    assert _earned(client, auth, 'first_week')


def test_goal_setter_and_completion(client, auth):
    assert not _earned(client, auth, 'goal_setter')
    r = client.post('/api/goals', json={'title': 'Cycle more', 'target_value': 50,
                                        'metric': 'transport', 'unit': 'km'}, headers=auth)
    gid = r.get_json()['id']
    assert _earned(client, auth, 'goal_setter')
    assert not _earned(client, auth, 'goal_first')
    client.patch(f'/api/goals/{gid}', json={'status': 'completed'}, headers=auth)
    assert _earned(client, auth, 'goal_first')


def test_streak_achievement_unlocks(client, auth):
    for i in range(3):
        add_activity(client, auth, date=TODAY - timedelta(days=i))
    assert _earned(client, auth, 'streak_3')
    assert not _earned(client, auth, 'streak_7')


def test_categories_achievement(client, auth):
    add_activity(client, auth, category='transport', type_='bus')
    add_activity(client, auth, category='electricity', type_='grid')
    add_activity(client, auth, category='water', type_='tap')
    assert not _earned(client, auth, 'analytics_explorer')
    add_activity(client, auth, category='waste', type_='recycling')
    assert _earned(client, auth, 'analytics_explorer')


def test_achievements_persist_and_are_per_user(client, auth, other_auth):
    add_activity(client, auth)
    assert _earned(client, auth, 'first_activity')
    # a different user starts fresh
    assert not _earned(client, other_auth, 'first_activity')
    # and the first user still has it
    assert _earned(client, auth, 'first_activity')


def test_deleting_activity_keeps_achievement_but_recomputes_streak(client, auth):
    for i in range(3):
        add_activity(client, auth, date=TODAY - timedelta(days=i))
    assert _earned(client, auth, 'streak_3')
    # remove today's entry: streak drops to 2, but the earned badge stays
    acts = client.get('/api/activities', headers=auth).get_json()['activities']
    today_act = next(a for a in acts if a['date'] == TODAY.isoformat())
    client.delete(f"/api/activities/{today_act['id']}", headers=auth)
    streak = client.get('/api/stats/streak', headers=auth).get_json()
    assert streak['current_streak'] == 2
    assert _earned(client, auth, 'streak_3')


def _earned(client, auth, code):
    data = client.get('/api/achievements', headers=auth).get_json()
    return next(a['earned'] for a in data['achievements'] if a['code'] == code)


def unlocked_codes(client, auth):
    data = client.get('/api/achievements', headers=auth).get_json()
    return [a['code'] for a in data['achievements'] if a['earned']]


# ---------------------------------------------------------------- challenges


def _challenges(client, auth):
    r = client.get('/api/challenges', headers=auth)
    assert r.status_code == 200
    return r.get_json()


def _challenge(client, auth, code):
    return next(c for c in _challenges(client, auth)['challenges'] if c['code'] == code)


def test_period_window_is_stable():
    from app.challenge_engine import period_window
    from datetime import date as _date
    d = _date(2026, 10, 14)  # a Wednesday
    s, e, key = period_window('daily', d)
    assert (s, e, key) == (d, d, '2026-10-14')
    s, e, key = period_window('weekly', d)
    assert s == _date(2026, 10, 12) and e == _date(2026, 10, 18)  # Mon..Sun
    assert key == '2026-W42'


def test_challenges_list_shape(client, auth):
    data = _challenges(client, auth)
    assert isinstance(data['points'], int)
    assert data['points'] == 0
    codes = {c['code'] for c in data['challenges']}
    assert {'daily_log', 'weekly_categories', 'weekly_transport'} <= codes
    sample = _challenge(client, auth, 'daily_log')
    for field in ('title', 'description', 'period', 'metric', 'target',
                  'reward_points', 'progress', 'completed', 'period_key'):
        assert field in sample
    assert sample['completed'] is False


def test_daily_log_challenge_completes_and_rewards(client, auth):
    add_activity(client, auth)
    c = _challenge(client, auth, 'daily_log')
    assert c['completed'] is True
    assert _challenges(client, auth)['points'] == c['reward_points']


def test_challenge_points_are_idempotent(client, auth):
    add_activity(client, auth)
    first = _challenges(client, auth)['points']
    # repeated reads and more activity must not double-credit daily_log
    add_activity(client, auth, category='electricity', type_='grid', quantity=5)
    add_activity(client, auth, category='water', type_='tap', quantity=20)
    data = _challenges(client, auth)
    assert data['points'] == sum(
        c['reward_points'] for c in data['challenges'] if c['completed']
    )
    assert data['points'] >= first


def test_daily_energy_challenge_is_category_scoped(client, auth):
    add_activity(client, auth, category='transport', type_='bus')
    assert _challenge(client, auth, 'daily_energy')['progress'] == 0
    add_activity(client, auth, category='electricity', type_='grid', quantity=5)
    assert _challenge(client, auth, 'daily_energy')['completed'] is True


def test_weekly_days_counts_distinct_days(client, auth):
    monday = TODAY - timedelta(days=TODAY.weekday())
    days = [monday + timedelta(days=i) for i in range(TODAY.weekday() + 1)]
    for d in days:
        add_activity(client, auth, date=d)
    assert _challenge(client, auth, 'weekly_days')['progress'] == min(len(days), 5)


def test_weekly_categories_completes_with_four(client, auth):
    add_activity(client, auth, category='transport', type_='bus')
    add_activity(client, auth, category='electricity', type_='grid', quantity=5)
    add_activity(client, auth, category='water', type_='tap', quantity=10)
    assert _challenge(client, auth, 'weekly_categories')['progress'] == 3
    assert _challenge(client, auth, 'weekly_categories')['completed'] is False
    add_activity(client, auth, category='waste', type_='recycling', quantity=2)
    assert _challenge(client, auth, 'weekly_categories')['completed'] is True


def test_weekly_transport_is_category_scoped(client, auth):
    add_activity(client, auth, category='water', type_='tap')
    assert _challenge(client, auth, 'weekly_transport')['progress'] == 0
    for _ in range(3):
        add_activity(client, auth, category='transport', type_='bus')
    assert _challenge(client, auth, 'weekly_transport')['completed'] is True


def test_challenges_are_per_user(client, auth, other_auth):
    add_activity(client, auth)
    assert _challenge(client, auth, 'daily_log')['completed'] is True
    assert _challenge(client, other_auth, 'daily_log')['completed'] is False
    assert _challenges(client, other_auth)['points'] == 0


# ---------------------------------------------------------------- calendar


def _calendar(client, auth, month=None):
    q = {'month': month} if month else {}
    r = client.get('/api/stats/calendar', headers=auth, query_string=q)
    assert r.status_code == 200, r.get_json()
    return r.get_json()


def test_calendar_default_month_shape(client, auth):
    data = _calendar(client, auth)
    assert data['month'] == TODAY.strftime('%Y-%m')
    assert data['start'].endswith('-01')
    first = data['days'][0]
    for field in ('date', 'co2_kg', 'entries', 'categories', 'level'):
        assert field in first
    assert first['entries'] == 0 and first['level'] == 0


def test_calendar_month_length(client, auth):
    assert len(_calendar(client, auth, '2026-02')['days']) == 28
    assert len(_calendar(client, auth, '2024-02')['days']) == 29  # leap year
    assert len(_calendar(client, auth, '2026-12')['days']) == 31


def test_calendar_rejects_bad_month(client, auth):
    for bad in ('2026-13', 'nope', '2026'):
        r = client.get('/api/stats/calendar', headers=auth, query_string={'month': bad})
        assert r.status_code == 400


def test_calendar_marks_logged_day(client, auth):
    add_activity(client, auth, category='transport', type_='bus', date=TODAY)
    days = _calendar(client, auth)['days']
    today = next(d for d in days if d['date'] == TODAY.isoformat())
    assert today['entries'] == 1
    assert today['co2_kg'] > 0
    assert today['categories'] == ['transport']
    assert today['level'] >= 1


def test_calendar_is_per_user(client, auth, other_auth):
    add_activity(client, auth, date=TODAY)
    other = _calendar(client, other_auth)['days']
    today = next(d for d in other if d['date'] == TODAY.isoformat())
    assert today['entries'] == 0


# ---------------------------------------------------------------- compare + explain


def test_score_includes_explanation(client, auth):
    add_activity(client, auth, category='transport', type_='car_petrol', quantity=20)
    data = client.get('/api/stats/score?period=week', headers=auth).get_json()
    exp = data['explanation']
    assert exp['available'] is True
    assert isinstance(exp['steps'], list) and len(exp['steps']) >= 3
    assert exp['thresholds']['good_daily_co2_kg'] == 3.0
    assert exp['top_category']['category'] == 'transport'
    assert exp['top_category']['share'] > 0


def test_score_explanation_unavailable_without_data(client, auth):
    exp = client.get('/api/stats/score?period=week', headers=auth).get_json()['explanation']
    assert exp['available'] is False
    assert 'text' in exp


def test_compare_shape_and_zero_baseline(client, auth):
    data = client.get('/api/stats/compare?period=week', headers=auth).get_json()
    assert set(data) >= {'period', 'current', 'previous', 'total_delta_kg', 'by_category'}
    assert data['total_delta_kg'] == 0
    assert data['total_change_pct'] is None
    assert set(data['by_category']) == {'transport', 'electricity', 'water', 'waste'}


def test_compare_rejects_bad_period(client, auth):
    r = client.get('/api/stats/compare?period=year', headers=auth)
    assert r.status_code == 400


def test_compare_detects_reduction(client, auth):
    add_activity(client, auth, category='transport', type_='car_petrol',
                 quantity=200, date=TODAY - timedelta(days=7))
    add_activity(client, auth, category='transport', type_='bus',
                 quantity=1, date=TODAY)
    data = client.get('/api/stats/compare?period=week', headers=auth).get_json()
    assert data['previous']['total_co2_kg'] > data['current']['total_co2_kg']
    assert data['total_delta_kg'] < 0
    assert data['total_change_pct'] < 0
    assert data['by_category']['transport']['delta'] < 0


def test_compare_is_per_user(client, auth, other_auth):
    add_activity(client, auth, quantity=100, date=TODAY)
    mine = client.get('/api/stats/compare?period=week', headers=auth).get_json()
    theirs = client.get('/api/stats/compare?period=week', headers=other_auth).get_json()
    assert mine['current']['total_co2_kg'] > 0
    assert theirs['current']['total_co2_kg'] == 0


# ---------------------------------------------------------------- grove


def test_grove_requires_auth(client):
    assert client.get('/api/stats/grove').status_code == 401


def test_grove_empty(client, auth):
    r = client.get('/api/stats/grove', headers=auth).get_json()
    assert r['trees'] == 0
    assert r['activities'] == 0
    assert r['goals_completed'] == 0


def test_grove_grows_with_data(client, auth):
    add_activity(client, auth, date=TODAY)
    add_activity(client, auth, date=TODAY - timedelta(days=1))
    r = client.post('/api/goals', json={'title': 'Cycle more', 'target_value': 50,
                                        'metric': 'transport', 'unit': 'km'}, headers=auth)
    client.patch(f"/api/goals/{r.get_json()['id']}", json={'status': 'completed'}, headers=auth)
    g = client.get('/api/stats/grove', headers=auth).get_json()
    assert g['activities'] == 2
    assert g['logged_days'] == 2
    assert g['goals_completed'] == 1
    assert g['trees'] >= 2


# ---------------------------------------------------------------- reports


def test_csv_requires_auth(client):
    assert client.get('/api/reports/activities.csv').status_code == 401


def test_csv_export(client, auth):
    add_activity(client, auth, category='transport', type_='bus', quantity=10, date=TODAY)
    r = client.get('/api/reports/activities.csv?period=week', headers=auth)
    assert r.status_code == 200
    assert 'text/csv' in r.headers['Content-Type']
    body = r.get_data(as_text=True)
    lines = body.strip().splitlines()
    assert lines[0] == 'date,category,type,quantity,unit,co2_kg'
    assert any('transport' in ln for ln in lines[1:])


def test_csv_rejects_bad_period(client, auth):
    assert client.get('/api/reports/activities.csv?period=year', headers=auth).status_code == 400


def test_pdf_requires_auth(client):
    assert client.get('/api/reports/summary.pdf').status_code == 401


def test_pdf_is_valid(client, auth):
    add_activity(client, auth, category='electricity', type_='grid', quantity=30)
    r = client.get('/api/reports/summary.pdf?period=week', headers=auth)
    assert r.status_code == 200
    assert r.headers['Content-Type'] == 'application/pdf'
    data = r.get_data()
    assert data.startswith(b'%PDF-1.4')
    assert data.rstrip().endswith(b'%%EOF')
    assert b'xref' in data


def test_pdf_rejects_bad_period(client, auth):
    assert client.get('/api/reports/summary.pdf?period=year', headers=auth).status_code == 400


# ---------------------------------------------------------------- notifications


def test_notifications_requires_auth(client):
    assert client.get('/api/notifications').status_code == 401


def test_notifications_onboarding_for_new_user(client, auth):
    data = client.get('/api/notifications', headers=auth).get_json()['notifications']
    assert len(data) == 1
    assert data[0]['code'] == 'onboarding'


def test_notifications_reminder_when_streak_at_risk(client, auth):
    yesterday = TODAY - timedelta(days=1)
    add_activity(client, auth, date=yesterday)
    data = client.get('/api/notifications', headers=auth).get_json()['notifications']
    codes = [n['code'] for n in data]
    assert 'streak_at_risk' in codes


def test_notifications_positive_trend(client, auth):
    add_activity(client, auth, category='transport', type_='car_petrol',
                 quantity=200, date=TODAY - timedelta(days=8))
    add_activity(client, auth, category='transport', type_='bus', quantity=1, date=TODAY)
    data = client.get('/api/notifications', headers=auth).get_json()['notifications']
    codes = [n['code'] for n in data]
    assert 'trend_down' in codes


# ---------------------------------------------------------------- offline sync / dedupe


def test_resend_dedupes_within_window(client, auth):
    body = {'category': 'transport', 'type': 'bus', 'quantity': 10}
    first = client.post('/api/activities', json=body, headers=auth)
    assert first.status_code == 201
    second = client.post('/api/activities', json={**body, 'resend': True}, headers=auth)
    assert second.status_code == 200
    assert second.get_json()['duplicate'] is True
    listing = client.get('/api/activities', headers=auth).get_json()
    assert listing['total'] == 1


def test_normal_duplicates_still_allowed(client, auth):
    body = {'category': 'transport', 'type': 'bus', 'quantity': 10}
    assert client.post('/api/activities', json=body, headers=auth).status_code == 201
    assert client.post('/api/activities', json=body, headers=auth).status_code == 201
    assert client.get('/api/activities', headers=auth).get_json()['total'] == 2


def test_batch_creates_then_dedupes(client, auth):
    payload = {
        'activities': [
            {'category': 'transport', 'type': 'bus', 'quantity': 10, 'resend': True},
            {'category': 'electricity', 'type': 'grid', 'quantity': 30, 'resend': True},
        ]
    }
    first = client.post('/api/activities/batch', json=payload, headers=auth).get_json()
    assert first['created'] == 2
    again = client.post('/api/activities/batch', json=payload, headers=auth).get_json()
    assert again['created'] == 0
    assert all(r['duplicate'] for r in again['results'])
    assert client.get('/api/activities', headers=auth).get_json()['total'] == 2


def test_batch_validation(client, auth):
    assert client.post('/api/activities/batch', json={'activities': []}, headers=auth).status_code == 400
    bad = client.post('/api/activities/batch',
                      json={'activities': [{'category': 'transport', 'type': 'nope', 'quantity': 1}]},
                      headers=auth).get_json()
    assert bad['results'][0]['ok'] is False


# ---------------------------------------------------- refresh tokens / logout

WEB = {"X-Client-Platform": "web"}


def test_register_returns_refresh_token(client):
    data = register(client).get_json()
    assert data["access_token"]
    assert data["refresh_token"]


def test_web_client_gets_cookie_not_body_refresh(client):
    client.post("/api/auth/register",
                json={"name": "Web", "email": "web@b.com", "password": "secret123",
                      "terms_accepted": True})
    r = client.post("/api/auth/login",
                    json={"email": "web@b.com", "password": "secret123"}, headers=WEB)
    assert r.status_code == 200
    data = r.get_json()
    assert data["access_token"]
    assert "refresh_token" not in data
    assert "refresh_token_cookie" in r.headers.get("Set-Cookie", "")


def test_refresh_issues_usable_access_token(client):
    refresh = register(client).get_json()["refresh_token"]
    r = client.post("/api/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 200
    new_access = r.get_json()["access_token"]
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {new_access}"}).status_code == 200


def test_refresh_rotates_and_revokes_old_token(client):
    refresh = register(client).get_json()["refresh_token"]
    assert client.post("/api/auth/refresh",
                       json={"refresh_token": refresh}).status_code == 200
    replay = client.post("/api/auth/refresh",
                         json={"refresh_token": refresh})
    assert replay.status_code == 401


def test_logout_revokes_refresh_token(client):
    refresh = register(client).get_json()["refresh_token"]
    assert client.post("/api/auth/logout",
                       json={"refresh_token": refresh}).status_code == 200
    assert client.post("/api/auth/refresh",
                       json={"refresh_token": refresh}).status_code == 401


def test_access_token_rejected_at_refresh(client):
    access = register(client).get_json()["access_token"]
    r = client.post("/api/auth/refresh", headers={"Authorization": f"Bearer {access}"})
    assert r.status_code == 401


def test_refresh_token_in_authorization_header_is_rejected(client):
    """The refresh token is not a header location.

    No client sends it that way, so accepting it in a header would only widen
    the set of channels a leaked token can be replayed from.
    """
    refresh = register(client).get_json()["refresh_token"]
    r = client.post("/api/auth/refresh",
                    headers={"Authorization": f"Bearer {refresh}"})
    assert r.status_code == 401


def test_access_token_is_accepted_from_the_header_only(client):
    """An access token must not work from a cookie or from the JSON body."""
    access = register(client).get_json()["access_token"]

    as_cookie = client.get(
        "/api/auth/me",
        headers={"Cookie": f"access_token_cookie={access}"},
    )
    assert as_cookie.status_code == 401

    as_body = client.get(
        "/api/auth/me",
        json={"access_token": access},
    )
    assert as_body.status_code == 401

    as_header = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {access}"},
    )
    assert as_header.status_code == 200


def test_refresh_requires_a_token(client):
    assert client.post("/api/auth/refresh").status_code == 401


def test_web_refresh_uses_cookie(client):
    register(client, email="cookie@b.com", password="secret123")
    login = client.post("/api/auth/login",
                        json={"email": "cookie@b.com", "password": "secret123"}, headers=WEB)
    assert login.status_code == 200
    assert "refresh_token_cookie" in login.headers.get("Set-Cookie", "")
    r = client.post("/api/auth/refresh", headers=WEB)
    assert r.status_code == 200
    assert r.get_json()["access_token"]
