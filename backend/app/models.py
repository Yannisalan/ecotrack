from datetime import datetime, date, timezone
from werkzeug.security import generate_password_hash, check_password_hash
from .extensions import db


def _utcnow():
    """Naive UTC timestamp (same as the deprecated datetime.utcnow())."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    # Bumped on password reset/change; JWTs carrying an older value are
    # rejected by the blocklist loader, which logs every session out.
    token_version = db.Column(db.Integer, nullable=False, default=0, server_default="0")
    # Consent captured at registration. The version pins the accepted document
    # ("2026-10-21"); the timestamp is UTC.
    terms_accepted = db.Column(db.Boolean, nullable=False, default=False, server_default="0")
    terms_accepted_at = db.Column(db.DateTime)
    policy_version = db.Column(db.String(20))
    created_at = db.Column(db.DateTime, default=_utcnow)

    activities = db.relationship("Activity", backref="user", cascade="all, delete-orphan")
    scores = db.relationship("EcoScore", backref="user", cascade="all, delete-orphan")

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "terms_accepted": bool(self.terms_accepted),
            "policy_version": self.policy_version,
            "created_at": self.created_at.isoformat(),
        }


class Activity(db.Model):
    """One logged action: a trip, a day's electricity, water use, or waste."""
    __tablename__ = "activities"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    category = db.Column(db.String(20), nullable=False)   # transport | electricity | water | waste
    type = db.Column(db.String(50), nullable=False)       # e.g. car, bus, ac, recycling
    quantity = db.Column(db.Float, nullable=False)
    unit = db.Column(db.String(20), nullable=False)       # km, kWh, litres, kg
    co2_kg = db.Column(db.Float, default=0.0)
    date = db.Column(db.Date, default=date.today, index=True)
    created_at = db.Column(db.DateTime, default=_utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "category": self.category,
            "type": self.type,
            "quantity": self.quantity,
            "unit": self.unit,
            "co2_kg": self.co2_kg,
            "date": self.date.isoformat(),
        }


class EcoScore(db.Model):
    __tablename__ = "eco_scores"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    score = db.Column(db.Integer, nullable=False)          # 0-100
    period = db.Column(db.String(20), nullable=False)      # e.g. 2026-W40
    created_at = db.Column(db.DateTime, default=_utcnow)

# --- Extended features (minimal, safe) ---
class Achievement(db.Model):
    __tablename__ = 'achievements'
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(64), unique=True, nullable=False)
    name = db.Column(db.String(128), nullable=False)
    description = db.Column(db.Text)
    icon = db.Column(db.String(64))
    active = db.Column(db.Boolean, default=True)

class UserAchievement(db.Model):
    __tablename__ = 'user_achievements'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    achievement_id = db.Column(db.Integer, db.ForeignKey('achievements.id'), nullable=False)
    unlocked_at = db.Column(db.DateTime, default=_utcnow)
    __table_args__ = (db.UniqueConstraint('user_id', 'achievement_id', name='uq_user_achievement'),)

class UserStreak(db.Model):
    __tablename__ = 'user_streaks'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, unique=True)
    current_streak = db.Column(db.Integer, default=0)
    longest_streak = db.Column(db.Integer, default=0)
    last_qualifying_date = db.Column(db.Date)

class Goal(db.Model):
    __tablename__ = 'goals'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    title = db.Column(db.String(128), nullable=False)
    metric = db.Column(db.String(32), default='co2')  # co2, electricity, water, waste
    target_value = db.Column(db.Float, nullable=False)
    current_value = db.Column(db.Float, default=0.0)
    unit = db.Column(db.String(16))
    start_date = db.Column(db.Date)
    end_date = db.Column(db.Date)
    status = db.Column(db.String(16), default='active')  # active, completed, expired, cancelled
    created_at = db.Column(db.DateTime, default=_utcnow)

class UserPoints(db.Model):
    __tablename__ = 'user_points'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, unique=True)
    total_points = db.Column(db.Integer, default=0)

class PointsLedger(db.Model):
    __tablename__ = 'points_ledger'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    points = db.Column(db.Integer, nullable=False)
    reason = db.Column(db.String(128))
    created_at = db.Column(db.DateTime, default=_utcnow)

