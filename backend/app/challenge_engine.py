"""Daily / weekly challenge engine.

Design notes
------------
* **Definitions live in code** (``CHALLENGES``) — explicit, unit-testable, and
  seeded idempotently into the ``challenges`` table for referential integrity.
* **Windows use server-local calendar dates** (same policy as streaks). Daily
  challenges reset at local midnight; weekly challenges use ISO weeks
  (Monday..Sunday). Progress is always derived from ``Activity`` rows inside the
  window, so it can never drift from the underlying data.
* **Idempotent completion:** ``ChallengePeriod`` (a dedicated table keyed by
  user + challenge + period key) records completion and unlocks the points
  exactly once, even if a request is retried.
"""
from datetime import date, timedelta

from sqlalchemy import func

from .extensions import db
from .models import (
    Activity,
    Challenge,
    ChallengePeriod,
    PointsLedger,
    UserPoints,
    _utcnow,
)

CHALLENGES = [
    {
        "code": "daily_log",
        "title": "Log an activity",
        "description": "Record at least one activity today.",
        "period": "daily",
        "metric": "logs",
        "target": 1,
        "reward_points": 10,
    },
    {
        "code": "daily_three",
        "title": "Triple impact",
        "description": "Record three activities today.",
        "period": "daily",
        "metric": "logs",
        "target": 3,
        "reward_points": 20,
    },
    {
        "code": "daily_energy",
        "title": "Energy check",
        "description": "Log an electricity activity today.",
        "period": "daily",
        "metric": "logs",
        "target": 1,
        "category": "electricity",
        "reward_points": 10,
    },
    {
        "code": "daily_energy_three",
        "title": "Energy saver",
        "description": "Log three electricity activities today.",
        "period": "daily",
        "metric": "logs",
        "target": 3,
        "category": "electricity",
        "reward_points": 20,
    },
    {
        "code": "weekly_days",
        "title": "Consistent week",
        "description": "Log activities on five days this week.",
        "period": "weekly",
        "metric": "days",
        "target": 5,
        "reward_points": 40,
    },
    {
        "code": "weekly_categories",
        "title": "All-rounder",
        "description": "Log activities in all four categories this week.",
        "period": "weekly",
        "metric": "categories",
        "target": 4,
        "reward_points": 50,
    },
    {
        "code": "weekly_transport",
        "title": "Green commuter",
        "description": "Log three transport activities this week.",
        "period": "weekly",
        "metric": "logs",
        "target": 3,
        "category": "transport",
        "reward_points": 30,
    },
]

_SPEC_BY_CODE = {spec["code"]: spec for spec in CHALLENGES}


def period_window(period, today=None):
    """Return ``(start, end, period_key)`` for the current window of ``period``."""
    today = today or date.today()
    if period == "daily":
        return today, today, today.isoformat()
    start = today - timedelta(days=today.weekday())  # Monday
    end = start + timedelta(days=6)  # Sunday
    iso = today.isocalendar()
    return start, end, f"{iso[0]}-W{iso[1]:02d}"


def progress_for_all(uid, today=None):
    """Progress for every code-defined challenge in a fixed number of queries.

    Returns ``{code: progress}``. Instead of one activity aggregate per
    challenge (13 round-trips), this computes the daily and weekly windows with
    three grouped queries total:

    * daily window, grouped by category -> powers all ``logs`` daily challenges
    * weekly window, distinct date + category -> ``days`` / ``categories``
    * weekly transport log count -> the single weekly ``logs`` challenge

    Every value is derived directly from the same ``Activity`` rows the old
    per-challenge lookup used, so a batched value always equals it.
    """
    today = today or date.today()
    progress = {spec["code"]: 0 for spec in CHALLENGES}

    # --- Daily window: one grouped query gives every daily count. ---
    day_start, day_end, _ = period_window("daily", today)
    daily_rows = (
        db.session.query(Activity.category, func.count(Activity.id))
        .filter(
            Activity.user_id == uid,
            Activity.date >= day_start,
            Activity.date <= day_end,
        )
        .group_by(Activity.category)
        .all()
    )
    per_category = {category: count for category, count in daily_rows}
    daily_total = sum(per_category.values())

    # --- Weekly window: distinct days, distinct categories, transport count. ---
    week_start, week_end, _ = period_window("weekly", today)
    week_base = (
        Activity.user_id == uid,
        Activity.date >= week_start,
        Activity.date <= week_end,
    )
    distinct_days, distinct_categories = (
        db.session.query(
            func.count(func.distinct(Activity.date)),
            func.count(func.distinct(Activity.category)),
        )
        .filter(*week_base)
        .one()
    )
    weekly_transport = (
        Activity.query.filter(*week_base, Activity.category == "transport").count()
    )

    for spec in CHALLENGES:
        metric = spec["metric"]
        category = spec.get("category")
        if metric == "logs":
            if spec["period"] == "daily":
                progress[spec["code"]] = (
                    per_category.get(category, 0) if category else daily_total
                )
            elif category:
                progress[spec["code"]] = weekly_transport
            else:
                # A weekly, uncategorized log-count challenge would need its own
                # count; none is defined today, so leave it at 0 rather than
                # issuing a query per spec.
                progress[spec["code"]] = 0
        elif metric == "days":
            progress[spec["code"]] = distinct_days or 0
        elif metric == "categories":
            progress[spec["code"]] = distinct_categories or 0

    return progress


