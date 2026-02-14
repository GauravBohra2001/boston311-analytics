/* =========================================================
   FINAL VIEW PACK FOR 2024 CASES ANALYTICS (MSSQL)
   Dependency order: base -> KPIs -> rolling -> product
   ========================================================= */

------------------------------------------------------------
-- 1) BASE SEMANTIC VIEW (FACT ENRICHMENT)
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_cases_enriched_2024 AS
SELECT
  case_id,
  system_generated_id,
  open_date,
  sla_target_date,
  closed_date,
  on_time,
  case_status,
  closure_reason,
  case_topic,
  assigned_department,
  assigned_team,
  service_name,
  queue,
  assignment_department,
  location,
  location_street_name,
  location_zipcode,
  neighborhood,
  ward,
  precinct,
  fire_district,
  public_works_district,
  city_council_district,
  police_district,
  neighborhood_services_district,
  latitude,
  longitude,
  source,

  CASE WHEN closed_date IS NULL OR case_status <> 'Closed' THEN 1 ELSE 0 END AS is_open,
  CASE WHEN closed_date IS NOT NULL AND case_status = 'Closed' THEN 1 ELSE 0 END AS is_closed,

  /* Only compute for closed cases to keep medians safe */
  CASE
    WHEN closed_date IS NOT NULL AND case_status = 'Closed'
    THEN DATEDIFF(hour, open_date, closed_date)
    ELSE NULL
  END AS resolution_hours,

  CASE WHEN sla_target_date IS NOT NULL THEN 1 ELSE 0 END AS sla_eligible,

  CASE
    WHEN sla_target_date IS NULL THEN NULL
    WHEN closed_date IS NULL OR case_status <> 'Closed' THEN NULL
    WHEN closed_date <= sla_target_date THEN 1
    ELSE 0
  END AS sla_met,

  DATEFROMPARTS(YEAR(open_date), MONTH(open_date), 1) AS open_month
FROM dbo.cases_analytics_2024;
GO


------------------------------------------------------------
-- 2) KPI: MONTHLY BY ZIP
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_kpi_monthly_zip_2024 AS
WITH base AS (
  SELECT
    open_month,
    location_zipcode,
    is_open,
    is_closed,
    resolution_hours,
    sla_eligible,
    sla_met,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)
      OVER (PARTITION BY open_month, location_zipcode) AS median_resolution_hours
  FROM dbo.v_cases_enriched_2024
  WHERE location_zipcode IS NOT NULL
    -- IMPORTANT: include all cases (open + closed)
    -- median will still be safe because resolution_hours is NULL for open cases
)
SELECT
  open_month,
  location_zipcode,
  COUNT(*) AS total_requests,
  SUM(is_open) AS open_requests,
  SUM(is_closed) AS closed_requests,
  MAX(median_resolution_hours) AS median_resolution_hours,
  SUM(CASE WHEN sla_eligible = 1 THEN 1 ELSE 0 END) AS sla_eligible_cases,
  CAST(
    AVG(CASE WHEN sla_met IS NULL THEN NULL ELSE CAST(sla_met AS float) END)
    AS float
  ) AS sla_met_rate
FROM base
GROUP BY open_month, location_zipcode;
GO


------------------------------------------------------------
-- 3) KPI: MONTHLY CITY
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_kpi_monthly_city_2024 AS
WITH base AS (
  SELECT
    open_month,
    is_open,
    is_closed,
    resolution_hours,
    sla_eligible,
    sla_met,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)
      OVER (PARTITION BY open_month) AS median_resolution_hours
  FROM dbo.v_cases_enriched_2024
  WHERE location_zipcode IS NOT NULL
    -- IMPORTANT: include all cases (open + closed)
)
SELECT
  open_month,
  COUNT(*) AS total_requests,
  SUM(is_open) AS open_requests,
  SUM(is_closed) AS closed_requests,
  MAX(median_resolution_hours) AS median_resolution_hours,
  SUM(CASE WHEN sla_eligible = 1 THEN 1 ELSE 0 END) AS sla_eligible_cases,
  CAST(
    AVG(CASE WHEN sla_met IS NULL THEN NULL ELSE CAST(sla_met AS float) END)
    AS float
  ) AS sla_met_rate
FROM base
GROUP BY open_month;
GO


