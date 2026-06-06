# Architecture Documentation

## Architecture Flow

```text
Boston 311 (2024 CSV)
        |
        v
Python Cleaning (pandas)
        |
        v
Azure Data Studio (local Postgres testing)
        |
        v
VM + Power BI (semantic modeling)
        |
        v
Managed PostgreSQL Hosting
  - Supabase (initial hosted deployment)
  - Neon (current production deployment)
        |
        v
Analytical Views
  - v_kpi_monthly_city_2024
  - v_kpi_monthly_zip_2024
        |
        v
Streamlit App (app/app.py)
        |
        v
Streamlit Cloud Deployment
        |
        v
page_views logging (session_id + UUID tracking)
```

## Hosting Evolution

The project went through three distinct stages:

1. Local data cleaning and warehouse design
2. Initial cloud deployment on Supabase
3. Production migration to Neon

That evolution matters because the final architecture was shaped by both data-modeling needs and hosting constraints.

## Initial Migration to Supabase

The project originally began in a local development environment:
1. Data extracted and cleaned in Python
2. Loaded into PostgreSQL via Azure Data Studio
3. Modeled inside a Windows VM using Power BI
4. Semantic model validated KPI definitions and aggregations

However, a public application needed a managed cloud database.

### Migration Steps

- Created a Supabase PostgreSQL instance
- Recreated raw table schema
- Rebuilt analytical SQL views
- Migrated cleaned dataset
- Connected Streamlit to Supabase

### Issue Encountered — IPv6 Connection Failure

Initial deployment used the direct Supabase host.

**Error:**
```
Cannot assign requested address
```

**Cause:** Direct host attempted IPv6 connection not supported by Streamlit Cloud environment

**Fix:** Switched to Supabase connection pooler host:
```
aws-0-us-west-2.pooler.supabase.com
```

This resolved connectivity issues.

### Secrets Management

- Database credentials stored in Streamlit Cloud Secrets
- No credentials committed to repository
- Environment variables managed securely via TOML

### Final State

- Stable pooled connection
- Hosted PostgreSQL
- Streamlit Cloud deployment
- Session-based logging architecture

This migration reflects real-world production debugging and deployment iteration.

## Migration from Supabase to Neon

The Supabase deployment worked technically, but it introduced a portfolio-hosting issue: the free-tier inactivity model could leave the public app showing a database error until the database was manually resumed.

For a resume project, that failure mode is worse than a cold start. The project needed a hosted Postgres provider that:

- preserved the existing SQL + `psycopg2` application design
- did not require a database rewrite
- reduced manual operational intervention
- still fit within a free-tier budget

### Why Neon

Neon was chosen because it kept the PostgreSQL contract intact while improving the operational behavior:

- same app-side connection model (`psycopg2`)
- same `public.*` tables and views
- pooled connection support for hosted apps
- automatic wake-up behavior on the free tier
- lower operational risk than a manually resumable free-tier database

### Migration Steps

1. Created a Neon project in `AWS US East 1`
2. Attempted provider-side import from Supabase
3. Fell back to manual `pg_dump` / `pg_restore` when automatic import failed
4. Verified app-critical objects after restore:
   - `public.cases_analytics_2024`
   - `public.page_views`
   - `public.v_kpi_monthly_city_2024`
   - `public.v_kpi_monthly_zip_2024`
   - `public.v_product_zip_latest_2024`
   - `public.v_top5_issues_zip_monthly_2024`
5. Switched Streamlit Cloud secrets to the Neon pooled `DATABASE_URL`
6. Added retry logic in the app to tolerate cold-start wakeups

### Migration Lesson

The important engineering decision was to migrate the provider, not the architecture.

That kept the project stable:
- no dashboard rewrite
- no analytics logic rewrite
- no schema redesign
- minimal application-code change

The only unsupported restore objects were Supabase-specific extensions and realtime internals, which were not part of the Streamlit app contract.

---

## 1. Data Extraction & Cleaning

**Source:** Boston 311 Open Data (2024)

Cleaning performed in Python:
- Standardized datetime formats
- Normalized ZIP codes
- Removed malformed entries
- Standardized SLA status fields
- Ensured consistent casing and null handling

### Edge Case: Corrupted ZIP Codes

Some ZIP values were incorrectly stored inside the source column:

**Example:**
```
02132,42.29,-71.15,Constituent Call
```

**Resolution:**
```sql
update cases_analytics_2024
set location_zipcode = split_part(source, ',', 1)
where ...
```

All ZIPs validated using regex: `^[0-9]{5}$`

---

## 2. Warehouse Schema

### Raw Table

`cases_analytics_2024`

**Includes:**
- `case_id` (primary key)
- `open_date`
- `closed_date`
- `location_zipcode`
- SLA fields
- Geographic metadata

**Indexes created on:**
- `location_zipcode`
- `open_date`
- `case_id`

### Type Mismatch Issue

**Encountered:**
```
operator does not exist: text = bigint
```

**Cause:** `case_id` type mismatch in update statement

**Resolution:** Explicit casting and schema normalization

---

## 3. Analytical Layer

**Views created:**
- `v_kpi_monthly_city_2024`
- `v_kpi_monthly_zip_2024`

**Metrics computed:**
- Total requests
- Open requests
- Closed requests
- Median resolution hours
- SLA eligible cases
- SLA met rate

### Why Views Instead of Raw Queries?

- Separation of concerns
- Reusable aggregation logic
- Cleaner application layer
- Easier optimization later

---

## 4. Power BI Semantic Model

Before hosting in Streamlit, a semantic model was built in Power BI.

**Design decisions:**
- Fact table: 311 cases
- Date dimension (derived)
- ZIP dimension
- **Measures defined:**
  - SLA compliance
  - Median resolution
  - Open backlog
  - Monthly totals

**Purpose:** Demonstrate dimensional modeling and DAX-based measure design

This modeling experience influenced the SQL view design in the hosted PostgreSQL layer.

---

## 5. Application Layer (Streamlit)

**Pages:**
- City Overview
- Find My Area (ZIP comparison)

**Design:**
- All metrics pulled from SQL views
- No heavy computation in app layer
- Month filtering applied at query level

---

## 6. Logging Architecture

### Initial Issue

Streamlit reruns script on:
- Initial load
- Widget interaction
- Layout changes

Naive logging caused inflated counts.

### Solution

**Implemented:** `log_once()`

**Using:**
- `st.session_state`
- UUID-based `session_id`

**Tracked:**
- `page`
- `zip_selected`
- `user_agent`
- `session_id`
- `visited_at`

**Supports:**
- Total views
- Unique sessions
- Page analytics

---

## 7. Hosting Architecture

**Database:** Neon PostgreSQL  
**App Hosting:** Streamlit Cloud

### Current Runtime Behavior

- Streamlit Cloud hosts the application
- Neon hosts the database
- App queries run against prebuilt analytical views
- Logging writes into `public.page_views`

### Current Hosting Tradeoff

Neon free-tier compute can cold start after inactivity, so the first request can be slower. That tradeoff is acceptable because it is materially better than a manually resumed database for a public portfolio project.

### Application Hardening

The app connection layer now retries database connection attempts before surfacing a failure. This reduces visible errors during provider wake-up windows.

### Operational Notes

- Hosted secret source: Streamlit Cloud secrets
- Local secret source: `.streamlit/secrets.toml` (gitignored)
- Runtime connection preference: pooled connection string for hosted deployment
