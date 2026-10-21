"""Periodic cleanup of rows that are no longer needed.

The token blocklist and password-reset tables would otherwise grow without
bound (a refresh every 15 minutes per session, plus every reset request). Rows
past their expiry can never affect an authorization decision, so they are safe
to delete. Run from the scheduler and once at startup.
"""
import logging
from datetime import datetime, timezone

from .extensions import db
from .models import PasswordResetToken, TokenBlocklist

log = logging.getLogger(__name__)


def _utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def prune_expired_tokens():
    """Delete expired blocklist entries and used/expired reset tokens.

    Returns a (blocklist_deleted, reset_tokens_deleted) tuple.
    """
    now = _utcnow()
    blocked = (
        TokenBlocklist.query
        .filter(TokenBlocklist.expires_at < now)
        .delete(synchronize_session=False)
    )
    resets = (
        PasswordResetToken.query
        .filter(
            db.or_(
                PasswordResetToken.expires_at < now,
                PasswordResetToken.used_at.isnot(None),
            )
        )
        .delete(synchronize_session=False)
    )
    db.session.commit()
    if blocked or resets:
        log.info("Pruned %s blocklist and %s reset-token rows", blocked, resets)
    return blocked, resets
