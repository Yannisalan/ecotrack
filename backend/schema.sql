-- Run once (PostgreSQL has no CREATE DATABASE IF NOT EXISTS).
-- Tables are created automatically by SQLAlchemy when the app starts.
CREATE DATABASE ecotrack ENCODING 'UTF8';

-- Consent columns on `users` (see migrations/2026-10-21_add_terms_consent.sql).
-- Applied automatically at startup; listed here for a fresh manual setup.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP;
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS policy_version VARCHAR(20);
