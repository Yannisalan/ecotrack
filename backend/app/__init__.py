from flask import Flask, jsonify
from sqlalchemy import text
from werkzeug.middleware.proxy_fix import ProxyFix
from config import Config
from .extensions import db, jwt, cors, limiter


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Trust the configured number of reverse proxies so request.remote_addr
    # (and therefore rate limiting) reflects the real client, not the balancer.
    hops = int(app.config.get("PROXY_FIX_HOPS") or 0)
    if hops:
        app.wsgi_app = ProxyFix(
            app.wsgi_app, x_for=hops, x_proto=hops, x_host=hops, x_port=hops
        )

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

    # The API always answers in JSON, never HTML error pages
    @app.errorhandler(404)
    def not_found(e):
        return jsonify(error="Not found"), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify(error="Method not allowed"), 405

    @app.errorhandler(413)
    def too_large(e):
        limit_mb = round(app.config["MAX_CONTENT_LENGTH"] / (1024 * 1024), 2)
        return jsonify(error=f"Request body too large (limit {limit_mb} MB)"), 413

    @app.errorhandler(429)
    def too_many_requests(e):
        resp = jsonify(error="Too many requests. Please slow down.")
        retry_after = getattr(e, "retry_after", None)
        if retry_after:
            resp.headers["Retry-After"] = str(retry_after)
        return resp, 429

    @app.errorhandler(500)
    def server_error(e):
        db.session.rollback()
        return jsonify(error="Internal server error"), 500

    @app.after_request
    def security_headers(resp):
        # JSON API hardening. HSTS is left to the TLS terminator (Render).
        resp.headers.setdefault("X-Content-Type-Options", "nosniff")
        resp.headers.setdefault("X-Frame-Options", "DENY")
        resp.headers.setdefault("Referrer-Policy", "no-referrer")
        resp.headers.setdefault("Cache-Control", "no-store")
        return resp

    @jwt.unauthorized_loader
    def missing_token(reason):
        return jsonify(error="Missing or invalid Authorization header"), 401

    @jwt.invalid_token_loader
    def invalid_token(reason):
        return jsonify(error="Invalid token"), 401

    @jwt.expired_token_loader
    def expired_token(jwt_header, jwt_payload):
        return jsonify(error="Token has expired"), 401

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
        return jsonify(error="Token has been revoked"), 401

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