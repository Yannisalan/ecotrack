from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from .engagement import payload

achievements_bp = Blueprint('achievements', __name__, url_prefix='/api/achievements')


@achievements_bp.get('')
@jwt_required()
def list_achievements():
    """Definitions + earned state + live progress + streak for the current user."""
    return jsonify(payload(int(get_jwt_identity())))


@achievements_bp.get('/me')
@jwt_required()
def my_achievements():
    """Backwards-compatible alias for the list view."""
    return jsonify(payload(int(get_jwt_identity())))
