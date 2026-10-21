"""Achievements + streak engine.

Design notes
------------
* **Rule definitions live in code** (``ACHIEVEMENTS``) so the unlock conditions
  are explicit and unit-testable. The ``achievements`` table only mirrors the
  definitions for referential integrity of ``user_achievements``; it is seeded
  idempotently by ``ensure_definitions``.
* **Timezone policy:** streaks and calendar days use the *server-local calendar
  date*. ``Activity.date`` is already a server-local ``Date`` (see
  ``activities._parse_date``), so streak math stays consistent with the data
  users can actually log. Multiple activities on one day count as one day.
* **Idempotency:** unlocks are guarded by the ``uq_user_achievement`` unique
  constraint; re-evaluation simply skips already-earned rows. Editing or
  re-logging an activity can therefore never award a duplicate.
* **Persistence:** once earned, an achievement stays earned even if data later
  changes (only streaks are recalculated).
"""
from datetime import date, timedelta

from sqlalchemy import func
from sqlalchemy.exc import IntegrityError

from .extensions import db
from .models import (
    Achievement,
    Activity,
    ChallengePeriod,
    Goal,
    UserAchievement,
    UserPoints,
    UserStreak,
)

# metric -> source of the progress number
ACHIEVEMENTS = [
    # Getting started
    {"code": "first_activity", "name": "First Step",
     "description": "Record your first sustainability activity.",
     "icon": "leaf", "category": "getting_started",
     "metric": "activities", "target": 1},
    {"code": "first_week", "name": "Getting Started",
     "description": "Log activities on two different days.",
     "icon": "calendar", "category": "getting_started",
     "metric": "logged_days", "target": 2},
    {"code": "goal_setter", "name": "Goal Setter",
     "description": "Create your first sustainability goal.",
     "icon": "target", "category": "getting_started",
     "metric": "goals_created", "target": 1},
    # Consistency
    {"code": "streak_3", "name": "Three-Day Streak",
     "description": "Log an activity 3 days in a row.",
     "icon": "flame", "category": "consistency",
     "metric": "streak", "target": 3},
    {"code": "streak_7", "name": "Seven-Day Streak",
     "description": "Log an activity 7 days in a row.",
     "icon": "flame", "category": "consistency",
     "metric": "streak", "target": 7},
    {"code": "streak_14", "name": "Fourteen-Day Streak",
     "description": "Log an activity 14 days in a row.",
     "icon": "flame", "category": "consistency",
     "metric": "streak", "target": 14},
    {"code": "streak_30", "name": "Thirty-Day Streak",
     "description": "Log an activity 30 days in a row.",
     "icon": "flame", "category": "consistency",
     "metric": "streak", "target": 30},
    # Progress
    {"code": "goal_first", "name": "First Goal Completed",
     "description": "Complete your first sustainability goal.",
     "icon": "check", "category": "progress",
     "metric": "goals_completed", "target": 1},
    {"code": "goal_five", "name": "Five Goals Completed",
     "description": "Complete five sustainability goals.",
     "icon": "trophy", "category": "progress",
     "metric": "goals_completed", "target": 5},
    {"code": "analytics_explorer", "name": "Analytics Explorer",
     "description": "Log activities in all four categories.",
     "icon": "chart", "category": "progress",
     "metric": "categories", "target": 4},
    {"code": "water_tracker", "name": "Water Tracker",
     "description": "Log 10 water activities.",
     "icon": "water_drop", "category": "progress",
     "metric": "water_logs", "target": 10},
    {"code": "green_commuter", "name": "Green Commuter",
     "description": "Log 10 transport activities.",
     "icon": "bus", "category": "progress",
     "metric": "transport_logs", "target": 10},
    {"code": "milestone_100", "name": "Sustainability Milestone",
     "description": "Record 100 sustainability activities.",
     "icon": "medal", "category": "progress",
     "metric": "activities", "target": 100},
    # Challenges
    {"code": "challenge_finisher", "name": "Challenge Finisher",
     "description": "Complete your first daily or weekly challenge.",
     "icon": "flag", "category": "challenges",
     "metric": "challenges_completed", "target": 1},
    {"code": "challenge_ten", "name": "Challenge Collector",
     "description": "Complete 10 daily or weekly challenges.",
     "icon": "military_tech", "category": "challenges",
     "metric": "challenges_completed", "target": 10},
    {"code": "eco_champion", "name": "Eco Champion",
     "description": "Earn 500 Eco Points from challenges.",
     "icon": "workspace_premium", "category": "challenges",
     "metric": "points_total", "target": 500},
]

_SPEC_BY_CODE = {spec["code"]: spec for spec in ACHIEVEMENTS}


def streak_from_days(days):
    """Given a set of ``date`` objects, return ``(current, longest)``.

    ``current`` counts back from today (or yesterday if today has no entry).
    """
    if not days:
        return 0, 0

    current = 0
    d = date.today()
    if d not in days:
        d -= timedelta(days=1)
    while d in days:
        current += 1
        d -= timedelta(days=1)

    longest = 0
    run = 0
    prev = None
    for day in sorted(days):
        run = run + 1 if prev is not None and (day - prev).days == 1 else 1
        longest = max(longest, run)
        prev = day
    return current, longest


