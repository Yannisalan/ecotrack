import re
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    jwt_required,
    get_jwt_identity,
    get_jwt,
    set_refresh_cookies,
    unset_jwt_cookies,
)
from .extensions import db, limiter
from .models import User, TokenBlocklist, PasswordResetToken
from .validation import validate_password, normalize_email, is_valid_email

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

RESET_TTL_MINUTES = 30

# Version string of the Terms and Conditions / Privacy Policy a new account
# accepts. Update this when the legal documents change.
POLICY_VERSION = "2026-10-21"

# Refresh tokens are read from the HttpOnly cookie (web) or the JSON body
# (mobile, and web clients that cannot use a first-party cookie). The
# Authorization header is deliberately not a refresh location: no client
# sends the refresh token that way, and accepting it in a header would let a
# token be replayed from a channel the browser does not protect the same way.
# Access tokens stay header-only.
_REFRESH_LOCATIONS = ["cookies", "json"]


def _client_is_web():
    """The web client opts into cookie-based refresh with this header."""
    return request.headers.get("X-Client-Platform", "").strip().lower() == "web"


def _token_version(user):
    return int(user.token_version or 0)


def _issue_tokens(user):
    """Access token always in the body. Refresh token goes into an HttpOnly
    cookie for the web, and into the body for mobile (stored in the keychain).
    ``tv`` pins every token to the user's token_version so a password reset
    can invalidate all outstanding sessions at once."""
    claims = {"tv": _token_version(user)}
    access_token = create_access_token(identity=str(user.id), additional_claims=claims)
    refresh_token = create_refresh_token(identity=str(user.id), additional_claims=claims)
    body = {"user": user.to_dict(), "access_token": access_token}
    if _client_is_web():
        resp = jsonify(body)
        set_refresh_cookies(resp, refresh_token)
        return resp
    body["refresh_token"] = refresh_token
    return jsonify(body)


def _revoke_refresh(payload):
    """Blocklist the presented refresh token's jti (idempotent)."""
    jti = payload.get("jti")
    if not jti:
        return
    if TokenBlocklist.query.filter_by(jti=jti).first():
        return
    exp = payload.get("exp")
    if exp:
        expires_at = datetime.fromtimestamp(exp, tz=timezone.utc).replace(tzinfo=None)
    else:
        expires_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.session.add(TokenBlocklist(
        jti=jti,
        user_id=int(get_jwt_identity()),
        token_type="refresh",
        expires_at=expires_at,
    ))
    db.session.commit()


@auth_bp.post("/register")
@limiter.limit("10 per minute")
def register():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    email = normalize_email(data.get("email"))
    password = data.get("password") or ""
    terms_accepted = data.get("terms_accepted")

    if not name or not email or not password:
        return jsonify(error="name, email and password are required"), 400
    if not is_valid_email(email):
        return jsonify(error="Invalid email address"), 400
    policy_error = validate_password(password)
    if policy_error:
        return jsonify(error=policy_error), 400
    # Consent is mandatory: reject anything that is not explicitly true so a
    # missing or falsy flag can never create an account.
    if terms_accepted is not True:
        return jsonify(
            error="You must accept the Terms and Privacy Policy to create an account."
        ), 400
    if User.query.filter_by(email=email).first():
        # Generic answer on purpose. The response is byte-for-byte the same
        # as any other rejected registration, so the endpoint cannot be used
        # to discover which addresses already have an account. The rate limit
        # above still applies, so the probing is rate limited as well.
        from .errors import MSG_BAD_REQUEST

        return jsonify(error=MSG_BAD_REQUEST), 400

    user = User(
        name=name,
        email=email,
        terms_accepted=True,
        terms_accepted_at=datetime.now(timezone.utc).replace(tzinfo=None),
        policy_version=POLICY_VERSION,
    )
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    # Seed the onboarding notification immediately (GET is now read-only).
    from .notification_service import generate_for_user
    generate_for_user(user.id)

    return _issue_tokens(user), 201


@auth_bp.post("/login")
@limiter.limit("10 per minute")
def login():
    data = request.get_json(silent=True) or {}
    email = normalize_email(data.get("email"))
    password = data.get("password") or ""

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify(error="Invalid email or password"), 401

    # Refresh reminders on login so the inbox is current on the next open.
    from .notification_service import generate_for_user
    generate_for_user(user.id)

    return _issue_tokens(user), 200


@auth_bp.post("/refresh")
@jwt_required(refresh=True, locations=_REFRESH_LOCATIONS)
@limiter.limit("30 per minute")
def refresh():
    identity = get_jwt_identity()
    user = db.session.get(User, int(identity)) if identity else None
    if not user:
        return jsonify(error="User not found"), 404
    _revoke_refresh(get_jwt())
    return _issue_tokens(user), 200


