------------------- TABLE CREATION ----------------------------------
CREATE TABLE dbo.cases_analytics_2024 (
  case_id varchar(50) NOT NULL,
  system_generated_id varchar(50) NOT NULL,

  open_date datetime2(0) NOT NULL,
  sla_target_date datetime2(0) NULL,
  closed_date datetime2(0) NULL,

  on_time varchar(20) NOT NULL,
  case_status varchar(20) NOT NULL,
  closure_reason varchar(4000) NULL,
  case_topic varchar(255) NULL,

  assigned_department varchar(500) NOT NULL,
  assigned_team varchar(500) NOT NULL,
  service_name varchar(500) NOT NULL,
  queue varchar(500) NOT NULL,
  assignment_department varchar(50) NOT NULL,

  location varchar(1000) NULL,
  location_street_name varchar(500) NULL,
  location_zipcode char(5) NULL,

  neighborhood varchar(150) NULL,
  ward int NULL,
  precinct varchar(50) NULL,

  fire_district varchar(255) NULL,
  public_works_district varchar(255) NULL,
  city_council_district varchar(50) NULL,
  police_district varchar(255) NULL,
  neighborhood_services_district varchar(50) NULL,

  latitude decimal(9,6) NULL,
  longitude decimal(9,6) NULL,

  source varchar(100) NOT NULL,

  CONSTRAINT PK_cases_analytics_2024 PRIMARY KEY (case_id)
);
GO

------------------- DATA INSERTION FROM RAW TO ANALYTICS TABLE -----------------
INSERT INTO dbo.cases_analytics_2024 (
  case_id, system_generated_id,
  open_date, sla_target_date, closed_date,
  on_time, case_status, closure_reason, case_topic,
  assigned_department, assigned_team, service_name, queue, assignment_department,
  location, location_street_name, location_zipcode,
  neighborhood, ward, precinct,
  fire_district, public_works_district, city_council_district, police_district, neighborhood_services_district,
  latitude, longitude,
  source
)
SELECT
  r.case_id,
  r.system_generated_id,

  TRY_CONVERT(datetime2(0), r.open_date),
  TRY_CONVERT(datetime2(0), r.sla_target_date),
  TRY_CONVERT(datetime2(0), r.closed_date),

  r.on_time,
  r.case_status,
  NULLIF(LTRIM(RTRIM(r.closure_reason)), ''),
  NULLIF(LTRIM(RTRIM(r.case_topic)), ''),

  r.assigned_department,
  r.assigned_team,
  r.service_name,
  r.queue,
  r.assignment_department,

  NULLIF(LTRIM(RTRIM(r.location)), ''),
  NULLIF(LTRIM(RTRIM(r.location_street_name)), ''),
  CASE
    WHEN r.location_zipcode IS NULL THEN NULL
    WHEN LEN(LTRIM(RTRIM(r.location_zipcode))) >= 5 THEN RIGHT(LTRIM(RTRIM(r.location_zipcode)), 5)
    ELSE RIGHT('00000' + LTRIM(RTRIM(r.location_zipcode)), 5)
  END,

  NULLIF(LTRIM(RTRIM(r.neighborhood)), ''),
  TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(r.ward)), '')),
  NULLIF(LTRIM(RTRIM(r.precinct)), ''),

  NULLIF(LTRIM(RTRIM(r.fire_district)), ''),
  NULLIF(LTRIM(RTRIM(r.public_works_district)), ''),
  NULLIF(LTRIM(RTRIM(r.city_council_district)), ''),
  NULLIF(LTRIM(RTRIM(r.police_district)), ''),
  NULLIF(LTRIM(RTRIM(r.neighborhood_services_district)), ''),

  TRY_CONVERT(decimal(9,6), NULLIF(LTRIM(RTRIM(r.latitude)), '')),
  TRY_CONVERT(decimal(9,6), NULLIF(LTRIM(RTRIM(r.longitude)), '')),

  r.source
FROM dbo.cases_raw_2024 r;
GO

------------------- INDEXES FOR ANALYTICS TABLE -----------------
CREATE INDEX IX_cases_open_date ON dbo.cases_analytics_2024 (open_date);
CREATE INDEX IX_cases_neighborhood ON dbo.cases_analytics_2024 (neighborhood);
CREATE INDEX IX_cases_zip ON dbo.cases_analytics_2024 (location_zipcode);
GO