def _logged_days(uid):
    rows = (
        db.session.query(Activity.date)
        .filter(Activity.user_id == uid)
        .distinct()
        .all()
    )
    return {row[0] for row in rows}


def recompute_streak(uid):
    """Recompute and persist ``UserStreak`` for a user; returns (current, longest)."""
    days = _logged_days(uid)
    current, longest = streak_from_days(days)
    row = UserStreak.query.filter_by(user_id=uid).first()
    if row is None:
        row = UserStreak(user_id=uid)
        db.session.add(row)
    row.current_streak = current
    row.longest_streak = longest
    row.last_qualifying_date = max(days) if days else None
    db.session.commit()
    return current, longest


def metrics(uid):
    """Live progress counters used to evaluate and display achievements."""
    logged_days = db.session.query(
        func.count(func.distinct(Activity.date))
    ).filter(Activity.user_id == uid).scalar() or 0
    activities = Activity.query.filter_by(user_id=uid).count()
    categories = db.session.query(
        func.count(func.distinct(Activity.category))
    ).filter(Activity.user_id == uid).scalar() or 0
    goals_created = Goal.query.filter_by(user_id=uid).count()
    goals_completed = Goal.query.filter_by(user_id=uid, status="completed").count()
    water_logs = Activity.query.filter_by(user_id=uid, category="water").count()
    transport_logs = Activity.query.filter_by(user_id=uid, category="transport").count()
    challenges_completed = ChallengePeriod.query.filter_by(
        user_id=uid, completed=True
    ).count()
    points = UserPoints.query.filter_by(user_id=uid).first()

    current, longest = streak_from_days(_logged_days(uid))
    return {
        "activities": activities,
        "logged_days": logged_days,
        "categories": categories,
        "goals_created": goals_created,
        "goals_completed": goals_completed,
        "water_logs": water_logs,
        "transport_logs": transport_logs,
        "challenges_completed": challenges_completed,
        "points_total": points.total_points if points else 0,
        "streak": current,
        "longest_streak": longest,
    }


def ensure_definitions():
    """Insert/refresh the code-defined achievements into the table (idempotent)."""
    existing = {a.code: a for a in Achievement.query.all()}
    changed = False
    for spec in ACHIEVEMENTS:
        row = existing.get(spec["code"])
        if row is None:
            db.session.add(Achievement(
                code=spec["code"], name=spec["name"],
                description=spec["description"], icon=spec["icon"], active=True,
            ))
            changed = True
        else:
            # keep display text in sync with the code definitions
            if (row.name, row.description, row.icon) != (
                spec["name"], spec["description"], spec["icon"]
            ):
                row.name, row.description, row.icon = (
                    spec["name"], spec["description"], spec["icon"]
                )
                changed = True
    if changed:
        db.session.commit()


def evaluate(uid):
    """Award any newly satisfied achievements. Returns the list of new codes.

    Safe to call after any activity/goal mutation; also refreshes the streak.
    """
    ensure_definitions()
    recompute_streak(uid)

    m = metrics(uid)
    specs = {a.code: a for a in Achievement.query.filter_by(active=True).all()}
    earned = {
        ua.achievement_id
        for ua in UserAchievement.query.filter_by(user_id=uid).all()
    }

    newly = []
    for spec in ACHIEVEMENTS:
        row = specs.get(spec["code"])
        if row is None or row.id in earned:
            continue
        if m.get(spec["metric"], 0) >= spec["target"]:
            db.session.add(UserAchievement(user_id=uid, achievement_id=row.id))
            newly.append(spec["code"])

    if newly:
        try:
            db.session.commit()
        except IntegrityError:
            # A concurrent request already awarded one of these; keep the rest.
            db.session.rollback()
            newly = []
    return newly


def payload(uid):
    """Full achievements view for the authenticated user (no side effects other
    than ensuring the definition rows exist)."""
    ensure_definitions()
    m = metrics(uid)
    specs = {a.code: a for a in Achievement.query.filter_by(active=True).all()}
    earned = {
        ua.achievement_id
        for ua in UserAchievement.query.filter_by(user_id=uid).all()
    }

    out = []
    for spec in ACHIEVEMENTS:
        row = specs.get(spec["code"])
        if row is None:
            continue
        current = m.get(spec["metric"], 0)
        out.append({
            "code": row.code,
            "name": row.name,
            "description": row.description,
            "icon": row.icon,
            "category": spec["category"],
            "metric": spec["metric"],
            "target": spec["target"],
            "progress": min(current, spec["target"]),
            "earned": row.id in earned,
        })

    return {
        "achievements": out,
        "streak": {"current": m["streak"], "longest": m["longest_streak"]},
        "metrics": m,
    }
