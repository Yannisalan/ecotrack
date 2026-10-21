"""Central, friendly JSON error handling for the API.

Every error the API emits is a JSON body of the form ``{"error": "..."}``
carrying a short, calm, jargon-free message that is safe to show to a user.
Technical detail (exception, traceback) is logged server-side and never sent.

Register with :func:`register_error_handlers` from ``create_app``.
"""

from flask import jsonify, request
from werkzeug.exceptions import HTTPException
from .extensions import db


# --- Friendly wording (single source of truth) ----------------------------
MSG_NOT_FOUND = "Sorry, we couldn't find what you were looking for."
MSG_METHOD_NOT_ALLOWED = "Sorry, that action isn't supported."
MSG_UNAUTHORIZED = "Your session has expired. Please log in again."
MSG_FORBIDDEN = "Sorry, you don't have permission to do that."
MSG_CONFLICT = "That didn't work because it already exists."
MSG_BAD_REQUEST = (
    "Sorry, we couldn't process that request. "
    "Please check your details and try again."
)
MSG_TOO_MANY = "Too many attempts. Please wait a moment and try again."
MSG_TOO_LARGE = "That file is too large. Please choose a smaller one."
MSG_SERVER = (
    "Sorry, we encountered an error on our side. Please try again in a moment."
)
MSG_MISSING_TOKEN = MSG_UNAUTHORIZED
MSG_INVALID_TOKEN = MSG_UNAUTHORIZED
MSG_EXPIRED_TOKEN = MSG_UNAUTHORIZED
MSG_REVOKED_TOKEN = MSG_UNAUTHORIZED


def _log(app, event, exc=None):
    """Log the real, technical detail for developers only."""
    if exc is not None:
        app.logger.warning("%s: %s", event, exc)
    else:
        app.logger.warning("%s", event)


def register_error_handlers(app):
    """Attach global JSON error handlers to ``app``.

    Covers the status codes the UI maps to friendly copy (400, 401, 403, 404,
    405, 409, 413, 429, 500) plus a catch-all so no request can ever return an
    HTML error page or an unhandled traceback.
    """

    @app.errorhandler(400)
    def bad_request(e):
        _log(app, "400 Bad Request", e)
        return jsonify(error=MSG_BAD_REQUEST), 400

    @app.errorhandler(401)
    def unauthorized(e):
        return jsonify(error=MSG_UNAUTHORIZED), 401

    @app.errorhandler(403)
    def forbidden(e):
        return jsonify(error=MSG_FORBIDDEN), 403

    @app.errorhandler(404)
    def not_found(e):
        _log(app, f"404 Not Found: {request.path}")
        return jsonify(error=MSG_NOT_FOUND), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        _log(app, f"405 Method Not Allowed: {request.method} {request.path}")
        return jsonify(error=MSG_METHOD_NOT_ALLOWED), 405

    @app.errorhandler(409)
    def conflict(e):
        _log(app, "409 Conflict", e)
        return jsonify(error=MSG_CONFLICT), 409

    @app.errorhandler(413)
    def too_large(e):
        return jsonify(error=MSG_TOO_LARGE), 413

    @app.errorhandler(429)
    def too_many_requests(e):
        resp = jsonify(error=MSG_TOO_MANY)
        retry_after = getattr(e, "retry_after", None)
        if retry_after:
            resp.headers["Retry-After"] = str(retry_after)
        return resp, 429

    @app.errorhandler(500)
    def server_error(e):
        db.session.rollback()
        app.logger.exception("500 Internal Server Error")
        return jsonify(error=MSG_SERVER), 500

    @app.errorhandler(HTTPException)
    def http_exception(e):
        # Any other Werkzeug HTTP error keeps its status but gets friendly copy
        # (never the HTML page Werkzeug would render by default).
        _log(app, f"{e.code} HTTPException", e.description)
        code = e.code or 500
        if code == 401:
            message = MSG_UNAUTHORIZED
        elif code == 403:
            message = MSG_FORBIDDEN
        elif code == 404:
            message = MSG_NOT_FOUND
        elif code == 405:
            message = MSG_METHOD_NOT_ALLOWED
        elif code == 409:
            message = MSG_CONFLICT
        elif code == 429:
            message = MSG_TOO_MANY
        elif code >= 500:
            message = MSG_SERVER
        else:
            message = MSG_BAD_REQUEST
        return jsonify(error=message), code

    @app.errorhandler(Exception)
    def unhandled(e):
        # Last resort: never leak an exception or stack trace to the client.
        db.session.rollback()
        app.logger.exception("Unhandled exception")
        return jsonify(error=MSG_SERVER), 500