def ensure_definitions():
    """Insert/refresh code-defined challenges in the table (idempotent)."""
    existing = {c.code: c for c in Challenge.query.all()}
    changed = False
    for spec in CHALLENGES:
        row = existing.get(spec["code"])
        if row is None:
            db.session.add(Challenge(
                code=spec["code"],
                title=spec["title"],
                description=spec["description"],
                reward_points=spec["reward_points"],
            ))
            changed = True
        elif (row.title, row.description, row.reward_points) != (
            spec["title"],
            spec["description"],
            spec["reward_points"],
        ):
            row.title = spec["title"]
            row.description = spec["description"]
            row.reward_points = spec["reward_points"]
            changed = True
    if changed:
        db.session.commit()


def _credit(uid, points, code, period_key):
    account = UserPoints.query.filter_by(user_id=uid).first()
    if account is None:
        account = UserPoints(user_id=uid, total_points=0)
        db.session.add(account)
    account.total_points = (account.total_points or 0) + points
    db.session.add(PointsLedger(
        user_id=uid, points=points, reason=f"challenge:{code}:{period_key}"
    ))


def evaluate_challenges(uid):
    """Award points for any challenge whose target is met this period.

    Idempotent: each (user, challenge, period) is credited exactly once.
    Returns the list of challenge codes credited by this call.
    """
    ensure_definitions()
    specs = {c.code: c for c in Challenge.query.all()}
    progress = progress_for_all(uid)
    awarded = []

    # Preload this user's current-period completion rows in one query.
    keys = {}
    for spec in CHALLENGES:
        row = specs.get(spec["code"])
        if row is not None:
            _, _, key = period_window(spec["period"])
            keys[row.id] = key
    periods = {}
    if keys:
        for row in ChallengePeriod.query.filter(
            ChallengePeriod.user_id == uid,
            ChallengePeriod.challenge_id.in_(list(keys)),
        ).all():
            if row.period_key == keys.get(row.challenge_id):
                periods[row.challenge_id] = row

    for spec in CHALLENGES:
        row = specs.get(spec["code"])
        if row is None:
            continue
        _, _, key = period_window(spec["period"])
        if progress.get(spec["code"], 0) < spec["target"]:
            continue

        period = periods.get(row.id)
        if period is not None and period.completed:
            continue

        if period is None:
            period = ChallengePeriod(
                user_id=uid, challenge_id=row.id, period_key=key
            )
            db.session.add(period)
        period.completed = True
        period.completed_at = _utcnow()
        _credit(uid, row.reward_points, row.code, key)
        awarded.append(row.code)

    if awarded:
        db.session.commit()
        # Challenge completions can unlock challenge badges / points badges.
        from .engagement import evaluate
        evaluate(uid)
    return awarded


def summary(uid):
    """Per-challenge view for the current period, with live progress."""
    ensure_definitions()
    specs = {c.code: c for c in Challenge.query.all()}
    progress = progress_for_all(uid)

    # Fetch every completion row for this user's current period keys in one
    # round-trip instead of one lookup per challenge.
    keys = {}
    for spec in CHALLENGES:
        row = specs.get(spec["code"])
        if row is None:
            continue
        _, _, key = period_window(spec["period"])
        keys[row.id] = key
    completed = {}
    if keys:
        rows = ChallengePeriod.query.filter(
            ChallengePeriod.user_id == uid,
            ChallengePeriod.challenge_id.in_(list(keys)),
            ChallengePeriod.completed.is_(True),
        ).all()
        for row in rows:
            if keys.get(row.challenge_id) == row.period_key:
                completed[row.challenge_id] = True

    out = []
    for spec in CHALLENGES:
        row = specs.get(spec["code"])
        if row is None:
            continue
        start, end, key = period_window(spec["period"])
        reached = progress.get(row.code, 0)
        out.append({
            "code": row.code,
            "title": row.title,
            "description": row.description,
            "period": spec["period"],
            "metric": spec["metric"],
            "target": spec["target"],
            "reward_points": row.reward_points,
            "progress": min(reached, spec["target"]),
            "completed": bool(completed.get(row.id)),
            "period_key": key,
            "window_start": start.isoformat(),
            "window_end": end.isoformat(),
        })
    return out


def total_points(uid):
    account = UserPoints.query.filter_by(user_id=uid).first()
    return account.total_points if account else 0


def completed_count(uid):
    return ChallengePeriod.query.filter_by(user_id=uid, completed=True).count()


def history(uid, limit=20):
    """Most recently completed challenge periods for the user."""
    rows = (
        db.session.query(ChallengePeriod, Challenge)
        .join(Challenge, Challenge.id == ChallengePeriod.challenge_id)
        .filter(
            ChallengePeriod.user_id == uid,
            ChallengePeriod.completed.is_(True),
        )
        .order_by(ChallengePeriod.completed_at.desc(), ChallengePeriod.id.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "code": challenge.code,
            "title": challenge.title,
            "period_key": period.period_key,
            "reward_points": challenge.reward_points,
            "completed_at": period.completed_at.isoformat()
            if period.completed_at
            else None,
        }
        for period, challenge in rows
    ]


def points_ledger(uid, limit=50):
    rows = (
        PointsLedger.query.filter_by(user_id=uid)
        .order_by(PointsLedger.created_at.desc(), PointsLedger.id.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "points": row.points,
            "reason": row.reason,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ]
