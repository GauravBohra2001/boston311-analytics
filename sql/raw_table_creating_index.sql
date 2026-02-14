CREATE INDEX ix_cases_open_date
ON dbo.cases_raw_2024 (open_date);

CREATE INDEX ix_cases_neighbourhood
ON dbo.cases_raw_2024 (neighborhood);

CREATE INDEX ix_cases_department
ON dbo.cases_raw_2024 (assigned_department);