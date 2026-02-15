# Change Log

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