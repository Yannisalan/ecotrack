from datetime import date, timedelta
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import func
from .extensions import db
from .models import Activity
from .factors import FACTORS, UNITS

stats_bp = Blueprint("stats", __name__, url_prefix="/api/stats")

# ---- Tunable settings -------------------------------------------------------
PERIOD_DAYS = {"week": 7, "month": 30}   # rolling windows ending today
GOOD_DAILY_CO2 = 3.0     # kg CO2/day at or below this -> score 100
POOR_DAILY_CO2 = 15.0    # kg CO2/day at or above this -> score 0
WATER_HIGH_LITRES_PER_DAY = 150
MAX_RECOMMENDATIONS = 4
# -----------------------------------------------------------------------------


def _uid():
    return int(get_jwt_identity())


def _window():
    period = (request.args.get("period") or "week").lower()
    if period not in PERIOD_DAYS:
        return None, None, None, "period must be 'week' or 'month'"
    days = PERIOD_DAYS[period]
    end = date.today()
    start = end - timedelta(days=days - 1)
    return period, start, end, None


def get_stats(user_id, start, end):
    return _collect(user_id, start, end)


def _collect(user_id, start, end):
    """Aggregate this user's activities in [start, end]."""
    by_type = (
        db.session.query(
            Activity.category,
            Activity.type,
            func.sum(Activity.quantity),
            func.sum(Activity.co2_kg),
            func.count(Activity.id),
        )
        .filter(Activity.user_id == user_id, Activity.date >= start, Activity.date <= end)
        .group_by(Activity.category, Activity.type)
        .all()
    )
    per_day = dict(
        db.session.query(Activity.date, func.sum(Activity.co2_kg))
        .filter(Activity.user_id == user_id, Activity.date >= start, Activity.date <= end)
        .group_by(Activity.date)
        .all()
    )

    by_category = {
        cat: {"co2_kg": 0.0, "quantity": 0.0, "unit": UNITS[cat], "entries": 0, "by_type": {}}
        for cat in FACTORS
    }
    for category, type_, qty, co2, count in by_type:
        c = by_category[category]
        c["co2_kg"] += float(co2 or 0)
        c["quantity"] += float(qty or 0)
        c["entries"] += int(count)
        c["by_type"][type_] = {"quantity": round(float(qty or 0), 3), "co2_kg": round(float(co2 or 0), 3)}

    total = sum(c["co2_kg"] for c in by_category.values())
    for c in by_category.values():
        c["co2_kg"] = round(c["co2_kg"], 3)
        c["quantity"] = round(c["quantity"], 3)

    daily = []
    d = start
    while d <= end:
        daily.append({"date": d.isoformat(), "co2_kg": round(float(per_day.get(d, 0) or 0), 3)})
        d += timedelta(days=1)

    return by_category, daily, round(total, 3), len(per_day)


def compute_score(total_co2, active_days):
    return _eco_score(total_co2, active_days)


def _eco_score(total_co2, active_days):
    """0-100 from average CO2 per *active* day (days with at least one log)."""
    if active_days == 0:
        return None
    avg = total_co2 / active_days
    if avg <= GOOD_DAILY_CO2:
        score = 100
    elif avg >= POOR_DAILY_CO2:
        score = 0
    else:
        score = 100 * (POOR_DAILY_CO2 - avg) / (POOR_DAILY_CO2 - GOOD_DAILY_CO2)
    score = round(score)
    grade = (
        "Excellent" if score >= 80 else
        "Good" if score >= 60 else
        "Fair" if score >= 40 else
        "Needs work"
    )
    return {
        "score": score,
        "grade": grade,
        "avg_daily_co2_kg": round(avg, 2),
        "active_days": active_days,
        "good_daily_co2_kg": GOOD_DAILY_CO2,
        "poor_daily_co2_kg": POOR_DAILY_CO2,
    }


