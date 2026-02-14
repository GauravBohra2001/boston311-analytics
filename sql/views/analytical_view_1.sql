CREATE VIEW dbo.v_cases_enriched_2024 AS
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
  CASE WHEN closed_date IS NOT NULL THEN 1 ELSE 0 END AS is_closed,

  DATEDIFF(hour, open_date, closed_date) AS resolution_hours,

  CASE WHEN sla_target_date IS NOT NULL THEN 1 ELSE 0 END AS sla_eligible,

  CASE
    WHEN sla_target_date IS NULL OR closed_date IS NULL THEN NULL
    WHEN closed_date <= sla_target_date THEN 1
    ELSE 0
  END AS sla_met,

  DATEFROMPARTS(YEAR(open_date), MONTH(open_date), 1) AS open_month
FROM dbo.cases_analytics_2024;
GO


SELECT TOP 5 * FROM dbo.v_cases_enriched_2024;