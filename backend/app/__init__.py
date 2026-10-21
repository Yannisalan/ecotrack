import os

from flask import Flask, jsonify, request
from sqlalchemy import text
from werkzeug.middleware.proxy_fix import ProxyFix
from config import Config
from .extensions import db, jwt, cors, limiter


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Trust the configured number of reverse proxies so request.remote_addr
    # (and therefore rate limiting) reflects the real client, not the balancer.
    # ProxyFix is only applied when the count is greater than zero, so a
    # direct connection never trusts a spoofable X-Forwarded-For header.
    hops = int(app.config.get("PROXY_FIX_HOPS") or 0)
    if hops:
        app.wsgi_app = ProxyFix(
            app.wsgi_app, x_for=hops, x_proto=hops, x_host=hops, x_port=hops
        )
    else:
        app.logger.info(
            "PROXY_FIX_HOPS=0: X-Forwarded-For is not trusted, so rate limits "
            "are keyed on the direct peer address."
        )

    # The rate limiter's counter store. "memory://" is per-process: counters
    # reset on every restart and every worker keeps its own set. That is fine
    # for the single-worker deployment (render.yaml pins --workers 1) but it
    # must not be silent.
    storage_uri = str(app.config.get("RATELIMIT_STORAGE_URI") or "memory://")
    if storage_uri.strip().lower().startswith("memory"):
        workers = (os.getenv("WEB_CONCURRENCY") or "1").strip()
        try:
            worker_count = int(workers)
        except ValueError:
            worker_count = 1
        message = (
            "RATELIMIT_STORAGE_URI is 'memory://': rate limits are counted per "
            "process and reset on every restart. With %d worker(s) each worker "
            "keeps its own counters, so a client can multiply its effective "
            "limit by the worker count. Point RATELIMIT_STORAGE_URI at a "
            "shared store (for example 'redis://HOST:PORT/0', which also needs "
            "the 'redis' package) before running more than one worker."
        ) % worker_count
        if worker_count > 1:
            app.logger.warning(message)
        else:
            app.logger.info(message)

    db.init_app(app)
    jwt.init_app(app)
    # Flask-Limiter is a module-level singleton; reset `enabled` from this
    # app's config so a later app (e.g. a test with rate limiting on) is not
    # stuck with an earlier app's setting.
    limiter.enabled = bool(app.config.get("RATELIMIT_ENABLED", True))
    limiter.init_app(app)
    cors.init_app(
        app,
        resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}},
        allow_headers=["Content-Type", "Authorization", "X-Client-Platform"],
        methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        # The web client refreshes with an HttpOnly cookie, so credentialed
        # cross-origin calls are required. This is safe only because the
        # allowlist contains exact origins: it can never contain a wildcard.
        supports_credentials=True,
    )

    from .auth import auth_bp
    from .activities import activities_bp
    from .stats import stats_bp
    from .achievements import achievements_bp
    from .goals import goals_bp
    from .reports import reports_bp
    from .challenges import challenges_bp
    from .notifications import notifications_bp
    from .insights import insights_bp
    app.register_blueprint(auth_bp)
    app.register_blueprint(activities_bp)
    app.register_blueprint(stats_bp)
    app.register_blueprint(achievements_bp)
    app.register_blueprint(goals_bp)
    app.register_blueprint(reports_bp)
    app.register_blueprint(challenges_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(insights_bp)

    @app.get("/api/health")
    def health():
        return jsonify(status="ok")

    # Central, friendly JSON error handling (400/401/403/404/405/409/413/429/500
    # + catch-all). See app/errors.py — the API never returns an HTML error page.
    from .errors import (
        register_error_handlers,
        MSG_UNAUTHORIZED,
    )
    register_error_handlers(app)

    @app.after_request
    def security_headers(resp):
        # JSON API hardening.
        resp.headers.setdefault("X-Content-Type-Options", "nosniff")
        resp.headers.setdefault("X-Frame-Options", "DENY")
        # The API only ever returns JSON, so it can afford the strictest
        # policy: no scripts, no plugins, no outbound connections, no framing.
        resp.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
        )
        # Never leak API paths to third parties. ("no-referrer" is already the
        # strictest referrer policy; it stays.)
        resp.headers.setdefault("Referrer-Policy", "no-referrer")
        resp.headers.setdefault("Cache-Control", "no-store")
        # HSTS is only meaningful once the connection is already HTTPS.
        # Sending it over plain http is ignored by browsers, and a stray
        # header on a local http request can lock a developer out of
        # localhost. ProxyFix already restores the original scheme here.
        if request.is_secure and "Strict-Transport-Security" not in resp.headers:
            resp.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return resp

    @jwt.unauthorized_loader
    def missing_token(reason):
        return jsonify(error=MSG_UNAUTHORIZED), 401

    @jwt.invalid_token_loader
    def invalid_token(reason):
        return jsonify(error=MSG_UNAUTHORIZED), 401

    @jwt.expired_token_loader
    def expired_token(jwt_header, jwt_payload):
        return jsonify(error=MSG_UNAUTHORIZED), 401

    @jwt.token_in_blocklist_loader
    def is_token_revoked(jwt_header, jwt_payload):
        from .models import TokenBlocklist, User
        jti = jwt_payload.get("jti")
        jti_revoked = False
        if jti:
            jti_revoked = (
                db.session.query(TokenBlocklist.id).filter_by(jti=jti).first()
                is not None
            )
        if jti_revoked:
            return True
        # A password reset/change bumps users.token_version, invalidating every
        # token issued before it. This runs for access AND refresh tokens.
        # A token minted before the column existed has no tv claim and is
        # treated as version 0, so it is rejected as soon as the user's version
        # is bumped above 0 (rather than being exempt forever).
        sub = jwt_payload.get("sub")
        if not sub:
            return False
        user = db.session.get(User, int(sub))
        if user is None:
            return False
        tv = jwt_payload.get("tv", 0)
        try:
            return int(tv) != int(user.token_version or 0)
        except (TypeError, ValueError):
            return True

    @jwt.revoked_token_loader
    def revoked_token(jwt_header, jwt_payload):
        return jsonify(error=MSG_UNAUTHORIZED), 401

    with app.app_context():
        from . import models  # noqa: F401
        db.create_all()
        # db.create_all() creates missing tables but never adds columns to
        # existing ones; token_version is new on `users`. Idempotent on
        # Postgres; SQLite test databases are created fresh above.
        if db.engine.dialect.name == "postgresql":
            db.session.execute(text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0"
            ))
            # Terms/Privacy consent captured at registration.
            db.session.execute(text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT FALSE"
            ))
            db.session.execute(text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP"
            ))
            db.session.execute(text(
                "ALTER TABLE users "
                "ADD COLUMN IF NOT EXISTS policy_version VARCHAR(20)"
            ))
            db.session.commit()
        # Clear already-expired blocklist/reset rows on every boot (cheap).
        from .maintenance import prune_expired_tokens
        try:
            prune_expired_tokens()
        except Exception:  # pragma: no cover - never block startup on cleanup
            db.session.rollback()
            app.logger.exception("Startup token prune failed")

    if app.config.get("ENABLE_SCHEDULER") and not app.config.get("TESTING"):
        from .scheduler import start_scheduler
        start_scheduler(app)

    return app