def _explanation(by_category, total, score):
    """Plain-language breakdown of how the Eco Score was produced.

    The score is the average CO2 *per active day*, so it is not decomposable
    into per-category points. The explanation therefore reports the formula,
    the thresholds, and the largest contributing category as context.
    """
    if score is None:
        return {
            "available": False,
            "text": "Log at least one activity this period to receive an Eco Score.",
        }

    steps = [
        f"Average footprint of {score['avg_daily_co2_kg']} kg CO2 per active "
        f"day across {score['active_days']} active "
        f"{'day' if score['active_days'] == 1 else 'days'}.",
        f"100 points for {GOOD_DAILY_CO2} kg/day or less; 0 points for "
        f"{POOR_DAILY_CO2} kg/day or more; scored linearly in between.",
        f"Result: {score['score']}/100 ({score['grade']}).",
    ]

    result = {
        "available": True,
        "score": score["score"],
        "grade": score["grade"],
        "avg_daily_co2_kg": score["avg_daily_co2_kg"],
        "active_days": score["active_days"],
        "thresholds": {"good_daily_co2_kg": GOOD_DAILY_CO2, "poor_daily_co2_kg": POOR_DAILY_CO2},
        "steps": steps,
    }

    if total > 0:
        category, entry = max(by_category.items(), key=lambda kv: kv[1]["co2_kg"])
        if entry["co2_kg"] > 0:
            result["top_category"] = {
                "category": category,
                "co2_kg": round(entry["co2_kg"], 3),
                "share": round(entry["co2_kg"] / total, 3),
            }
    return result


def _recommendations(by_category, total, active_days, score):
    if total <= 0 and all(c["entries"] == 0 for c in by_category.values()):
        return [{
            "category": "general",
            "title": "Start logging",
            "message": "Log your travel, electricity, water and waste for a few days to get personalised tips.",
            "estimated_saving_co2_kg": 0.0,
        }]

    recs = []
    share = lambda co2: (co2 / total) if total > 0 else 0

    # Transport
    t = by_category["transport"]["by_type"]
    car_km = sum(t.get(k, {}).get("quantity", 0) for k in ("car_petrol", "car_diesel"))
    car_co2 = sum(t.get(k, {}).get("co2_kg", 0) for k in ("car_petrol", "car_diesel"))
    if car_km > 0 and share(car_co2) >= 0.30:
        moved = car_km * 0.25
        saving = moved * (car_co2 / car_km - FACTORS["transport"]["bus"])
        recs.append({
            "category": "transport",
            "title": "Swap some car trips",
            "message": (f"Car travel made up {share(car_co2):.0%} of your footprint. Moving a quarter of "
                        f"those km ({moved:.0f} km) to bus or metro could save about {saving:.1f} kg CO2."),
            "estimated_saving_co2_kg": round(saving, 2),
        })
    fl = t.get("flight", {})
    if fl.get("quantity", 0) > 0 and share(fl.get("co2_kg", 0)) >= 0.30:
        moved = fl["quantity"] * 0.25
        saving = moved * (FACTORS["transport"]["flight"] - FACTORS["transport"]["train"])
        recs.append({
            "category": "transport",
            "title": "Take the train for shorter journeys",
            "message": (f"Flights made up {share(fl['co2_kg']):.0%} of your footprint. Taking the train for "
                        f"a quarter of that distance could save about {saving:.1f} kg CO2."),
            "estimated_saving_co2_kg": round(saving, 2),
        })

    # Electricity
    e = by_category["electricity"]["by_type"].get("grid", {})
    if e.get("quantity", 0) > 0 and share(e.get("co2_kg", 0)) >= 0.25:
        saving = e["quantity"] * 0.10 * FACTORS["electricity"]["grid"]
        recs.append({
            "category": "electricity",
            "title": "Trim grid electricity",
            "message": (f"Grid electricity made up {share(e['co2_kg']):.0%} of your footprint. Cutting use by "
                        f"10% (LED lights, switching off standby, efficient AC settings) saves about "
                        f"{saving:.1f} kg CO2."),
            "estimated_saving_co2_kg": round(saving, 2),
        })

    # Water
    water = by_category["water"]
    if active_days and water["quantity"] / active_days > WATER_HIGH_LITRES_PER_DAY:
        litres_saved = water["quantity"] * 0.20
        recs.append({
            "category": "water",
            "title": "Reduce water use",
            "message": (f"You average {water['quantity'] / active_days:.0f} litres per logged day. Shorter showers "
                        f"and fixing leaks could save about {litres_saved:.0f} litres this period."),
            "estimated_saving_co2_kg": round(litres_saved * FACTORS["water"]["tap"], 3),
        })

    # Waste
    w = by_category["waste"]
    landfill = w["by_type"].get("landfill", {}).get("quantity", 0)
    if w["quantity"] > 0 and landfill / w["quantity"] >= 0.60:
        saving = landfill * 0.5 * (FACTORS["waste"]["landfill"] - FACTORS["waste"]["recycling"])
        recs.append({
            "category": "waste",
            "title": "Recycle or compost more",
            "message": (f"{landfill / w['quantity']:.0%} of your waste went to landfill. Recycling or composting "
                        f"half of it could save about {saving:.1f} kg CO2."),
            "estimated_saving_co2_kg": round(saving, 2),
        })

    recs.sort(key=lambda r: r["estimated_saving_co2_kg"], reverse=True)
    recs = recs[:MAX_RECOMMENDATIONS]

    if not recs:
        msg = ("Great work, nothing stands out as a big source of emissions. Keep logging to stay on track."
               if score and score["score"] >= 60 else
               "Keep logging for a few more days so we can spot where you can cut back.")
        recs.append({"category": "general", "title": "Keep it up", "message": msg,
                     "estimated_saving_co2_kg": 0.0})
    return recs


