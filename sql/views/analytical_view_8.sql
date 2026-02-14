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

    -- Base monthly (keep for charts)
    z.total_requests,
    z.open_requests,
    z.closed_requests,
    z.median_resolution_hours,
    z.sla_eligible_cases,
    z.sla_met_rate,

    -- Rolling 3-month (MVP rules)
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

    -- Useful for “do we have enough history?”
    COUNT(*) OVER (
      PARTITION BY z.location_zipcode
      ORDER BY z.open_month
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS roll3_months_present
  FROM zip_m z
)
SELECT
  r.*,

  -- City rolling 3-month
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

  -- Deltas vs city (rolling)
  (r.roll3_sla_rate - AVG(CAST(c.city_sla_met_rate AS float)) OVER (
    ORDER BY c.open_month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  )) AS delta_roll3_sla_vs_city

FROM zip_roll r
JOIN city_m c
  ON c.open_month = r.open_month;
GO