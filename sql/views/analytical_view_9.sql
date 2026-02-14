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

    /* % open this month */
    CAST(
      CASE WHEN f.total_requests = 0 THEN NULL
           ELSE 1.0 * f.open_requests / f.total_requests
      END AS float
    ) AS open_share,

    /* speed category from roll3 median */
    CASE
      WHEN f.roll3_median_resolution_hours IS NULL THEN 'Unknown'
      WHEN f.roll3_median_resolution_hours <= 6  THEN 'Fast'
      WHEN f.roll3_median_resolution_hours <= 12 THEN 'Moderate'
      ELSE 'Slow'
    END AS speed_category,

    /* demand tier from roll3 volume */
    CASE
      WHEN f.roll3_requests IS NULL THEN 'Unknown'
      WHEN f.roll3_requests >= 3000 THEN 'High'
      WHEN f.roll3_requests >= 1500 THEN 'Medium'
      ELSE 'Low'
    END AS demand_tier,

    /* backlog flag (simple rule) */
    CASE
      WHEN f.total_requests = 0 THEN 0
      WHEN (1.0 * f.open_requests / f.total_requests) >= 0.25 THEN 1
      ELSE 0
    END AS high_backlog_flag,

    /* low volume flag for credibility */
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

    /* Priority score (higher = needs attention) */
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

    /* Ranked score: hide low volume from ranking by default */
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
  -- Keys
  open_month,
  location_zipcode,

  -- Monthly KPIs (context)
  total_requests,
  open_requests,
  closed_requests,
  median_resolution_hours,
  sla_eligible_cases,
  sla_met_rate,

  -- Rolling 3-month KPIs (primary)
  roll3_requests,
  roll3_sla_rate,
  roll3_median_resolution_hours,

  -- City benchmark (rolling)
  city_roll3_requests,
  city_roll3_sla_rate,
  city_roll3_median_resolution_hours,
  delta_roll3_sla_vs_city,

  -- Derived
  open_share,
  speed_category,
  demand_tier,
  high_backlog_flag,
  low_volume_flag,

  -- Scoring (transparent)
  priority_score,
  CASE
    WHEN priority_score >= 70 THEN 'P1'
    WHEN priority_score >= 45 THEN 'P2'
    ELSE 'P3'
  END AS priority_bucket,

  -- Scoring (default ranking)
  priority_score_ranked,
  CASE
    WHEN priority_score_ranked IS NULL THEN NULL
    WHEN priority_score_ranked >= 70 THEN 'P1'
    WHEN priority_score_ranked >= 45 THEN 'P2'
    ELSE 'P3'
  END AS priority_bucket_ranked

FROM scored;
GO

SELECT COUNT(*) AS zip_rows
FROM dbo.v_product_zip_latest_2024;

SELECT
  low_volume_flag,
  COUNT(*) AS zips
FROM dbo.v_product_zip_latest_2024
GROUP BY low_volume_flag;

SELECT TOP 10
  location_zipcode,
  roll3_requests,
  low_volume_flag,
  open_share,
  speed_category,
  demand_tier,
  delta_roll3_sla_vs_city,
  priority_score_ranked,
  priority_bucket_ranked
FROM dbo.v_product_zip_latest_2024
WHERE priority_score_ranked IS NOT NULL
ORDER BY priority_score_ranked DESC;