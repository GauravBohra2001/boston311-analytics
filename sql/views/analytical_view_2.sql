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


SELECT TOP 20 *
FROM dbo.v_kpi_monthly_area_2024
WHERE neighborhood = 'Dorchester'
ORDER BY open_month DESC;

SELECT
  COUNT(*) AS rows_in_view,
  COUNT(DISTINCT CONCAT(CONVERT(varchar(10), open_month, 23), '|', ISNULL(neighborhood,''), '|', ISNULL(location_zipcode,''))) AS distinct_keys
FROM dbo.v_kpi_monthly_area_2024;