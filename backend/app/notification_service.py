"""Deterministic notification engine with persistence, read state and prefs.

Everything here is rule-based and derived from the user's own rows. Generation
happens when the notifications endpoint is read, so it works with no background
worker or push provider. Each event carries a ``dedupe_key``; the unique
constraint on (user_id, dedupe_key) keeps repeated polling idempotent.
"""
from datetime import date, datetime, timedelta, timezone
import logging

from sqlalchemy import func

from . import challenge_engine as ce
from . import engagement
from .extensions import db
from .models import (
    Achievement,
    Activity,
    Challenge,
    ChallengePeriod,
    Notification,
    NotificationPreference,
    UserAchievement,
)
from .stats import PERIOD_DAYS, _collect

log = logging.getLogger(__name__)

_TRANSIENT_CODES = ("streak_at_risk", "log_today", "daily_reminder")


def get_preferences(uid):
    prefs = NotificationPreference.query.filter_by(user_id=uid).first()
    if prefs is None:
        prefs = NotificationPreference(user_id=uid)
        db.session.add(prefs)
        db.session.commit()
    return prefs


def update_preferences(uid, data):
    prefs = get_preferences(uid)
    bool_fields = (
        "daily_reminder",
        "streak_reminders",
        "challenge_nudges",
        "trend_alerts",
        "achievement_alerts",
        "weekly_summary",
    )
    for field in bool_fields:
        if field in data:
            value = data[field]
            if not isinstance(value, bool):
                raise ValueError(f"{field} must be a boolean")
            setattr(prefs, field, value)
    if "reminder_hour" in data:
        try:
            hour = int(data["reminder_hour"])
        except (TypeError, ValueError):
            raise ValueError("reminder_hour must be an integer")
        if not 0 <= hour <= 23:
            raise ValueError("reminder_hour must be between 0 and 23")
        prefs.reminder_hour = hour
    db.session.commit()
    return prefs


def serialize(notification):
    return {
        "id": notification.id,
        "code": notification.code,
        "type": notification.type,
        "severity": notification.severity,
        "title": notification.title,
        "body": notification.body,
        "read": notification.read_at is not None,
        "created_at": notification.created_at.isoformat()
        if notification.created_at
        else None,
        "read_at": notification.read_at.isoformat()
        if notification.read_at
        else None,
    }


def _add(uid, *, code, type_, severity, title, body, dedupe_key):
    exists = Notification.query.filter_by(
        user_id=uid, dedupe_key=dedupe_key
    ).first()
    if exists is not None:
        return False
    db.session.add(
        Notification(
            user_id=uid,
            code=code,
            type=type_,
            severity=severity,
            title=title,
            body=body,
            dedupe_key=dedupe_key,
        )
    )
    return True


def _resolve_stale(uid, has_activities, logged_today):
    """Remove nudges that no longer apply (they would be misleading)."""
    if has_activities:
        Notification.query.filter_by(user_id=uid, code="onboarding").delete(
            synchronize_session=False
        )
    if logged_today:
        Notification.query.filter(
            Notification.user_id == uid,
            Notification.code.in_(_TRANSIENT_CODES),
        ).delete(synchronize_session=False)


def _trend(uid, today):
    span = PERIOD_DAYS["week"]
    cur_end = today
    cur_start = cur_end - timedelta(days=span - 1)
    prev_end = cur_start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)
    _, _, cur_total, cur_active = _collect(uid, cur_start, cur_end)
    _, _, prev_total, _ = _collect(uid, prev_start, prev_end)
    return cur_start, cur_total, cur_active, prev_total


def _weekly_summary(uid, today):
    span = PERIOD_DAYS["week"]
    cur_start = today - timedelta(days=span - 1)
    prev_end = cur_start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)
    _, _, total, active_days = _collect(uid, prev_start, prev_end)
    iso = today.isocalendar()
    key = f"weekly_summary:{iso[0]}-W{iso[1]:02d}"
    _add(
        uid,
        code="weekly_summary",
        type_="summary",
        severity="info",
        title="Your week in review",
        body=(
            f"Last week you logged {active_days} active "
            f"{'day' if active_days == 1 else 'days'} with "
            f"{round(total, 1)} kg CO2. Open Analytics for the full breakdown."
        ),
        dedupe_key=key,
    )