def _build():
    period, start, end, err = _window()
    if err:
        return None, err
    by_category, daily, total, active_days = _collect(_uid(), start, end)
    return {
        "period": period,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "days": PERIOD_DAYS[period],
        "active_days": active_days,
        "total_co2_kg": total,
        "by_category": by_category,
        "daily": daily,
    }, None


@stats_bp.get("/summary")
@jwt_required()
def summary():
    data, err = _build()
    if err:
        return jsonify(error=err), 400
    return jsonify(data)


@stats_bp.get("/score")
@jwt_required()
def score():
    data, err = _build()
    if err:
        return jsonify(error=err), 400
    sc = _eco_score(data["total_co2_kg"], data["active_days"])
    return jsonify(
        period=data["period"], start=data["start"], end=data["end"],
        total_co2_kg=data["total_co2_kg"],
        eco_score=sc,
        explanation=_explanation(data["by_category"], data["total_co2_kg"], sc),
    )


@stats_bp.get("/compare")
@jwt_required()
def compare():
    """Current period vs the immediately preceding equal-length window."""
    period = (request.args.get("period") or "week").strip().lower()
    if period not in PERIOD_DAYS:
        return jsonify(error="period must be week or month"), 400
    span = PERIOD_DAYS[period]
    cur_end = date.today()
    cur_start = cur_end - timedelta(days=span - 1)
    prev_end = cur_start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)

    uid = _uid()
    cur_bc, _, cur_total, cur_active = _collect(uid, cur_start, cur_end)
    prev_bc, _, prev_total, prev_active = _collect(uid, prev_start, prev_end)

    by_category = {}
    for cat in FACTORS:
        a = cur_bc[cat]["co2_kg"]
        b = prev_bc[cat]["co2_kg"]
        by_category[cat] = {
            "current": a,
            "previous": b,
            "delta": round(a - b, 3),
            "pct": round((a - b) / b * 100, 1) if b > 0 else None,
        }

    return jsonify(
        period=period,
        current={
            "start": cur_start.isoformat(), "end": cur_end.isoformat(),
            "total_co2_kg": cur_total, "active_days": cur_active,
            "eco_score": _eco_score(cur_total, cur_active),
        },
        previous={
            "start": prev_start.isoformat(), "end": prev_end.isoformat(),
            "total_co2_kg": prev_total, "active_days": prev_active,
            "eco_score": _eco_score(prev_total, prev_active),
        },
        total_delta_kg=round(cur_total - prev_total, 3),
        total_change_pct=(round((cur_total - prev_total) / prev_total * 100, 1)
                          if prev_total > 0 else None),
        by_category=by_category,
    )


@stats_bp.get("/recommendations")
@jwt_required()
def recommendations():
    data, err = _build()
    if err:
        return jsonify(error=err), 400
    sc = _eco_score(data["total_co2_kg"], data["active_days"])
    return jsonify(
        period=data["period"],
        recommendations=_recommendations(
            data["by_category"], data["total_co2_kg"], data["active_days"], sc
        ),
    )

