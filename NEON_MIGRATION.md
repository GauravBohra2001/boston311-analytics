# Neon Migration Guide

This project was migrated from Supabase to Neon without changing the fundamental application architecture.

The key reason this migration worked cleanly is that the app already talks to PostgreSQL through `psycopg2` and treats SQL views as the analytics contract.

## Why Neon Was Chosen

The migration goal was not to redesign the system. It was to remove an operational weakness in the free-tier hosting setup.

Supabase free-tier pause behavior could leave the public app broken until the database was manually resumed. Neon was chosen because it preserved the PostgreSQL architecture while replacing that failure mode with wake-on-demand cold starts.

## What Changed

- The provider changed from Supabase to Neon.
- The application code remained largely unchanged.
- Streamlit secrets now point to Neon.
- The app connection layer now retries connection attempts during wake-up windows.

## Recommended Approach

Do not rebuild the database from the checked-in SQL files unless you have to.

The repository SQL is mostly historical MSSQL-style work (`dbo`, `GO`, `DATEDIFF`), while the deployed app expects Postgres `public.*` objects. The easiest migration path is:

1. Export or import the existing Supabase Postgres database into Neon.
2. Keep the same Postgres tables/views the app already uses.
3. Update Streamlit secrets to the Neon pooled connection string.

## What Happened In This Migration

The completed migration followed this path:

1. Created a Neon project
2. Tried Neon automatic import from Supabase
3. Hit import failure in the hosted migration flow
4. Switched to manual `pg_dump` from Supabase direct host
5. Restored into Neon with `pg_restore`
6. Ignored unsupported Supabase-specific restore objects:
   - `supabase_vault`
   - `vault.secrets`
   - Supabase realtime internals
7. Verified the Streamlit app contract in Neon
8. Switched Streamlit Cloud to the Neon pooled `DATABASE_URL`

That fallback is worth documenting because it shows the migration was debugged pragmatically rather than restarted from scratch.

## Database Objects The App Requires

Verify that these objects exist in Neon after migration:

- `public.v_kpi_monthly_city_2024`
- `public.v_kpi_monthly_zip_2024`
- `public.v_product_zip_latest_2024`
- `public.v_top5_issues_zip_monthly_2024`
- `public.page_views`

Also verify the base case table used by those views was migrated with data.

## Secrets Setup

Preferred option:

- Set `DATABASE_URL` in Streamlit secrets using the Neon pooled connection string.

The app already supports split secrets too:

- `DB_HOST`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `DB_PORT`
- `DB_SSLMODE`

`DATABASE_URL` is simpler and is the better option for Neon.

## Neon-Specific Notes

- On the free plan, Neon scales to zero after inactivity.
- The first request after idle time can be slower while the compute wakes up.
- This app now retries initial connection attempts to reduce visible cold-start failures.
- Prefer Neon’s pooled connection string for the hosted app.

## Result

The final production architecture remains:

- Streamlit Cloud for the application
- Neon PostgreSQL for the analytical database
- SQL views as the query contract
- Session logging in `public.page_views`

## Verification Checklist

After updating secrets, test these flows:

1. Open the City Overview page and confirm monthly KPIs render.
2. Open the ZIP page and confirm the ZIP dropdown loads.
3. Select a ZIP and confirm the ZIP vs City chart renders.
4. Confirm the Top 5 Issues table loads.
5. Confirm `page_views` inserts still work by checking recent rows in Neon.

## Migration Risk

The main migration risk is not Python compatibility. It is whether the current live Postgres schema and views are migrated intact.

If the import copies schema and data correctly, the code changes should be minimal.