def _achievement_alerts(uid, today):
    cutoff = today - timedelta(days=30)
    rows = (
        db.session.query(UserAchievement, Achievement)
        .join(Achievement, Achievement.id == UserAchievement.achievement_id)
        .filter(UserAchievement.user_id == uid)
        .order_by(UserAchievement.unlocked_at.desc())
        .limit(20)
        .all()
    )
    for unlocked, achievement in rows:
        unlocked_on = unlocked.unlocked_at.date() if unlocked.unlocked_at else today
        if unlocked_on < cutoff:
            continue
        _add(
            uid,
            code=f"achievement_{achievement.code}",
            type_="achievement",
            severity="success",
            title=f"Badge unlocked: {achievement.name}",
            body=achievement.description or "A new achievement is yours.",
            dedupe_key=f"achievement:{achievement.code}",
        )


def _challenge_completions(uid, today):
    cutoff = today - timedelta(days=30)
    rows = (
        db.session.query(ChallengePeriod, Challenge)
        .join(Challenge, Challenge.id == ChallengePeriod.challenge_id)
        .filter(
            ChallengePeriod.user_id == uid,
            ChallengePeriod.completed.is_(True),
        )
        .order_by(ChallengePeriod.completed_at.desc())
        .limit(10)
        .all()
    )
    for period, challenge in rows:
        completed_on = (
            period.completed_at.date() if period.completed_at else today
        )
        if completed_on < cutoff:
            continue
        _add(
            uid,
            code=f"challenge_done_{challenge.code}",
            type_="challenge",
            severity="success",
            title=f"Challenge complete: {challenge.title}",
            body=f"You earned {challenge.reward_points} Eco Points.",
            dedupe_key=f"challenge_done:{challenge.code}:{period.period_key}",
        )


def materialize(uid):
    """Create any notifications that currently apply, then return all of them.

    Kept for callers that legitimately generate (login, activity writes, the
    scheduler). The read endpoint uses ``list_for_user`` instead so a GET never
    mutates state.
    """
    _generate(uid)
    return _list(uid)


def generate_for_user(uid):
    """Generate any notifications that currently apply (used on login and after
    a mutation). Never raises: notification generation must not break the
    request that triggered it."""
    try:
        _generate(uid)
    except Exception:
        db.session.rollback()
        log.exception("notification generation failed for user %s", uid)


def list_for_user(uid):
    """Read-only listing: no generation, no writes."""
    return _list(uid)