@stats_bp.get("/streak")
@jwt_required()
def streak():
    """Consecutive days with at least one logged activity, ending today
    (or yesterday when today has no entries yet), plus the longest run.

    Uses the shared engagement engine so the streak definition stays identical
    to the one that drives streak achievements.
    """
    from .engagement import streak_from_days, _logged_days

    current, longest = streak_from_days(_logged_days(_uid()))
    return jsonify(current_streak=current, longest_streak=longest)


@stats_bp.get('/score-history')
@jwt_required()
def score_history():
    uid = _uid()
    from app.models import EcoScoreHistory
    items = EcoScoreHistory.query.filter_by(user_id=uid).order_by(EcoScoreHistory.recorded_at.desc()).limit(30).all()
    return jsonify([{'score': i.score, 'recorded_at': i.recorded_at.isoformat() if i.recorded_at else None} for i in items])


@stats_bp.get("/calendar")
@jwt_required()
def calendar():
    """Per-day footprint for a calendar month (heatmap + day drill-down).

    ``?month=YYYY-MM`` (defaults to the current month). Uses server-local
    calendar dates, consistent with activities and streaks.
    """
    raw = request.args.get("month") or date.today().strftime("%Y-%m")
    try:
        year, month = (int(part) for part in raw.split("-"))
        start = date(year, month, 1)
    except (ValueError, TypeError):
        return jsonify(error="month must be YYYY-MM"), 400
    if not 1 <= month <= 12:
        return jsonify(error="month must be YYYY-MM"), 400
    end = date(year + (month // 12), (month % 12) + 1, 1) - timedelta(days=1)

    uid = _uid()
    agg = {
        d: (float(co2 or 0), int(n))
        for d, co2, n in db.session.query(
            Activity.date, func.sum(Activity.co2_kg), func.count(Activity.id)
        )
        .filter(Activity.user_id == uid, Activity.date >= start, Activity.date <= end)
        .group_by(Activity.date)
        .all()
    }
    days_cat = {}
    for d, cat in (
        db.session.query(Activity.date, Activity.category)
        .filter(Activity.user_id == uid, Activity.date >= start, Activity.date <= end)
        .distinct()
        .all()
    ):
        days_cat.setdefault(d, set()).add(cat)

    days = []
    d = start
    while d <= end:
        co2, entries = agg.get(d, (0.0, 0))
        days.append({
            "date": d.isoformat(),
            "co2_kg": round(co2, 3),
            "entries": entries,
            "categories": sorted(days_cat.get(d, set())),
            "level": _day_level(co2, entries),
        })
        d += timedelta(days=1)

    return jsonify(month=raw, start=start.isoformat(), end=end.isoformat(), days=days)


@stats_bp.get("/grove")
@jwt_required()
def grove():
    """Lightweight summary to render the virtual eco-world (grove)."""
    uid = _uid()
    from app.models import Activity, Goal

    logged_days = (
        db.session.query(func.count(func.distinct(Activity.date)))
        .filter(Activity.user_id == uid)
        .scalar()
        or 0
    )
    activities = Activity.query.filter_by(user_id=uid).count()
    goals = Goal.query.filter_by(user_id=uid, status="completed").count()
    total_co2 = (
        db.session.query(func.coalesce(func.sum(Activity.co2_kg), 0.0))
        .filter(Activity.user_id == uid)
        .scalar()
        or 0.0
    )

    # Cap trees to keep UI lightweight (reference uses 12 max)
    trees = min(logged_days + goals, 12)
    saplings = activities
    return jsonify(
        trees=trees,
        saplings=saplings,
        total_co2_kg=round(float(total_co2), 3),
        logged_days=logged_days,
        activities=activities,
        goals_completed=goals,
    )


def _day_level(co2, entries):
    if entries == 0:
        return 0
    if co2 <= GOOD_DAILY_CO2 / 2:
        return 1
    if co2 <= GOOD_DAILY_CO2:
        return 2
    if co2 <= POOR_DAILY_CO2:
        return 3
    return 4
