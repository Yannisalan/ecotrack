from datetime import timedelta

from conftest import add_activity
from test_api import TODAY


def _codes(client, auth):
    data = client.get('/api/notifications', headers=auth).get_json()
    return [n['code'] for n in data['notifications']]


def _earned(client, auth, code):
    data = client.get('/api/achievements', headers=auth).get_json()
    return next(a['earned'] for a in data['achievements'] if a['code'] == code)


# --------------------------------------------------------------- insights

def test_insights_require_auth(client):
    assert client.get('/api/insights').status_code == 401


def test_insights_empty_state(client, auth):
    r = client.get('/api/insights?period=week', headers=auth)
    assert r.status_code == 200
    data = r.get_json()
    assert data['has_data'] is False
    assert data['trend'] == 'no_data'
    assert data['eco_score'] is None
    assert data['total_co2_kg'] == 0
    assert len(data['categories']) == 4
    assert data['watchouts']


def test_insights_rejects_bad_period(client, auth):
    assert client.get('/api/insights?period=year', headers=auth).status_code == 400


def test_insights_summarises_and_compares_periods(client, auth):
    add_activity(
        client, auth, category='transport', type_='car_petrol',
        quantity=200, date=TODAY - timedelta(days=8),
    )
    add_activity(
        client, auth, category='transport', type_='bus',
        quantity=1, date=TODAY,
    )
    data = client.get('/api/insights?period=week', headers=auth).get_json()

    assert data['has_data'] is True
    assert data['active_days'] == 1
    assert data['entries'] == 1
    assert data['total_co2_kg'] > 0
    assert data['previous']['total_co2_kg'] > data['total_co2_kg']
    assert data['change_pct'] < 0
    assert data['trend'] == 'improving'
    assert data['top_category']['category'] == 'transport'
    assert len(data['weekday']['by_weekday']) == 7
    assert data['weekday']['best_day'] is not None
    assert data['projection']['monthly_co2_kg'] >= 0
    assert data['projection']['annual_tonnes'] >= 0
    assert data['streak']['current'] >= 1
    assert data['highlights']
    assert data['tips']


def test_insights_are_per_user(client, auth, other_auth):
    add_activity(client, auth, date=TODAY)
    mine = client.get('/api/insights', headers=auth).get_json()
    theirs = client.get('/api/insights', headers=other_auth).get_json()
    assert mine['has_data'] is True
    assert theirs['has_data'] is False


# ------------------------------------------------------------- challenges

def test_challenge_history_and_points(client, auth):
    add_activity(client, auth, date=TODAY)

    data = client.get('/api/challenges', headers=auth).get_json()
    assert data['completed_total'] >= 1
    assert any(h['code'] == 'daily_log' for h in data['history'])
    assert data['points'] > 0

    hist = client.get('/api/challenges/history', headers=auth).get_json()
    assert hist['completed_total'] >= 1
    assert any(h['code'] == 'daily_log' for h in hist['history'])

    pts = client.get('/api/challenges/points', headers=auth).get_json()
    assert pts['points'] > 0
    assert pts['ledger']
    assert all(item['points'] > 0 for item in pts['ledger'])


def test_challenge_completion_unlocks_badge(client, auth):
    add_activity(client, auth, date=TODAY)
    assert _earned(client, auth, 'challenge_finisher')


def test_water_and_commuter_badges(client, auth):
    for _ in range(10):
        add_activity(
            client, auth, category='water', type_='tap',
            quantity=5, date=TODAY,
        )
    assert _earned(client, auth, 'water_tracker')

    for _ in range(10):
        add_activity(
            client, auth, category='transport', type_='bus',
            quantity=5, date=TODAY,
        )
    assert _earned(client, auth, 'green_commuter')


# ---------------------------------------------------------- notifications

def test_notifications_persist_and_track_read(client, auth):
    first = client.get('/api/notifications', headers=auth).get_json()
    assert first['unread'] == 1
    onboarding = next(n for n in first['notifications'] if n['code'] == 'onboarding')
    assert onboarding['read'] is False

    r = client.post(
        f"/api/notifications/{onboarding['id']}/read", headers=auth
    )
    assert r.status_code == 200
    assert r.get_json()['unread'] == 0

    again = client.get('/api/notifications', headers=auth).get_json()
    assert again['unread'] == 0
    row = next(n for n in again['notifications'] if n['id'] == onboarding['id'])
    assert row['read'] is True