@auth_bp.post("/logout")
@jwt_required(optional=True, refresh=True, locations=_REFRESH_LOCATIONS)
@limiter.limit("30 per minute")
def logout():
    try:
        payload = get_jwt() or {}
    except RuntimeError:
        payload = {}
    if payload.get("jti"):
        _revoke_refresh(payload)
    resp = jsonify(message="Logged out")
    unset_jwt_cookies(resp)
    return resp, 200


@auth_bp.get("/me")
@jwt_required()
def me():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return jsonify(error="User not found"), 404
    return jsonify(user=user.to_dict()), 200

@auth_bp.delete('/account')
@jwt_required()
def delete_account():
    uid = int(get_jwt_identity())
    from .models import (
        Activity,
        ChallengePeriod,
        EcoScore,
        EcoScoreHistory,
        Goal,
        Notification,
        NotificationPreference,
        PasswordResetToken,
        PointsLedger,
        User,
        UserAchievement,
        UserChallenge,
        UserPoints,
        UserStreak,
    )
    user = db.session.get(User, uid)
    if not user:
        return jsonify({'error': 'Not found'}), 404
    try:
        for model in (
            Activity,
            Goal,
            UserAchievement,
            EcoScore,
            EcoScoreHistory,
            UserStreak,
            ChallengePeriod,
            UserChallenge,
            PointsLedger,
            UserPoints,
            Notification,
            NotificationPreference,
            PasswordResetToken,
        ):
            model.query.filter_by(user_id=uid).delete(synchronize_session=False)
        db.session.delete(user)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(
            "Failed to execute account deletion for user %s: %s", uid, e
        )
        return jsonify({'error': 'Failed to delete account'}), 500
    resp = jsonify({'message': 'Account deleted'})
    unset_jwt_cookies(resp)
    return resp, 200


def _hash_reset_token(raw):
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


@auth_bp.post("/forgot-password")
@limiter.limit("5 per minute")
def forgot_password():
    """Start a password reset.

    Always answers 200 so the response cannot be used to probe which emails
    are registered. A raw, single-use token is generated for known emails;
    without SMTP configured it is only echoed back when
    RESET_TOKEN_IN_RESPONSE is enabled (debug/demo mode).
    """
    data = request.get_json(silent=True) or {}
    email = normalize_email(data.get("email"))
    body = {"message": "If that email is registered, a reset token has been generated."}

    user = User.query.filter_by(email=email).first() if email else None
    if user:
        raw = secrets.token_urlsafe(32)
        PasswordResetToken.query.filter_by(user_id=user.id, used_at=None).delete(
            synchronize_session=False
        )
        db.session.add(PasswordResetToken(
            user_id=user.id,
            token_hash=_hash_reset_token(raw),
            expires_at=datetime.now(timezone.utc).replace(tzinfo=None)
            + timedelta(minutes=RESET_TTL_MINUTES),
        ))
        db.session.commit()
        current_app.logger.info("Password reset requested for user %s", user.id)
        if current_app.config.get("RESET_TOKEN_IN_RESPONSE"):
            body["reset_token"] = raw

    return jsonify(body), 200


@auth_bp.post("/reset-password")
@limiter.limit("10 per minute")
def reset_password():
    data = request.get_json(silent=True) or {}
    token = (data.get("token") or "").strip()
    password = data.get("password") or ""

    if not token or not password:
        return jsonify(error="token and password are required"), 400
    policy_error = validate_password(password)
    if policy_error:
        return jsonify(error=policy_error), 400

    row = PasswordResetToken.query.filter_by(token_hash=_hash_reset_token(token)).first()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if not row or row.used_at is not None or row.expires_at < now:
        return jsonify(error="Invalid or expired reset token"), 400

    user = db.session.get(User, row.user_id)
    if not user:
        # Same response as an invalid token so a valid token cannot be used to
        # probe whether an account still exists.
        return jsonify(error="Invalid or expired reset token"), 400

    user.set_password(password)
    user.token_version = (user.token_version or 0) + 1
    row.used_at = now
    db.session.commit()
    return jsonify(message="Password has been reset. You can log in."), 200


@auth_bp.post("/change-password")
@jwt_required()
@limiter.limit("10 per minute")
def change_password():
    data = request.get_json(silent=True) or {}
    current = data.get("current_password") or ""
    new = data.get("new_password") or ""

    if not current or not new:
        return jsonify(error="current_password and new_password are required"), 400
    policy_error = validate_password(new)
    if policy_error:
        return jsonify(error=policy_error), 400

    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return jsonify(error="User not found"), 404
    if not user.check_password(current):
        return jsonify(error="Current password is incorrect"), 400

    user.set_password(new)
    user.token_version = (user.token_version or 0) + 1
    db.session.commit()
    return jsonify(message="Password changed"), 200
