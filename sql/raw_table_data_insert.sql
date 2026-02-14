BULK INSERT dbo.cases_raw_2024
FROM '/var/opt/mssql/cases_clean_2024.csv'
WITH (
  FIRSTROW = 2,
  FIELDTERMINATOR = ',',
  ROWTERMINATOR = '0x0a',
  TABLOCK
);
GO