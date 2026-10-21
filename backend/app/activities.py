import math
from datetime import date, timedelta
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from .extensions import db
from .models import Activity, _utcnow
from .factors import FACTORS, UNITS, is_valid, calculate_co2
from .engagement import evaluate
from .challenge_engine import evaluate_challenges
from .notification_service import generate_for_user

activities_bp = Blueprint("activities", __name__, url_prefix="/api/activities")

MAX_QUANTITY = 1_000_000

# Offline sync can retry a create; treat an identical activity logged within
# this short window as a duplicate instead of double-counting it. Short enough
# that logging the same activity twice on purpose still works.
DEDUPE_WINDOW = timedelta(minutes=2)


def _uid():
    return int(get_jwt_identity())


def _parse_quantity(value):
    if isinstance(value, bool):
        return None, "quantity must be a number"
    try:
        q = float(value)
    except (TypeError, ValueError):
        return None, "quantity must be a number"
    if not math.isfinite(q) or q <= 0:
        return None, "quantity must be greater than 0"
    if q > MAX_QUANTITY:
        return None, f"quantity must not exceed {MAX_QUANTITY}"
    return q, None


def _parse_date(value):
    if value in (None, ""):
        return date.today(), None
    try:
        d = date.fromisoformat(str(value))
    except ValueError:
        return None, "date must be in YYYY-MM-DD format"
    if d > date.today():
        return None, "date cannot be in the future"
    return d, None


def _get_owned(activity_id):
    return Activity.query.filter_by(id=activity_id, user_id=_uid()).first()


def _find_duplicate(uid, category, type_, quantity, when):
    return (
        Activity.query
        .filter_by(user_id=uid, category=category, type=type_, date=when)
        .filter(
            Activity.quantity == quantity,
            Activity.created_at >= _utcnow() - DEDUPE_WINDOW,
        )
        .first()
    )


def _insert(uid, category, type_, quantity, when, resend=False, notify=True):
    """Create an activity. When ``resend`` is set (an offline-sync retry that
    may already have been applied) an identical entry within DEDUPE_WINDOW is
    treated as a duplicate instead of being counted twice. Normal logging never
    sets ``resend``, so logging the same activity twice still works.
    Returns (activity, duplicate)."""
    if resend:
        existing = _find_duplicate(uid, category, type_, quantity, when)
        if existing is not None:
            return existing, True

    activity = Activity(
        user_id=uid,
        category=category,
        type=type_,
        quantity=quantity,
        unit=UNITS[category],
        co2_kg=calculate_co2(category, type_, quantity),
        date=when,
    )
    db.session.add(activity)
    db.session.commit()
    evaluate_challenges(uid)
    evaluate(uid)
    if notify:
        generate_for_user(uid)
    return activity, False


@activities_bp.get("/options")
def options():
    """Categories, types and units, for the app's dropdowns."""
    return jsonify(
        categories={
            cat: {"unit": UNITS[cat], "types": sorted(types)}
            for cat, types in FACTORS.items()
        }
    )


@activities_bp.post("")
@jwt_required()
def create_activity():
    data = request.get_json(silent=True) or {}
    category = (data.get("category") or "").strip().lower()
    type_ = (data.get("type") or "").strip().lower()

    if not is_valid(category, type_):
        return jsonify(error="Invalid category/type. See GET /api/activities/options"), 400
    quantity, err = _parse_quantity(data.get("quantity"))
    if err:
        return jsonify(error=err), 400
    when, err = _parse_date(data.get("date"))
    if err:
        return jsonify(error=err), 400

    activity, duplicate = _insert(
        _uid(), category, type_, quantity, when,
        resend=bool(data.get("resend")),
    )
    return jsonify(activity=activity.to_dict(), duplicate=duplicate), (
        200 if duplicate else 201
    )


