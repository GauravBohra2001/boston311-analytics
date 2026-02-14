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