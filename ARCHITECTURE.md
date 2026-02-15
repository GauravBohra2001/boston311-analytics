```markdown
# Architecture Documentation

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

This modeling experience influenced the SQL view design in Supabase.

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

**Database:** Supabase PostgreSQL  
**App Hosting:** Streamlit Cloud

### Issue Encountered

```
Cannot assign requested address
```

**Cause:** Direct host attempted IPv6 connection

**Resolution:** Switched to Supabase pooler host:
```
aws-0-us-west-2.pooler.supabase.com
```

Secrets configured via Streamlit Cloud TOML settings.
```