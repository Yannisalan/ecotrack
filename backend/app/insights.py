"""Smart sustainability insights.

A single deterministic, rule-based endpoint that turns the user's own logged
activities into a short narrative: score/trend, biggest category, weekday
pattern, projected footprint, and ranked highlights/watchouts. No AI model is
involved; every number comes from ``Activity`` rows.
"""
from datetime import date, timedelta

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from .engagement import _logged_days, streak_from_days
from .factors import FACTORS
from .stats import (
    PERIOD_DAYS,
    _collect,
    _eco_score,
    _explanation,
    _recommendations,
)

insights_bp = Blueprint("insights", __name__, url_prefix="/api/insights")

WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def _uid():
    return int(get_jwt_identity())


def _change_pct(current, previous):
    if previous <= 0:
        return None
    return round((current - previous) / previous * 100, 1)


def _trend(current, previous, active_days):
    if active_days == 0:
        return "no_data"
    if previous <= 0:
        return "new"
    change = _change_pct(current, previous)
    if change is None:
        return "new"
    if change <= -3:
        return "improving"
    if change >= 3:
        return "worsening"
    return "stable"


def _weekday_pattern(daily):
    totals = [0.0] * 7
    counts = [0] * 7
    for row in daily:
        day = date.fromisoformat(row["date"])
        totals[day.weekday()] += float(row["co2_kg"] or 0)
        counts[day.weekday()] += 1
    by_weekday = [
        {
            "weekday": i,
            "label": WEEKDAYS[i],
            "co2_kg": round(totals[i], 2),
            "days": counts[i],
        }
        for i in range(7)
    ]

    active = [row for row in daily if (row["co2_kg"] or 0) > 0]
    best = min(active, key=lambda r: r["co2_kg"]) if active else None
    worst = max(active, key=lambda r: r["co2_kg"]) if active else None
    return {
        "by_weekday": by_weekday,
        "best_day": best,
        "worst_day": worst,
    }


def _highlights_watchouts(
    *, has_data, score, change_pct, top_category, categories, active_days,
    period, streak, logged_today, water_avg
):
    highlights = []
    watchouts = []

    if not has_data:
        watchouts.append({
            "title": "No data yet",
            "body": "Log a few activities to unlock personalised insights.",
        })
        return highlights, watchouts

    if score is not None and score["score"] >= 80:
        highlights.append({
            "title": "Excellent footprint",
            "body": (
                f"Your Eco Score is {score['score']}/100 — "
                f"{score['grade'].lower()}."
            ),
        })

    if change_pct is not None and change_pct <= -3:
        highlights.append({
            "title": "Down from last period",
            "body": f"Your footprint fell {abs(round(change_pct))}% versus the previous period.",
        })
    elif change_pct is not None and change_pct >= 10:
        watchouts.append({
            "title": "Footprint is rising",
            "body": f"Your footprint rose {round(change_pct)}% versus the previous period.",
        })

    if top_category and top_category["share"] >= 0.5:
        share = round(top_category["share"] * 100)
        watchouts.append({
            "title": f"{top_category['category'].title()} dominates",
            "body": (
                f"{top_category['category'].title()} is {share}% of your "
                "footprint this period."
            ),
        })

    logged_categories = [c for c in categories if c["co2_kg"] > 0 or c["entries"] > 0]
    if len(logged_categories) == len(FACTORS):
        highlights.append({
            "title": "Full picture",
            "body": "You logged all four categories this period.",
        })

    threshold = 5 if period == "week" else 20
    if active_days >= threshold:
        highlights.append({
            "title": "Consistent logging",
            "body": f"You logged on {active_days} active days this period.",
        })
    elif active_days < 3:
        watchouts.append({
            "title": "More data needed",
            "body": "A few more logged days will make your insights sharper.",
        })

    if streak and streak["current"] >= 3:
        highlights.append({
            "title": f"{streak['current']}-day streak",
            "body": "Consistency is building a reliable picture of your footprint.",
        })
    if not logged_today and streak and streak["current"] > 0:
        watchouts.append({
            "title": "Streak at risk",
            "body": f"Log today to keep your {streak['current']}-day streak alive.",
        })

    if water_avg and water_avg > 150:
        watchouts.append({
            "title": "High water use",
            "body": f"You average {round(water_avg)} litres per logged day.",
        })

    return highlights[:4], watchouts[:4]


