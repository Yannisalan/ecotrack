"""Server-driven, in-app smart notifications.

Notifications are deterministic nudges derived from the user's own data
(streak, challenges, trend, achievements, weekly summary). They are persisted
per user with read/unread state and per-user preferences, so the feed stays
consistent across devices and app restarts. No third-party push infrastructure
is required; device push would be an optional transport on top of these rows.
"""
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from . import notification_service as service
from .extensions import limiter

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')


def _uid():
    return int(get_jwt_identity())


def _payload(uid):
    rows = service.list_for_user(uid)
    return {
        'notifications': [service.serialize(n) for n in rows],
        'unread': sum(1 for n in rows if n.read_at is None),
    }


@notifications_bp.get('')
@jwt_required()
@limiter.limit("120 per minute")
def list_notifications():
    return jsonify(_payload(_uid()))


@notifications_bp.post('/read-all')
@jwt_required()
def read_all():
    uid = _uid()
    updated = service.mark_all_read(uid)
    return jsonify(updated=updated, unread=0)


@notifications_bp.post('/<int:notification_id>/read')
@jwt_required()
def read_one(notification_id):
    uid = _uid()
    row = service.mark_read(uid, notification_id)
    if row is None:
        return jsonify(error='Notification not found'), 404
    return jsonify(
        notification=service.serialize(row),
        unread=service.unread_count(uid),
    )


@notifications_bp.delete('/<int:notification_id>')
@jwt_required()
def delete_one(notification_id):
    uid = _uid()
    if not service.delete(uid, notification_id):
        return jsonify(error='Notification not found'), 404
    return jsonify(message='Deleted', unread=service.unread_count(uid))


@notifications_bp.route('/preferences', methods=['GET', 'PUT'])
@jwt_required()
def preferences():
    uid = _uid()
    if request.method == 'PUT':
        data = request.get_json(silent=True) or {}
        try:
            prefs = service.update_preferences(uid, data)
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(preferences=prefs.to_dict())
    return jsonify(preferences=service.get_preferences(uid).to_dict())