@activities_bp.post("/batch")
@jwt_required()
def create_activities_batch():
    """Offline sync: create several activities at once, de-duplicating retries."""
    data = request.get_json(silent=True) or {}
    items = data.get("activities")
    if not isinstance(items, list) or not items:
        return jsonify(error="activities must be a non-empty list"), 400

    uid = _uid()
    results = []
    created = 0
    for item in items:
        category = ((item or {}).get("category") or "").strip().lower()
        type_ = ((item or {}).get("type") or "").strip().lower()
        if not is_valid(category, type_):
            results.append({"ok": False, "error": "invalid category/type"})
            continue
        quantity, err = _parse_quantity(item.get("quantity"))
        if err:
            results.append({"ok": False, "error": err})
            continue
        when, err = _parse_date(item.get("date"))
        if err:
            results.append({"ok": False, "error": err})
            continue
        resend = bool(item.get("resend", data.get("resend", True)))
        activity, duplicate = _insert(
            uid, category, type_, quantity, when, resend=resend, notify=False
        )
        results.append({"ok": True, "duplicate": duplicate, "activity": activity.to_dict()})
        if not duplicate:
            created += 1

    if created:
        generate_for_user(uid)
    return jsonify(created=created, results=results)


@activities_bp.get("")
@jwt_required()
def list_activities():
    q = Activity.query.filter_by(user_id=_uid())

    category = (request.args.get("category") or "").strip().lower()
    if category:
        if category not in FACTORS:
            return jsonify(error="Unknown category"), 400
        q = q.filter_by(category=category)

    for param, op in (("from", "ge"), ("to", "le")):
        raw = request.args.get(param)
        if raw:
            try:
                d = date.fromisoformat(raw)
            except ValueError:
                return jsonify(error=f"'{param}' must be YYYY-MM-DD"), 400
            q = q.filter(Activity.date >= d if op == "ge" else Activity.date <= d)

    try:
        limit = min(max(int(request.args.get("limit", 50)), 1), 200)
        offset = max(int(request.args.get("offset", 0)), 0)
    except ValueError:
        return jsonify(error="limit and offset must be integers"), 400

    total = q.count()
    rows = q.order_by(Activity.date.desc(), Activity.id.desc()).limit(limit).offset(offset).all()
    return jsonify(
        activities=[a.to_dict() for a in rows], total=total, limit=limit, offset=offset
    )


@activities_bp.get("/<int:activity_id>")
@jwt_required()
def get_activity(activity_id):
    activity = _get_owned(activity_id)
    if not activity:
        return jsonify(error="Activity not found"), 404
    return jsonify(activity=activity.to_dict())


@activities_bp.route("/<int:activity_id>", methods=["PUT", "PATCH"])
@jwt_required()
def update_activity(activity_id):
    activity = _get_owned(activity_id)
    if not activity:
        return jsonify(error="Activity not found"), 404

    data = request.get_json(silent=True) or {}
    category = (data.get("category") or activity.category).strip().lower()
    type_ = (data.get("type") or activity.type).strip().lower()
    if not is_valid(category, type_):
        return jsonify(error="Invalid category/type. See GET /api/activities/options"), 400

    quantity = activity.quantity
    if "quantity" in data:
        quantity, err = _parse_quantity(data["quantity"])
        if err:
            return jsonify(error=err), 400

    when = activity.date
    if "date" in data:
        when, err = _parse_date(data["date"])
        if err:
            return jsonify(error=err), 400

    activity.category = category
    activity.type = type_
    activity.quantity = quantity
    activity.unit = UNITS[category]
    activity.co2_kg = calculate_co2(category, type_, quantity)
    activity.date = when
    db.session.commit()
    evaluate_challenges(_uid())
    evaluate(_uid())
    generate_for_user(_uid())
    return jsonify(activity=activity.to_dict())


@activities_bp.delete("/<int:activity_id>")
@jwt_required()
def delete_activity(activity_id):
    activity = _get_owned(activity_id)
    if not activity:
        return jsonify(error="Activity not found"), 404
    db.session.delete(activity)
    db.session.commit()
    # Recompute streaks; earned achievements are intentionally kept.
    evaluate_challenges(_uid())
    evaluate(_uid())
    generate_for_user(_uid())
    return jsonify(message="Deleted"), 200
