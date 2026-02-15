
# Power BI Semantic Modeling Layer

Before building the hosted Streamlit application, a semantic model was created in Power BI.

## Why a Semantic Model Was Built

Before building the hosted application, the dataset was modeled inside Power BI to:
- Validate aggregation logic
- Test KPI definitions
- Design relationships between dimensions
- Simulate a business intelligence layer
- Ensure metrics were correct before moving to production hosting

The semantic model acted as a validation layer for the analytical logic later implemented in PostgreSQL views.

---

## Fact Table Design

**Primary fact table:** `cases_analytics_2024`

**Grain:** One row per 311 service request

**Key fields:**
- `case_id` (Primary Key)
- `open_date`
- `closed_date`
- `location_zipcode`
- `department`
- `case_status`
- `on_time` (SLA met flag)
- `resolution_time_hours` (derived)

This table served as the transactional layer.

---

## Relationship Design

The model followed a star-schema-inspired structure:

**Fact:**
- `cases_analytics_2024`

**Dimensions:**
- Date (derived from `open_date`)
- ZIP / Location
- Department
- Service Type

**Relationships:**
- Date table linked via `open_date` (many-to-one)
- ZIP linked via `location_zipcode`
- Department linked via `assigned_department`

This separation ensured:
- Clean aggregations
- Controlled filter propagation
- Accurate monthly KPI calculations

---

## Date Table Logic

A dedicated date table was used (or auto-generated via Power BI) to:
- Support monthly grouping
- Enable time intelligence
- Ensure consistent month-based aggregations

Month-level aggregation was later mirrored in PostgreSQL using:
```sql
date_trunc('month', open_date)


This allowed seamless migration of logic from Power BI to SQL views.

---

## KPI Measure Definitions

Key measures defined in Power BI:

**Total Requests**
- Count of `case_id`

**Open Requests**
- Count of `case_id` where `case_status != 'Closed'`

**Closed Requests**
- Count of `case_id` where `case_status = 'Closed'`

**Median Resolution (Hours)**
- Median of `resolution_time_hours`

**SLA Eligible Cases**
- Count where SLA target exists

**SLA Compliance Rate**
- SLA met cases / SLA eligible cases

These definitions were later replicated in PostgreSQL analytical views for production consistency.

---

## Why Power BI Was Not Used for Hosting

Power BI was used for modeling and validation but not chosen for hosting because:
- Public sharing limitations
- Authentication constraints
- Lack of lightweight public access
- Less control over backend database logic
- No granular logging capability
- Not suited for open public deployment

The goal was to build a system with:
- Direct database-backed queries
- Controlled SQL logic
- Custom logging architecture
- Scalable cloud deployment

---

## Why Migration to Supabase + Streamlit

The project evolved into a hosted analytics system:

**Supabase was chosen because:**
- Managed PostgreSQL
- Cloud-native
- Production-grade infrastructure
- Easy connection pooling
- SQL view compatibility

**Streamlit was chosen because:**
- Rapid application layer development
- Direct database querying
- Custom logging control
- Lightweight deployment on Streamlit Cloud

This migration transformed the project from:  
**A BI dashboard → to a hosted analytics application with logging + session tracking**

---

## Model Structure

**Fact Table:**
- 311 service requests

**Dimensions:**
- Date
- ZIP
- Department (if applicable)

## Key Measures

- Total Requests
- Open Requests
- Closed Requests
- SLA Compliance Rate
- Median Resolution Time

## Design Influence

The Power BI model informed:
- SQL view structure
- Monthly aggregation logic
- SLA eligibility calculation

This ensured consistency between BI tool logic and database logic.
```
