-- Aegis Trader - PostgreSQL initialization
-- Creates the base schema and enables required extensions

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Tenant isolation: all tenant-owned tables will include tenant_id
-- This init script sets up the database; schema migrations will be handled
-- by the application (Alembic) in later phases.