class EcoScoreHistory(db.Model):
    __tablename__ = 'eco_score_history'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    score = db.Column(db.Integer, nullable=False)
    recorded_at = db.Column(db.DateTime, default=_utcnow)

class Challenge(db.Model):
    __tablename__ = 'challenges'
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(32), unique=True, nullable=False)
    title = db.Column(db.String(128), nullable=False)
    description = db.Column(db.Text)
    reward_points = db.Column(db.Integer, default=20)

class UserChallenge(db.Model):
    __tablename__ = 'user_challenges'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    challenge_id = db.Column(db.Integer, db.ForeignKey('challenges.id'), nullable=False)
    started_at = db.Column(db.DateTime, default=_utcnow)


class ChallengePeriod(db.Model):
    __tablename__ = 'challenge_periods'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    challenge_id = db.Column(db.Integer, db.ForeignKey('challenges.id'), nullable=False)
    period_key = db.Column(db.String(16), nullable=False)
    completed = db.Column(db.Boolean, default=False)
    completed_at = db.Column(db.DateTime)
    __table_args__ = (
        db.UniqueConstraint('user_id', 'challenge_id', 'period_key',
                            name='uq_challenge_period'),
    )


class Notification(db.Model):
    """A persisted, user-owned in-app notification.

    ``dedupe_key`` makes generation idempotent: a given event can only create
    one row per user even if the API is polled repeatedly.
    """
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'),
                        nullable=False, index=True)
    code = db.Column(db.String(64), nullable=False)
    type = db.Column(db.String(32), nullable=False, default='info')
    severity = db.Column(db.String(16), nullable=False, default='info')
    title = db.Column(db.String(160), nullable=False)
    body = db.Column(db.Text)
    dedupe_key = db.Column(db.String(160), nullable=False)
    created_at = db.Column(db.DateTime, default=_utcnow)
    read_at = db.Column(db.DateTime)
    dismissed_at = db.Column(db.DateTime)
    __table_args__ = (
        db.UniqueConstraint('user_id', 'dedupe_key', name='uq_notification_dedupe'),
    )


class NotificationPreference(db.Model):
    """Per-user switches for the deterministic notification engine."""
    __tablename__ = 'notification_preferences'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'),
                        nullable=False, unique=True)
    daily_reminder = db.Column(db.Boolean, default=True)
    reminder_hour = db.Column(db.Integer, default=19)
    streak_reminders = db.Column(db.Boolean, default=True)
    challenge_nudges = db.Column(db.Boolean, default=True)
    trend_alerts = db.Column(db.Boolean, default=True)
    achievement_alerts = db.Column(db.Boolean, default=True)
    weekly_summary = db.Column(db.Boolean, default=True)
    updated_at = db.Column(db.DateTime, default=_utcnow, onupdate=_utcnow)

    def to_dict(self):
        return {
            'daily_reminder': bool(self.daily_reminder),
            'reminder_hour': self.reminder_hour,
            'streak_reminders': bool(self.streak_reminders),
            'challenge_nudges': bool(self.challenge_nudges),
            'trend_alerts': bool(self.trend_alerts),
            'achievement_alerts': bool(self.achievement_alerts),
            'weekly_summary': bool(self.weekly_summary),
        }


class TokenBlocklist(db.Model):
    """Revoked JWT ids (refresh tokens). A token is rejected once its jti is here."""
    __tablename__ = 'token_blocklist'

    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(36), nullable=False, unique=True, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'),
                        nullable=False, index=True)
    token_type = db.Column(db.String(16), nullable=False, default='refresh')
    revoked_at = db.Column(db.DateTime, default=_utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)


class PasswordResetToken(db.Model):
    """Single-use password-reset tokens (hash stored, never the raw token)."""
    __tablename__ = 'password_reset_tokens'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'),
                        nullable=False, index=True)
    token_hash = db.Column(db.String(64), nullable=False, unique=True, index=True)
    created_at = db.Column(db.DateTime, default=_utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)
    used_at = db.Column(db.DateTime)
