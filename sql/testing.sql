SELECT COUNT(*) AS row_count FROM dbo.cases_raw_2024;

-- To verify case_id is unique and worthy of becoming primary key
SELECT
    COUNT(DISTINCT case_id) as unique_case_id,
    COUNT(*) as total_rows
    FROM dbo.cases_raw_2024;


-- TO understand all the columns data type
sp_help 'dbo.cases_raw_2024';

-- Checking data in both raw and analytics table
SELECT COUNT(*) AS analytics_rows FROM dbo.cases_analytics_2024;
SELECT COUNT(*) AS raw_rows FROM dbo.cases_raw_2024;