------------------------------------------------------------
-- 4) OPTIONAL KPI: MONTHLY AREA (NEIGHBORHOOD + ZIP)
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_kpi_monthly_area_2024 AS
WITH base AS (
  SELECT
    open_month,
    neighborhood,
    location_zipcode,
    is_open,
    is_closed,
    resolution_hours,
    sla_eligible,
    sla_met,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)
      OVER (PARTITION BY open_month, neighborhood, location_zipcode) AS median_resolution_hours
  FROM dbo.v_cases_enriched_2024
  WHERE (neighborhood IS NOT NULL OR location_zipcode IS NOT NULL)
    -- IMPORTANT: include all cases (open + closed)
)
SELECT
  open_month,
  neighborhood,
  location_zipcode,
  COUNT(*) AS total_requests,
  SUM(is_open) AS open_requests,
  SUM(is_closed) AS closed_requests,
  MAX(median_resolution_hours) AS median_resolution_hours,
  SUM(CASE WHEN sla_eligible = 1 THEN 1 ELSE 0 END) AS sla_eligible_cases,
  CAST(
    AVG(CASE WHEN sla_met IS NULL THEN NULL ELSE CAST(sla_met AS float) END)
    AS float
  ) AS sla_met_rate
FROM base
GROUP BY open_month, neighborhood, location_zipcode;
GO

------------------------------------------------------------
-- 5) TOP ISSUES: MONTHLY BY NEIGHBORHOOD
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_top_issues_monthly_neighborhood_2024 AS
SELECT
  open_month,
  neighborhood,
  service_name,
  COUNT(*) AS request_count
FROM dbo.v_cases_enriched_2024
WHERE neighborhood IS NOT NULL
GROUP BY open_month, neighborhood, service_name;
GO


