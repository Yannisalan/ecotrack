"""Background jobs (APScheduler).

Two jobs share one scheduler:
- a daily token purge (always on: keeps the blocklist/reset tables small), and
- an hourly reminder materialization, opt-in via REMINDER_SCHEDULER=true.

Tests never start the scheduler; it is only wired up by create_app().
"""
import logging

from apscheduler.schedulers.background import BackgroundScheduler

log = logging.getLogger(__name__)

_scheduler = None


def start_scheduler(app):
    """Start one background scheduler bound to this app (idempotent)."""
    global _scheduler
    if _scheduler is not None:
        return _scheduler

    def _prune_job():
        from .maintenance import prune_expired_tokens

        with app.app_context():
            prune_expired_tokens()

    _scheduler = BackgroundScheduler(timezone="UTC")
    _scheduler.add_job(
        _prune_job,
        trigger="interval",
        hours=24,
        id="token-purge",
        max_instances=1,
        coalesce=True,
    )

    if app.config.get("REMINDER_SCHEDULER"):
        def _reminder_job():
            from .notification_service import materialize_all

            with app.app_context():
                processed = materialize_all()
            log.info("Reminder materialization ran for %s user(s)", processed)

        _scheduler.add_job(
            _reminder_job,
            trigger="interval",
            hours=1,
            id="reminder-materialize",
            max_instances=1,
            coalesce=True,
        )

    _scheduler.start()
    app.logger.info(
        "Background scheduler started (purge daily, reminders=%s)",
        bool(app.config.get("REMINDER_SCHEDULER")),
    )
    return _scheduler


def stop_scheduler():
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
