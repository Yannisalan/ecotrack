from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from .challenge_engine import (
    completed_count,
    evaluate_challenges,
    history,
    points_ledger,
    summary,
    total_points,
)
from .engagement import evaluate

challenges_bp = Blueprint('challenges', __name__, url_prefix='/api/challenges')


def _uid():
    return int(get_jwt_identity())


@challenges_bp.get('')
@jwt_required()
def list_challenges():
    """Current daily/weekly challenges with live progress and points.

    Re-evaluates on read so completing a target is reflected (and rewarded)
    immediately; ``evaluate_challenges`` is idempotent per period.
    """
    uid = _uid()
    evaluate_challenges(uid)
    evaluate(uid)
    return jsonify(
        challenges=summary(uid),
        points=total_points(uid),
        completed_total=completed_count(uid),
        history=history(uid, limit=10),
    )


@challenges_bp.get('/history')
@jwt_required()
def challenge_history():
    """Completed daily/weekly challenges, newest first."""
    return jsonify(
        completed_total=completed_count(_uid()),
        history=history(_uid(), limit=50),
    )


@challenges_bp.get('/points')
@jwt_required()
def challenge_points():
    """Total Eco Points plus the ledger of how they were earned."""
    uid = _uid()
    return jsonify(points=total_points(uid), ledger=points_ledger(uid))