------------------------------------------------------------
-- 6) ROLLING 3-MONTH ZIP + CITY BENCHMARKS
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_kpi_zip_roll3_2024 AS
WITH zip_m AS (
  SELECT
    open_month,
    location_zipcode,
    total_requests,
    open_requests,
    closed_requests,
    median_resolution_hours,
    sla_eligible_cases,
    sla_met_rate
  FROM dbo.v_kpi_monthly_zip_2024
),
city_m AS (
  SELECT
    open_month,
    total_requests AS city_total_requests,
    open_requests  AS city_open_requests,
    closed_requests AS city_closed_requests,
    median_resolution_hours AS city_median_resolution_hours,
    sla_eligible_cases AS city_sla_eligible_cases,
    sla_met_rate AS city_sla_met_rate
  FROM dbo.v_kpi_monthly_city_2024
),
zip_roll AS (
  SELECT
    z.open_month,
    z.location_zipcode,

    z.total_requests,
    z.open_requests,
    z.closed_requests,
    z.median_resolution_hours,
    z.sla_eligible_cases,
    z.sla_met_rate,

    SUM(z.total_requests) OVER (
      PARTITION BY z.location_zipcode
      ORDER BY z.open_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS roll3_requests,

    AVG(CAST(z.sla_met_rate AS float)) OVER (
      PARTITION BY z.location_zipcode
      ORDER BY z.open_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS roll3_sla_rate,

    AVG(CAST(z.median_resolution_hours AS float)) OVER (
      PARTITION BY z.location_zipcode
      ORDER BY z.open_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS roll3_median_resolution_hours,

    COUNT(*) OVER (
      PARTITION BY z.location_zipcode
      ORDER BY z.open_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS roll3_months_present
  FROM zip_m z
)
SELECT
  r.*,

  AVG(CAST(c.city_sla_met_rate AS float)) OVER (
    ORDER BY c.open_month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS city_roll3_sla_rate,

  AVG(CAST(c.city_median_resolution_hours AS float)) OVER (
    ORDER BY c.open_month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS city_roll3_median_resolution_hours,

  SUM(c.city_total_requests) OVER (
    ORDER BY c.open_month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS city_roll3_requests,

  (r.roll3_sla_rate - AVG(CAST(c.city_sla_met_rate AS float)) OVER (
    ORDER BY c.open_month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  )) AS delta_roll3_sla_vs_city
FROM zip_roll r
JOIN city_m c
  ON c.open_month = r.open_month;
GO


------------------------------------------------------------
-- 7) PRODUCT VIEW: LATEST MONTH PER ZIP + FLAGS + SCORING
------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_product_zip_latest_2024 AS
WITH latest AS (
  SELECT MAX(open_month) AS latest_month
  FROM dbo.v_kpi_zip_roll3_2024
),
filtered AS (
  SELECT r.*
  FROM dbo.v_kpi_zip_roll3_2024 r
  CROSS JOIN latest l
  WHERE r.open_month = l.latest_month
    AND r.roll3_months_present = 3
    AND r.location_zipcode IS NOT NULL
),
derived AS (
  SELECT
    f.*,

    CAST(
      CASE WHEN f.total_requests = 0 THEN NULL
           ELSE 1.0 * f.open_requests / f.total_requests
      END AS float
    ) AS open_share,

    CASE
      WHEN f.roll3_median_resolution_hours IS NULL THEN 'Unknown'
      WHEN f.roll3_median_resolution_hours <= 6  THEN 'Fast'
      WHEN f.roll3_median_resolution_hours <= 12 THEN 'Moderate'
      ELSE 'Slow'
    END AS speed_category,

    CASE
      WHEN f.roll3_requests IS NULL THEN 'Unknown'
      WHEN f.roll3_requests >= 3000 THEN 'High'
      WHEN f.roll3_requests >= 1500 THEN 'Medium'
      ELSE 'Low'
    END AS demand_tier,

    CASE
      WHEN f.total_requests = 0 THEN 0
      WHEN (1.0 * f.open_requests / f.total_requests) >= 0.25 THEN 1
      ELSE 0
    END AS high_backlog_flag,

    CASE
      WHEN f.roll3_requests IS NULL THEN 1
      WHEN f.roll3_requests < 200 THEN 1
      ELSE 0
    END AS low_volume_flag
  FROM filtered f
),
scored AS (
  SELECT
    d.*,

    CAST(
        (COALESCE(d.open_share, 0.0) * 40.0)
      + (CASE
            WHEN d.roll3_requests >= 200
             AND d.delta_roll3_sla_vs_city IS NOT NULL
             AND d.delta_roll3_sla_vs_city < 0
            THEN ABS(d.delta_roll3_sla_vs_city) * 100.0
            ELSE 0.0
         END)
      + (CASE d.speed_category
           WHEN 'Slow' THEN 20.0
           WHEN 'Moderate' THEN 10.0
           WHEN 'Fast' THEN 0.0
           ELSE 5.0
         END)
      + (CASE d.demand_tier
           WHEN 'High' THEN 20.0
           WHEN 'Medium' THEN 10.0
           WHEN 'Low' THEN 0.0
           ELSE 5.0
         END)
      AS float
    ) AS priority_score,

    CASE
      WHEN d.low_volume_flag = 1 THEN NULL
      ELSE CAST(
          (COALESCE(d.open_share, 0.0) * 40.0)
        + (CASE
              WHEN d.roll3_requests >= 200
               AND d.delta_roll3_sla_vs_city IS NOT NULL
               AND d.delta_roll3_sla_vs_city < 0
              THEN ABS(d.delta_roll3_sla_vs_city) * 100.0
              ELSE 0.0
           END)
        + (CASE d.speed_category
             WHEN 'Slow' THEN 20.0
             WHEN 'Moderate' THEN 10.0
             WHEN 'Fast' THEN 0.0
             ELSE 5.0
           END)
        + (CASE d.demand_tier
             WHEN 'High' THEN 20.0
             WHEN 'Medium' THEN 10.0
             WHEN 'Low' THEN 0.0
             ELSE 5.0
           END)
        AS float
      )
    END AS priority_score_ranked
  FROM derived d
)
SELECT
  open_month,
  location_zipcode,

  total_requests,
  open_requests,
  closed_requests,
  median_resolution_hours,
  sla_eligible_cases,
  sla_met_rate,

  roll3_requests,
  roll3_sla_rate,
  roll3_median_resolution_hours,

  city_roll3_requests,
  city_roll3_sla_rate,
  city_roll3_median_resolution_hours,
  delta_roll3_sla_vs_city,

  open_share,
  speed_category,
  demand_tier,
  high_backlog_flag,
  low_volume_flag,

  priority_score,
  CASE
    WHEN priority_score >= 70 THEN 'P1'
    WHEN priority_score >= 45 THEN 'P2'
    ELSE 'P3'
  END AS priority_bucket,

  priority_score_ranked,
  CASE
    WHEN priority_score_ranked IS NULL THEN NULL
    WHEN priority_score_ranked >= 70 THEN 'P1'
    WHEN priority_score_ranked >= 45 THEN 'P2'
    ELSE 'P3'
  END AS priority_bucket_ranked
FROM scored;
GO


-- 1) base rows (should match your table count)
SELECT COUNT(*) AS rows FROM dbo.v_cases_enriched_2024;

-- 2) monthly zip: check open requests exist
SELECT TOP 10 *
FROM dbo.v_kpi_monthly_zip_2024
WHERE open_requests > 0
ORDER BY open_month DESC;

-- 3) city monthly: check open requests exist
SELECT TOP 12 *
FROM dbo.v_kpi_monthly_city_2024
ORDER BY open_month DESC;

-- 4) product view: should be latest month only + 31 zips
SELECT open_month, COUNT(*) AS zips
FROM dbo.v_product_zip_latest_2024
GROUP BY open_month;

-- 5) ranking split check (your expected: 31 total, 5 low volume -> null ranked)
SELECT low_volume_flag,
       COUNT(*) AS zips,
       SUM(CASE WHEN priority_score_ranked IS NULL THEN 1 ELSE 0 END) AS null_rank_rows
FROM dbo.v_product_zip_latest_2024
GROUP BY low_volume_flag;


