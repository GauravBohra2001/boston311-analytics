CREATE OR ALTER VIEW dbo.v_top_issues_monthly_zip_2024 AS
SELECT
  open_month,
  location_zipcode,
  service_name,
  COUNT(*) AS request_count
FROM dbo.v_cases_enriched_2024
WHERE location_zipcode IS NOT NULL
GROUP BY open_month, location_zipcode, service_name;
GO


