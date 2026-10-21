from flask import Blueprint, jsonify, request
from app.extensions import db
from app.models import Goal
from app.engagement import evaluate
from app.notification_service import generate_for_user
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime

goals_bp = Blueprint('goals', __name__, url_prefix='/api/goals')

VALID_STATUS = {'active', 'completed'}


def _to_dict(g):
    return {
        'id': g.id, 'title': g.title, 'metric': g.metric,
        'target_value': g.target_value, 'current_value': g.current_value,
        'unit': g.unit, 'start_date': str(g.start_date) if g.start_date else None,
        'end_date': str(g.end_date) if g.end_date else None,
        'status': g.status,
    }


def _owned(goal_id, uid):
    return Goal.query.filter_by(id=goal_id, user_id=uid).first()


@goals_bp.route('', methods=['GET', 'POST'])
@jwt_required()
def list_create():
    uid = int(get_jwt_identity())
    if request.method == 'POST':
        data = request.get_json(silent=True) or {}
        title = (data.get('title') or '').strip()
        if not title:
            return jsonify(error='title is required'), 400
        try:
            target = float(data.get('target_value', 0))
        except (TypeError, ValueError):
            return jsonify(error='target_value must be a number'), 400
        if target <= 0:
            return jsonify(error='target_value must be greater than 0'), 400
        status = data.get('status', 'active')
        if status not in VALID_STATUS:
            return jsonify(error="status must be 'active' or 'completed'"), 400
        g = Goal(
            user_id=uid,
            title=title,
            metric=data.get('metric', 'co2'),
            target_value=target,
            current_value=float(data.get('current_value', 0) or 0),
            unit=data.get('unit'),
            start_date=datetime.fromisoformat(data['start_date']).date() if data.get('start_date') else None,
            end_date=datetime.fromisoformat(data['end_date']).date() if data.get('end_date') else None,
            status=status,
        )
        db.session.add(g)
        db.session.commit()
        evaluate(uid)
        generate_for_user(uid)
        return jsonify(_to_dict(g)), 201
    items = Goal.query.filter_by(user_id=uid).all()
    return jsonify([_to_dict(x) for x in items])


@goals_bp.route('/<int:goal_id>', methods=['PATCH', 'DELETE'])
@jwt_required()
def update_delete(goal_id):
    uid = int(get_jwt_identity())
    g = _owned(goal_id, uid)
    if not g:
        return jsonify(error='Goal not found'), 404

    if request.method == 'DELETE':
        db.session.delete(g)
        db.session.commit()
        return jsonify({'ok': True})

    data = request.get_json(silent=True) or {}
    if 'title' in data:
        title = (data['title'] or '').strip()
        if not title:
            return jsonify(error='title cannot be empty'), 400
        g.title = title
    if 'metric' in data:
        g.metric = data['metric'] or 'co2'
    if 'unit' in data:
        g.unit = data['unit']
    if 'status' in data:
        if data['status'] not in VALID_STATUS:
            return jsonify(error="status must be 'active' or 'completed'"), 400
        g.status = data['status']
    if 'target_value' in data:
        try:
            target = float(data['target_value'])
        except (TypeError, ValueError):
            return jsonify(error='target_value must be a number'), 400
        if target <= 0:
            return jsonify(error='target_value must be greater than 0'), 400
        g.target_value = target
    if 'current_value' in data:
        try:
            current = float(data['current_value'])
        except (TypeError, ValueError):
            return jsonify(error='current_value must be a number'), 400
        if current < 0:
            return jsonify(error='current_value cannot be negative'), 400
        g.current_value = current
    if 'start_date' in data:
        g.start_date = datetime.fromisoformat(data['start_date']).date() if data['start_date'] else None
    if 'end_date' in data:
        g.end_date = datetime.fromisoformat(data['end_date']).date() if data['end_date'] else None

    db.session.commit()
    evaluate(uid)
    generate_for_user(uid)
    return jsonify(_to_dict(g))