def _generate(uid):
    prefs = get_preferences(uid)
    today = date.today()
    now = datetime.now()

    metrics = engagement.metrics(uid)
    logged_today = (
        db.session.query(func.count(Activity.id))
        .filter(Activity.user_id == uid, Activity.date == today)
        .scalar()
        or 0
    )
    _resolve_stale(uid, metrics["activities"] > 0, logged_today > 0)

    if metrics["activities"] == 0:
        _add(
            uid,
            code="onboarding",
            type_="onboarding",
            severity="info",
            title="Welcome to EcoTrack",
            body="Log your first activity to start tracking your footprint.",
            dedupe_key="onboarding",
        )
        db.session.commit()
        return

    if not logged_today:
        if prefs.streak_reminders:
            if metrics["streak"] > 0:
                _add(
                    uid,
                    code="streak_at_risk",
                    type_="reminder",
                    severity="warning",
                    title="Your streak is at risk",
                    body=(
                        f"Log an activity today to keep your "
                        f"{metrics['streak']}-day streak alive."
                    ),
                    dedupe_key=f"streak_at_risk:{today.isoformat()}",
                )
            else:
                _add(
                    uid,
                    code="log_today",
                    type_="reminder",
                    severity="info",
                    title="Don't forget to log today",
                    body="A quick entry keeps your progress accurate.",
                    dedupe_key=f"log_today:{today.isoformat()}",
                )
        if prefs.daily_reminder and now.hour >= (prefs.reminder_hour or 0):
            _add(
                uid,
                code="daily_reminder",
                type_="reminder",
                severity="info",
                title="Daily check-in",
                body="Take a minute to log today's travel, energy, water and waste.",
                dedupe_key=f"daily_reminder:{today.isoformat()}",
            )

    if prefs.weekly_summary and today.weekday() == 0:
        _weekly_summary(uid, today)

    if prefs.challenge_nudges:
        for challenge in ce.summary(uid):
            if challenge["completed"]:
                continue
            if challenge["target"] - challenge["progress"] == 1:
                _add(
                    uid,
                    code=f"challenge_{challenge['code']}",
                    type_="challenge",
                    severity="info",
                    title="Almost there!",
                    body=(
                        f"{challenge['title']}: just 1 more to earn "
                        f"{challenge['reward_points']} points."
                    ),
                    dedupe_key=(
                        f"challenge_nearly:{challenge['code']}:"
                        f"{challenge['period_key']}"
                    ),
                )

    if prefs.trend_alerts:
        cur_start, cur_total, cur_active, prev_total = _trend(uid, today)
        if prev_total > 0 and cur_active > 0:
            change = (cur_total - prev_total) / prev_total * 100
            if change <= -3:
                _add(
                    uid,
                    code="trend_down",
                    type_="insight",
                    severity="success",
                    title="Nice trend",
                    body=(
                        f"Your CO2 is down {abs(round(change))}% vs the "
                        "previous week. Keep it up!"
                    ),
                    dedupe_key=f"trend_down:{cur_start.isoformat()}",
                )
            elif change >= 10:
                _add(
                    uid,
                    code="trend_up",
                    type_="insight",
                    severity="warning",
                    title="Footprint creeping up",
                    body=(
                        f"Your CO2 is up {round(change)}% vs the previous week. "
                        "Check Analytics to see which category changed."
                    ),
                    dedupe_key=f"trend_up:{cur_start.isoformat()}",
                )

    if prefs.achievement_alerts:
        _achievement_alerts(uid, today)
    if prefs.challenge_nudges:
        _challenge_completions(uid, today)

    db.session.commit()


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def materialize_all(limit=None):
    """Run ``materialize`` for every user (used by the hourly scheduler).

    Commits are per-user, so one user's failure never blocks the rest.
    Returns the number of users processed successfully.
    """
    from .models import User

    query = User.query.with_entities(User.id).order_by(User.id)
    if limit:
        query = query.limit(limit)
    user_ids = [row[0] for row in query.all()]

    processed = 0
    for uid in user_ids:
        try:
            materialize(uid)
            processed += 1
        except Exception:
            db.session.rollback()
            log.exception("materialize failed for user %s", uid)
    return processed


def _list(uid):
    return (
        Notification.query.filter_by(user_id=uid, dismissed_at=None)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .limit(100)
        .all()
    )


def unread_count(uid):
    return Notification.query.filter_by(
        user_id=uid, read_at=None, dismissed_at=None
    ).count()


def mark_read(uid, notification_id):
    row = Notification.query.filter_by(id=notification_id, user_id=uid).first()
    if row is None:
        return None
    if row.read_at is None:
        row.read_at = _utcnow()
        db.session.commit()
    return row


def mark_all_read(uid):
    count = Notification.query.filter_by(
        user_id=uid, read_at=None, dismissed_at=None
    ).update(
        {"read_at": _utcnow()},
        synchronize_session=False,
    )
    db.session.commit()
    return count


def delete(uid, notification_id):
    """Soft-dismiss so the generator does not recreate the same event."""
    row = Notification.query.filter_by(
        id=notification_id, user_id=uid, dismissed_at=None
    ).first()
    if row is None:
        return False
    row.dismissed_at = _utcnow()
    db.session.commit()
    return True