@insights_bp.get("")
@jwt_required()
def insights():
    uid = _uid()
    period = (request.args.get("period") or "week").strip().lower()
    if period not in PERIOD_DAYS:
        return jsonify(error="period must be 'week' or 'month'"), 400

    span = PERIOD_DAYS[period]
    today = date.today()
    cur_end = today
    cur_start = cur_end - timedelta(days=span - 1)
    prev_end = cur_start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)

    by_category, daily, total, active_days = _collect(uid, cur_start, cur_end)
    prev_by_category, _, prev_total, prev_active = _collect(
        uid, prev_start, prev_end
    )

    score = _eco_score(total, active_days)
    previous_score = _eco_score(prev_total, prev_active)
    change_pct = _change_pct(total, prev_total)
    trend = _trend(total, prev_total, active_days)

    entries = sum(c["entries"] for c in by_category.values())
    categories = []
    top_category = None
    for category in FACTORS:
        current = by_category[category]["co2_kg"]
        previous = prev_by_category[category]["co2_kg"]
        item = {
            "category": category,
            "co2_kg": current,
            "entries": by_category[category]["entries"],
            "share": round(current / total, 3) if total > 0 else 0.0,
            "previous_co2_kg": previous,
            "change_pct": _change_pct(current, previous),
        }
        categories.append(item)
        if top_category is None or item["co2_kg"] > top_category["co2_kg"]:
            top_category = item
    if top_category and top_category["co2_kg"] <= 0:
        top_category = None

    streak = {"current": 0, "longest": 0}
    days = _logged_days(uid)
    current_streak, longest_streak = streak_from_days(days)
    streak = {"current": current_streak, "longest": longest_streak}

    water_avg = (
        by_category["water"]["quantity"] / active_days if active_days else 0
    )
    highlights, watchouts = _highlights_watchouts(
        has_data=active_days > 0,
        score=score,
        change_pct=change_pct,
        top_category=top_category,
        categories=categories,
        active_days=active_days,
        period=period,
        streak=streak,
        logged_today=today in days,
        water_avg=water_avg,
    )

    monthly_kg = round(total / span * 30, 1) if span else 0.0
    projection = {
        "monthly_co2_kg": monthly_kg,
        "annual_tonnes": round(monthly_kg * 12 / 1000, 2),
    }

    if active_days == 0:
        summary = "Log an activity to unlock your personalised insights."
    else:
        avg = score["avg_daily_co2_kg"] if score else round(total / active_days, 2)
        summary = (
            f"You logged {entries} activities across {active_days} active "
            f"{'day' if active_days == 1 else 'days'}, averaging {avg} kg CO2 "
            "per active day."
        )

    return jsonify(
        period=period,
        start=cur_start.isoformat(),
        end=cur_end.isoformat(),
        has_data=active_days > 0,
        summary=summary,
        total_co2_kg=total,
        active_days=active_days,
        entries=entries,
        eco_score=score,
        previous={
            "start": prev_start.isoformat(),
            "end": prev_end.isoformat(),
            "total_co2_kg": prev_total,
            "active_days": prev_active,
            "eco_score": previous_score,
        },
        change_pct=change_pct,
        trend=trend,
        top_category=top_category,
        categories=categories,
        weekday=_weekday_pattern(daily),
        projection=projection,
        streak=streak,
        highlights=highlights,
        watchouts=watchouts,
        tips=_recommendations(by_category, total, active_days, score),
        explanation=_explanation(by_category, total, score),
    )