def test_notifications_mark_all_read(client, auth):
    add_activity(client, auth, date=TODAY)
    feed = client.get('/api/notifications', headers=auth).get_json()
    assert feed['unread'] >= 1

    r = client.post('/api/notifications/read-all', headers=auth)
    assert r.status_code == 200
    assert r.get_json()['unread'] == 0

    assert client.get('/api/notifications', headers=auth).get_json()['unread'] == 0


def test_notifications_dismiss_stays_dismissed(client, auth):
    feed = client.get('/api/notifications', headers=auth).get_json()
    onboarding = next(n for n in feed['notifications'] if n['code'] == 'onboarding')

    r = client.delete(f"/api/notifications/{onboarding['id']}", headers=auth)
    assert r.status_code == 200

    after = client.get('/api/notifications', headers=auth).get_json()
    assert all(n['id'] != onboarding['id'] for n in after['notifications'])
    assert 'onboarding' not in [n['code'] for n in after['notifications']]


def test_notifications_are_user_scoped(client, auth, other_auth):
    feed = client.get('/api/notifications', headers=auth).get_json()
    target = feed['notifications'][0]['id']

    assert client.post(
        f'/api/notifications/{target}/read', headers=other_auth
    ).status_code == 404
    assert client.delete(
        f'/api/notifications/{target}', headers=other_auth
    ).status_code == 404


def test_notification_preferences_defaults_and_update(client, auth):
    prefs = client.get('/api/notifications/preferences', headers=auth).get_json()
    assert prefs['preferences']['daily_reminder'] is True
    assert prefs['preferences']['reminder_hour'] == 19
    assert prefs['preferences']['achievement_alerts'] is True

    r = client.put(
        '/api/notifications/preferences',
        json={'daily_reminder': False, 'reminder_hour': 7},
        headers=auth,
    )
    assert r.status_code == 200
    assert r.get_json()['preferences']['daily_reminder'] is False
    assert r.get_json()['preferences']['reminder_hour'] == 7

    bad = client.put(
        '/api/notifications/preferences',
        json={'reminder_hour': 25},
        headers=auth,
    )
    assert bad.status_code == 400


def test_disabled_alerts_suppress_generation(client, auth):
    client.put(
        '/api/notifications/preferences',
        json={
            'daily_reminder': False,
            'streak_reminders': False,
            'challenge_nudges': False,
            'trend_alerts': False,
            'achievement_alerts': False,
            'weekly_summary': False,
        },
        headers=auth,
    )
    add_activity(client, auth, date=TODAY)
    assert _codes(client, auth) == []


def test_achievement_and_challenge_notifications(client, auth):
    add_activity(client, auth, date=TODAY)
    codes = _codes(client, auth)
    assert any(c.startswith('achievement_') for c in codes)
    assert any(c.startswith('challenge_done_') for c in codes)


def test_notifications_get_is_read_only(client, auth):
    """GET must not create rows; generation happens on login/register/mutate."""
    from app.models import Notification

    with client.application.app_context():
        before = Notification.query.count()

    feed = client.get('/api/notifications', headers=auth).get_json()
    assert feed['notifications']

    with client.application.app_context():
        after = Notification.query.count()
    assert after == before


def test_notifications_generated_on_login(client):
    """Registering seeds onboarding; a fresh login regenerates reminders."""
    r = client.post('/api/auth/register', json={
        'name': 'Login User', 'email': 'login_gen@example.com',
        'password': 'Str0ng!Passw0rd', 'terms_accepted': True,
    })
    assert r.status_code == 201
    token = r.get_json()['access_token']
    headers = {'Authorization': f'Bearer {token}'}

    first = client.get('/api/notifications', headers=headers).get_json()
    assert any(n['code'] == 'onboarding' for n in first['notifications'])

    r2 = client.post('/api/auth/login', json={
        'email': 'login_gen@example.com', 'password': 'Str0ng!Passw0rd',
    })
    assert r2.status_code == 200
    again = client.get('/api/notifications', headers=headers).get_json()
    assert any(n['code'] == 'onboarding' for n in again['notifications'])
