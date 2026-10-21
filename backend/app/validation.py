"""Shared credential validation."""
import re

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

MIN_PASSWORD_LENGTH = 8
# A small, high-signal denylist of the passwords most abused in credential
# stuffing / spray attacks. Not a substitute for a breach-list service, but it
# blocks the obvious cases without a network dependency.
COMMON_PASSWORDS = {
    "password", "password1", "password123", "passw0rd", "12345678", "123456789",
    "1234567890", "qwerty123", "qwertyui", "letmein", "iloveyou", "admin123",
    "welcome1", "abc12345", "football", "monkey123", "dragon123", "sunshine",
    "princess", "login123", "changeme", "changeme1", "ecotrack", "ecotrack1",
}


def validate_password(password):
    """Return an error string for a weak password, or None if acceptable."""
    if not isinstance(password, str) or len(password) < MIN_PASSWORD_LENGTH:
        return "Password is too short; please use a longer password"
    if password.lower() in COMMON_PASSWORDS:
        return "Password is too common; choose something less guessable"
    if len(set(password)) < 4:
        return "Password must use more distinct characters"
    return None


def normalize_email(email):
    return (email or "").strip().lower()


def is_valid_email(email):
    return bool(email) and bool(EMAIL_RE.match(email))
