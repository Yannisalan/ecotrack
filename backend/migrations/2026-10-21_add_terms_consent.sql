-- Migration: terms/privacy consent on accounts
-- Adds consent tracking to the `users` table.
-- Idempotent and safe to run on a live database (PostgreSQL).
--
-- The application also applies these statements automatically at startup
-- (see backend/app/__init__.py); this file is provided for manual/CI runs.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS policy_version VARCHAR(20);
