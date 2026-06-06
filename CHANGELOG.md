# Change Log

## Neon Migration

- Migrated hosted PostgreSQL from Supabase to Neon
- Chose provider migration instead of rewriting the application architecture
- Used manual `pg_dump` / `pg_restore` after automatic import failed
- Verified all app-critical `public.*` views and tables after restore
- Switched Streamlit Cloud secrets to a pooled Neon `DATABASE_URL`
- Added connection retry logic to handle cold-start wakeups more gracefully

## ZIP Corruption Issue

- Discovered malformed ZIP values stored inside source
- Corrected using SQL string split

## Type Mismatch Error

- `text` vs `bigint` comparison on `case_id`
- Resolved with explicit casting

## Supabase IPv6 Connection Error

- Direct host failed
- Switched to pooler connection

## Logging Inflation Bug

- Naive logging caused multiple entries per session
- Implemented `log_once()` with session tracking

## Session ID Tracking Added

- Added UUID per session
- Enabled unique session analytics
