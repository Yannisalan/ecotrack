"""Redacted secret scanner. Reports file:line:kind only - never the value."""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # repository root

SKIP_DIRS = {
    ".git", "build", ".dart_tool", "node_modules", "__pycache__",
    ".pytest_cache", ".gradle", ".idea", "ios", "ephemeral",
}
SKIP_SUFFIX = {".png", ".jpg", ".jpeg", ".ico", ".jar", ".keystore", ".class", ".lock"}

PATTERNS = [
    ("JWT_SECRET_ASSIGN", re.compile(r"JWT_SECRET_KEY\s*[=:]\s*\S+")),
    ("DB_URL_ASSIGN", re.compile(r"DATABASE_URL\s*[=:]\s*\S+")),
    ("DB_PASSWORD_ASSIGN", re.compile(r"DB_PASSWORD\s*[=:]\s*\S+")),
    ("NEON_URL", re.compile(r"postgres(?:ql)?://[^\s'\"]+")),
    ("AWS_KEY", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("PRIVATE_KEY_BLOCK", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("GENERIC_SECRET_ASSIGN", re.compile(
        r"(?i)\b(secret|api[_-]?key|apikey|access[_-]?token|password|passwd|"
        r"private[_-]?key|auth[_-]?token)\b\s*[=:]\s*['\"][^'\"]{6,}['\"]")),
    ("BEARER_LITERAL", re.compile(r"(?i)bearer\s+[a-z0-9\-._~+/]{20,}")),
    ("NPM_TOKEN", re.compile(r"npm_[A-Za-z0-9]{30,}")),
    ("GH_TOKEN", re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}")),
    ("SLACK_TOKEN", re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")),
    ("STRIPE_KEY", re.compile(r"[sr]k_(?:live|test)_[A-Za-z0-9]{20,}")),
    ("OPENAI_KEY", re.compile(r"sk-[A-Za-z0-9]{20,}")),
    ("GOOGLE_API_KEY", re.compile(r"AIza[0-9A-Za-z\-_]{35}")),
]

# Values that are obviously placeholders / examples, not real secrets.
PLACEHOLDER = re.compile(
    r"^(\s*)$|^(your|change-me|changeme|placeholder|example|xxx+|\.\.\.|"
    r"<[^>]*>|\$\{[^}]*\}|%s|\{\{[^}]*\}\}|null|none|true|false|"
    r"user:password|user|password|host|dbname|localhost|127\.0\.0\.1)",
    re.IGNORECASE,
)


def is_placeholder(value: str) -> bool:
    v = value.strip().strip("'\"")
    if not v:
        return True
    if PLACEHOLDER.match(v):
        return True
    if v.lower() in {"true", "false", "0", "1", "none", "null"}:
        return True
    # Obviously a template token, e.g. YOUR-RENDER-SERVICE, ${...}
    if re.search(r"(?i)your|example|placeholder|todo|xxx|changeme|change-me|replace", v):
        return True
    return False


def iter_files():
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if p.suffix.lower() in SKIP_SUFFIX:
            continue
        if p.name == ".env":
            # Real .env: report only the KEY NAMES, never the values.
            yield p, "env-file"
            continue
        yield p, "text"


def main():
    findings = []
    for path, kind in iter_files():
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        rel = path.relative_to(ROOT).as_posix()
        if kind == "env-file":
            for i, line in enumerate(text.splitlines(), 1):
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key = line.split("=", 1)[0].strip()
                if re.match(r"^[A-Z0-9_]+$", key):
                    findings.append((rel, i, "ENV_KEY_PRESENT", key))
            continue
        for i, line in enumerate(text.splitlines(), 1):
            if len(line) > 2000:
                continue
            for name, rx in PATTERNS:
                m = rx.search(line)
                if not m:
                    continue
                raw = m.group(0)
                # For assignment-style patterns, look at the assigned value.
                value = raw.split("=", 1)[-1] if "=" in raw else raw
                value = value.split(":", 1)[-1] if (":" in value and "://" not in value) else value
                if is_placeholder(value):
                    continue
                findings.append((rel, i, name, "<redacted>"))

    if not findings:
        print("NO_SECRET_HITS")
        return 0
    print(f"HITS: {len(findings)}")
    for rel, line, kind, extra in findings:
        print(f"{rel}:{line}: {kind} {extra}".rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
