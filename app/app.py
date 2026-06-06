import pandas as pd
import altair as alt
import streamlit as st
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
from time import sleep
from uuid import uuid4
from urllib.parse import parse_qsl, unquote, urlparse

# ============================================================
# Page config + lightweight styling
# ============================================================
st.set_page_config(page_title="Boston 311 Analytics (2024)", layout="wide")
st.title("Boston 311 Analytics (2024)")
st.caption("Data source: Boston 311 (2024). Last refreshed: February 2026.")

# ------------------------------------------------------------
# Session ID (unique per browser session)
# ------------------------------------------------------------
if "sid" not in st.session_state:
    st.session_state["sid"] = str(uuid4())
    
# Optional: keep charts readable
alt.data_transformers.disable_max_rows()

# ============================================================
# DB connection helpers
# ============================================================
def _secret_str(name: str, default: str | None = None) -> str | None:
    if name not in st.secrets:
        return default
    value = st.secrets[name]
    if value is None:
        return default
    text = str(value).strip()
    return text or default


def _build_conn_kwargs() -> dict:
    database_url = _secret_str("DATABASE_URL")
    if database_url:
        parsed = urlparse(database_url)
        if not parsed.hostname:
            raise RuntimeError("DATABASE_URL is set but does not include a hostname.")

        conn_kwargs = {
            "host": parsed.hostname,
            "dbname": parsed.path.lstrip("/") or "postgres",
            "user": unquote(parsed.username) if parsed.username else None,
            "password": unquote(parsed.password) if parsed.password else None,
            "port": parsed.port or 5432,
            "sslmode": "require",
            "connect_timeout": 10,
        }

        for key, value in parse_qsl(parsed.query, keep_blank_values=False):
            if key == "sslmode":
                conn_kwargs["sslmode"] = value

        return {k: v for k, v in conn_kwargs.items() if v is not None}

    host = _secret_str("DB_HOST")
    dbname = _secret_str("DB_NAME", "postgres")
    user = _secret_str("DB_USER")
    password = _secret_str("DB_PASSWORD")
    sslmode = _secret_str("DB_SSLMODE", "require")

    if not host:
        raise RuntimeError(
            "Missing database configuration. Set either DATABASE_URL or DB_HOST in Streamlit secrets."
        )

    if not user or not password:
        raise RuntimeError(
            "Incomplete database configuration. DB_USER and DB_PASSWORD must be set in Streamlit secrets."
        )

    port_text = _secret_str("DB_PORT")
    if port_text:
        try:
            port = int(port_text)
        except ValueError as exc:
            raise RuntimeError(f"Invalid DB_PORT value: {port_text!r}.") from exc
    else:
        port = 6543 if "pooler.supabase.com" in host else 5432

    return {
        "host": host,
        "dbname": dbname,
        "user": user,
        "password": password,
        "port": port,
        "sslmode": sslmode,
        "connect_timeout": 10,
    }


def get_conn():
    conn_kwargs = _build_conn_kwargs()
    last_error = None
    for attempt in range(3):
        try:
            return psycopg2.connect(**conn_kwargs)
        except psycopg2.OperationalError as exc:
            last_error = exc
            if attempt < 2:
                sleep(2)

    host = str(conn_kwargs.get("host", ""))
    port = conn_kwargs.get("port", "")
    direct_supabase_hint = ""
    neon_pooler_hint = ""
    if host.endswith(".supabase.co") and "pooler.supabase.com" not in host:
        direct_supabase_hint = (
            " You appear to be using the direct Supabase host. "
            "Try the Supabase pooler host instead."
        )
    if ".neon.tech" in host and "-pooler." not in host:
        neon_pooler_hint = (
            " For Neon-hosted apps, prefer the pooled connection string "
            "so cold starts and concurrent requests are handled more gracefully."
        )

    raise RuntimeError(
        f"Database connection failed for host={host!r} port={port!r}. "
        "Verify the database host, port, database name, user, password, and sslmode=require."
        " If the database was idle, retrying after the compute wakes up may resolve the issue."
        f"{direct_supabase_hint}{neon_pooler_hint}"
    ) from last_error

@st.cache_data(ttl=300, show_spinner=False)
def fetch_df(sql: str, params=None) -> pd.DataFrame:
    conn = get_conn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
        return pd.DataFrame(rows)
    finally:
        conn.close()

def exec_sql(sql: str, params=None):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            conn.commit()
    finally:
        conn.close()

def get_user_agent() -> str:
    try:
        return st.context.headers.get("User-Agent", "")
    except Exception:
        return ""

# def log_page_view(page: str, zip_selected: str | None = None):
#     # never break app if logging fails
#     try:
#         exec_sql(
#             """
#             INSERT INTO public.page_views(page, zip_selected, user_agent)
#             VALUES (%s, %s, %s)
#             """,
#             (page, zip_selected, get_user_agent()),
#         )
#     except Exception:
#         pass

def log_page_view(page: str, zip_selected: str | None = None):
    try:
        exec_sql(
            """
            INSERT INTO public.page_views(page, zip_selected, user_agent, session_id)
            VALUES (%s, %s, %s, %s)
            """,
            (page, zip_selected, get_user_agent(), st.session_state.get("sid")),
        )
    except Exception:
        pass

def log_once(page: str, zip_selected: str | None = None):
    key = f"logged::{page}::{zip_selected or 'null'}"
    if st.session_state.get(key):
        return
    st.session_state[key] = True
    log_page_view(page, zip_selected)

# ============================================================
# KPI helpers
# ============================================================
def weighted_sla(df: pd.DataFrame) -> float | None:
    if df.empty:
        return None
    if "sla_eligible_cases" not in df.columns or "sla_met_rate" not in df.columns:
        return None
    denom = pd.to_numeric(df["sla_eligible_cases"], errors="coerce").fillna(0).sum()
    if denom == 0:
        return None
    num = (pd.to_numeric(df["sla_met_rate"], errors="coerce").fillna(0) * pd.to_numeric(df["sla_eligible_cases"], errors="coerce").fillna(0)).sum()
    return float(num / denom)

def safe_float_median(series: pd.Series) -> float | None:
    s = pd.to_numeric(series, errors="coerce")
    if s.dropna().empty:
        return None
    return float(s.median())

def fmt_int(x: int | float | None) -> str:
    if x is None:
        return "—"
    try:
        return f"{int(x):,}"
    except Exception:
        return "—"

def fmt_pct(p: float | None, digits: int = 1) -> str:
    if p is None:
        return "—"
    return f"{p*100:.{digits}f}%"

# ============================================================
# Dimensions from DB (so no dependency on Dim tables)
# ============================================================
dim_month = fetch_df("""
  SELECT DISTINCT to_char(open_month, 'YYYY-MM') AS year_month
  FROM public.v_kpi_monthly_city_2024
  ORDER BY year_month;
""")
month_options = dim_month["year_month"].tolist() if not dim_month.empty else []

# dim_zip = fetch_df("""
#   SELECT DISTINCT location_zipcode
#   FROM public.v_kpi_monthly_zip_2024
#   WHERE location_zipcode IS NOT NULL
#   ORDER BY location_zipcode;
# """)

dim_zip = fetch_df("""
    SELECT location_zipcode
    FROM public.v_kpi_monthly_zip_2024
    GROUP BY location_zipcode
    HAVING SUM(total_requests) > 50
    ORDER BY location_zipcode;
""")
zip_options = dim_zip["location_zipcode"].astype(str).tolist() if not dim_zip.empty else []

# ============================================================
# Sidebar (simple + usable)
# ============================================================
st.sidebar.header("Controls")

page = st.sidebar.radio("Page", ["City Overview (2024)", "Find My Area (ZIP)"], index=0)

# Month selection UX: default full year, allow custom selection
show_full_year = st.sidebar.checkbox("Show full year (YTD)", value=True)

if show_full_year:
    selected_months = month_options[:]  # all months
else:
    selected_months = st.sidebar.multiselect(
        "Select months",
        options=month_options,
        default=month_options[-3:] if len(month_options) >= 3 else month_options
    )

if not selected_months:
    st.sidebar.warning("Select at least 1 month.")
    st.stop()

# Convert selected_months to date filter like YYYY-MM-01
open_month_filter = [f"{ym}-01" for ym in selected_months]
st.sidebar.caption(f"Active months: {selected_months[0]} → {selected_months[-1]} ({len(selected_months)} months)")

# ZIP selection (only on ZIP page)
selected_zip = None
if page == "Find My Area (ZIP)":
    st.sidebar.subheader("ZIP Selection")
    if not zip_options:
        st.error("No ZIPs found from v_kpi_monthly_zip_2024.")
        st.stop()
    selected_zip = st.sidebar.selectbox("Select ZIP", options=zip_options, index=0)

# ============================================================
# Small “What am I looking at?” blocks (students + recruiters)
# ============================================================
def info_block_city():
    st.markdown("""
### What is 311?

Boston 311 is the city's public service request system.  
Residents use it to report issues like potholes, trash pickup problems, broken streetlights, and other neighborhood concerns.

This dashboard analyzes 2024 311 request performance across Boston.

### How to Explore This Dashboard
- Use the month selector on the left to compare seasonal trends.
- Watch **SLA Compliance Rate** to see how reliably cases are resolved on time.
- Check **Open Requests** to understand backlog pressure.
- Use the monthly trends to see whether performance is improving or declining.

### How to Interpret the KPIs
- **SLA Compliance Rate** = % of eligible cases resolved within target time (higher is better)
- **Open Requests** = unresolved cases (backlog signal)
- **Median Resolution (hrs)** = typical time to close requests (lower is better)
""".strip())

def info_block_zip(zip_code: str):
    st.markdown(
        f"""
**What this is:** Performance for **ZIP {zip_code}** compared with the **Boston city average** for the same months.  
**How to use:** Select a ZIP → compare the two SLA lines → use the “Risk & Demand” row for a quick status view.  
**How to interpret:**
- If **ZIP line is below City line**, the area is underperforming vs the city average.
- **ZIP SLA Δ vs City (last)** shows the gap in the most recent selected month.
        """.strip()
    )

# ============================================================
# Page 1: City Overview
# ============================================================
if page == "City Overview (2024)":
    #log_page_view("city_overview", None)
    log_once("city_overview", None)
    info_block_city()

    city = fetch_df(
        """
        SELECT *
        FROM public.v_kpi_monthly_city_2024
        WHERE open_month = ANY(%s::date[])
        ORDER BY open_month;
        """,
        (open_month_filter,),
    )

    if city.empty:
        st.error("No rows returned for selected months from v_kpi_monthly_city_2024.")
        st.stop()

    # KPIs
    total_requests = int(pd.to_numeric(city["total_requests"], errors="coerce").fillna(0).sum())
    open_requests = int(pd.to_numeric(city["open_requests"], errors="coerce").fillna(0).sum())
    sla = weighted_sla(city)
    median_res = safe_float_median(city["median_resolution_hours"])

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Requests", fmt_int(total_requests))
    c2.metric("Open Requests", fmt_int(open_requests))
    c3.metric("SLA Compliance Rate", fmt_pct(sla, 1))
    c4.metric("Median Resolution (hrs)", f"{median_res:.1f}" if median_res is not None else "—")

    # Trend prep
    city["YearMonth"] = pd.to_datetime(city["open_month"]).dt.strftime("%Y-%m")
    city["sla_met_rate"] = pd.to_numeric(city["sla_met_rate"], errors="coerce")
    city["total_requests"] = pd.to_numeric(city["total_requests"], errors="coerce")

    left, right = st.columns(2)

    with left:
        st.subheader("SLA Met Rate by Month (City)")
        chart_df = city[["YearMonth", "sla_met_rate"]].dropna()
        chart = (
            alt.Chart(chart_df)
            .mark_line(point=True)
            .encode(
                x=alt.X("YearMonth:N", title="Year-Month"),
                y=alt.Y("sla_met_rate:Q", title="SLA Met Rate", axis=alt.Axis(format="%")),
                tooltip=["YearMonth", alt.Tooltip("sla_met_rate:Q", format=".1%")],
            )
        )
        st.altair_chart(chart, use_container_width=True)

    with right:
        st.subheader("Total Requests by Month (City)")
        vol_df = city[["YearMonth", "total_requests"]].dropna()
        chart2 = (
            alt.Chart(vol_df)
            .mark_line(point=True)
            .encode(
                x=alt.X("YearMonth:N", title="Year-Month"),
                y=alt.Y("total_requests:Q", title="Total Requests"),
                tooltip=["YearMonth", alt.Tooltip("total_requests:Q", format=",")],
            )
        )
        st.altair_chart(chart2, use_container_width=True)

# ============================================================
# Page 2: Find My Area (ZIP)
# ============================================================
else:
    # Track ZIP selection + page view
    #log_page_view("find_my_area", str(selected_zip))
    log_once("find_my_area", str(selected_zip))
    info_block_zip(str(selected_zip))

    # Query only what you need for speed
    zip_kpi = fetch_df(
        """
        SELECT open_month, location_zipcode, total_requests, open_requests, sla_eligible_cases, sla_met_rate, median_resolution_hours
        FROM public.v_kpi_monthly_zip_2024
        WHERE location_zipcode = %s
          AND open_month = ANY(%s::date[])
        ORDER BY open_month;
        """,
        (str(selected_zip), open_month_filter),
    )

    city = fetch_df(
        """
        SELECT open_month, total_requests, open_requests, sla_eligible_cases, sla_met_rate, median_resolution_hours
        FROM public.v_kpi_monthly_city_2024
        WHERE open_month = ANY(%s::date[])
        ORDER BY open_month;
        """,
        (open_month_filter,),
    )

    # if zip_kpi.empty or city.empty:
    #     city_sla = weighted_sla(city)
    #     st.error("Missing data for selected ZIP/months.")
    #     st.stop()
    
    if zip_kpi.empty or city.empty:
        st.error("Missing data for selected ZIP/months.")
        st.stop()

    city_sla = weighted_sla(city)

    st.header(f"Find My Area — ZIP {selected_zip}")
    st.caption("Compare your ZIP against the city average and see which issues appear most often in your neighborhood.")

    # KPIs
    total_requests = int(pd.to_numeric(zip_kpi["total_requests"], errors="coerce").fillna(0).sum())
    open_requests = int(pd.to_numeric(zip_kpi["open_requests"], errors="coerce").fillna(0).sum())
    sla = weighted_sla(zip_kpi)
    median_res = safe_float_median(zip_kpi["median_resolution_hours"])

    # Last-month delta vs city (based on most recent selected month available)
    zip_kpi["open_month"] = pd.to_datetime(zip_kpi["open_month"])
    city["open_month"] = pd.to_datetime(city["open_month"])

    # Align on last month present in both
    last_month = min(zip_kpi["open_month"].max(), city["open_month"].max())
    z_last_row = zip_kpi[zip_kpi["open_month"] == last_month]
    c_last_row = city[city["open_month"] == last_month]

    delta_pct = None
    if not z_last_row.empty and not c_last_row.empty:
        z_last = float(pd.to_numeric(z_last_row["sla_met_rate"], errors="coerce").iloc[0])
        c_last = float(pd.to_numeric(c_last_row["sla_met_rate"], errors="coerce").iloc[0])
        if pd.notna(z_last) and pd.notna(c_last):
            delta_pct = (z_last - c_last) * 100.0

    k1, k2, k3, k4, k5, k6 = st.columns(6)
    k1.metric("Total Requests (ZIP)", fmt_int(total_requests))
    k2.metric("Open Requests (ZIP)", fmt_int(open_requests))
    k3.metric("SLA Met Rate (ZIP)", fmt_pct(sla, 1))
    k4.metric("Median Resolution (hrs)", f"{median_res:.1f}" if median_res is not None else "—")
    k5.metric("ZIP SLA Δ vs City (last)", f"{delta_pct:.1f}%" if delta_pct is not None else "—")
    k6.metric("SLA Met Rate (City)", fmt_pct(city_sla, 1))

    # SLA edge case: if there are no SLA-eligible cases, SLA rate will be null/—
    sla_eligible_sum = pd.to_numeric(zip_kpi["sla_eligible_cases"], errors="coerce").fillna(0).sum()
    if sla_eligible_sum == 0:
        st.caption("Note: No SLA-eligible cases in the selected months for this ZIP, so SLA rate is shown as —.")

    # Trend prep
    zip_kpi["YearMonth"] = zip_kpi["open_month"].dt.strftime("%Y-%m")
    city["YearMonth"] = city["open_month"].dt.strftime("%Y-%m")
    zip_kpi["sla_met_rate"] = pd.to_numeric(zip_kpi["sla_met_rate"], errors="coerce")
    city["sla_met_rate"] = pd.to_numeric(city["sla_met_rate"], errors="coerce")

    # ========================================================
    # Actionable insight (makes it “product-like”)
    # ========================================================
    product = fetch_df(
        """
        SELECT *
        FROM public.v_product_zip_latest_2024
        WHERE location_zipcode = %s
        LIMIT 1;
        """,
        (str(selected_zip),),
    )

    insight_title = "Area Status: —"
    insight_body = "No classification available for this ZIP in the latest month."

    if not product.empty:
        row = product.iloc[0].to_dict()
        pb = row.get("priority_bucket_ranked")
        speed = row.get("speed_category")
        demand = row.get("demand_tier")
        delta_roll3 = row.get("delta_roll3_sla_vs_city")
        roll3_req = row.get("roll3_requests")
        open_share = row.get("open_share")

        # safe numeric parsing
        try:
            delta_roll3 = float(delta_roll3) if delta_roll3 is not None else None
        except Exception:
            delta_roll3 = None

        status = "Stable"
        reason_bits = []

        if pb == "P1" or (speed == "Slow" and demand == "High"):
            status = "Needs Attention"
            reason_bits.append("High priority bucket / slow+high demand pattern")
        if delta_roll3 is not None and delta_roll3 < -0.03:
            status = "Underperforming vs City"
            reason_bits.append("3-month SLA below city average")

        insight_title = f"Area Status: {status}"
        detail = []
        if roll3_req is not None:
            detail.append(f"Roll-3 Requests: {int(float(roll3_req)):,}")
        if open_share is not None:
            try:
                detail.append(f"Open Share: {float(open_share)*100:.1f}%")
            except Exception:
                pass
        if delta_roll3 is not None:
            detail.append(f"Δ SLA vs City (roll-3): {delta_roll3*100:+.1f}%")

        reason = "; ".join(reason_bits) if reason_bits else "Performance is not significantly below the city baseline."
        insight_body = f"**Why:** {reason}  \n**Signals:** " + (" | ".join(detail) if detail else "—")

    st.info(f"**{insight_title}**  \n{insight_body}")
    st.caption("Action idea: If the same issue types repeat every month, report early in the month to avoid end-month backlog. Use the Top Issues section below to spot repeats.")

    # ========================================================
    # ZIP vs City SLA chart
    # ========================================================
    # st.subheader("SLA Benchmark: ZIP vs City")
    left_col, right_col = st.columns([2, 1])
    with left_col:
        st.subheader("SLA Benchmark: ZIP vs City")
        zdf = zip_kpi[["YearMonth", "sla_met_rate"]].copy()
        zdf["series"] = "Selected ZIP"
        cdf = city[["YearMonth", "sla_met_rate"]].copy()
        cdf["series"] = "City Average"
        plot = pd.concat([zdf, cdf], ignore_index=True).dropna()
        chart = (
            alt.Chart(plot)
            .mark_line(point=True)
            .encode(
                x=alt.X("YearMonth:N", title="Year-Month"),
                y=alt.Y("sla_met_rate:Q", title="SLA Met Rate", axis=alt.Axis(format="%")),
                color=alt.Color("series:N", title=""),
                tooltip=["YearMonth", "series", alt.Tooltip("sla_met_rate:Q", format=".1%")],
            )
        )
        st.altair_chart(chart, use_container_width=True)

    # ----------------------------
    # Current Risk & Demand Classification
    # ----------------------------
    # st.subheader("Current Risk & Demand Classification (Latest 3-month view)")
    # st.caption(
    #     "This classification summarizes whether the area is high demand, slow resolving, "
    #     "or showing backlog risk compared to the city average."
    # )
    with right_col:
        st.subheader("Current Risk & Demand Classification (Latest 3-month view)")
        st.caption(
            "This classification summarizes whether the area is high demand, slow resolving, "
            "or showing backlog risk compared to the city average."
        )

        if not product.empty:
            cols = [c for c in [
                "location_zipcode",
                "priority_bucket_ranked",
                "speed_category",
                "demand_tier",
                "high_backlog_flag",
                "priority_score_ranked",
                "roll3_requests",
                "open_share",
                "delta_roll3_sla_vs_city",
            ] if c in product.columns]

            st.dataframe(product[cols], use_container_width=True)

            st.info(
                "How to read this:\n"
                "- **Priority Bucket**: Overall risk tier based on backlog, SLA performance and demand.\n"
                "- **Speed Category**: How quickly cases are resolved compared to thresholds.\n"
                "- **Demand Tier**: Volume intensity of 311 requests in the past 3 months.\n"
                "- **High Backlog Flag**: 1 = unusually high share of open cases.\n"
                "- **ZIP SLA Δ vs City**: Negative means this ZIP is performing worse than city average."
            )
        else:
            st.info("No product row found for selected ZIP.")

    # if not product.empty:
    #     cols = [c for c in [
    #         "location_zipcode",
    #         "priority_bucket_ranked",
    #         "speed_category",
    #         "demand_tier",
    #         "high_backlog_flag",
    #         "priority_score_ranked",
    #         "roll3_requests",
    #         "open_share",
    #         "delta_roll3_sla_vs_city",
    #     ] if c in product.columns]

    #     st.dataframe(product[cols], use_container_width=True)

    #     # Small interpretation guide (adds recruiter value)
    #     st.info(
    #         "How to read this:\n"
    #         "- **Priority Bucket**: Overall risk tier based on backlog, SLA performance and demand.\n"
    #         "- **Speed Category**: How quickly cases are resolved compared to thresholds.\n"
    #         "- **Demand Tier**: Volume intensity of 311 requests in the past 3 months.\n"
    #         "- **High Backlog Flag**: 1 = unusually high share of open cases.\n"
    #         "- **ZIP SLA Δ vs City**: Negative means this ZIP is performing worse than city average."
    #     )
    # else:
    #     st.info("No product row found for selected ZIP.")


    # ----------------------------
    # Top 5 Issue Types (Actionable Section)
    # ----------------------------
    st.subheader("Top 5 Issue Types in this ZIP (Selected Months)")
    st.caption(
        "Most common request categories submitted in this ZIP. "
        "This helps students understand recurring neighborhood problems."
    )

    top_issues = fetch_df("""
    select open_month, issue_type, request_count, issue_rank
    from public.v_top5_issues_zip_monthly_2024
    where location_zipcode = %s
        and open_month = ANY(%s::date[])
    order by open_month desc, issue_rank;
    """, (str(selected_zip), open_month_filter))

    if not top_issues.empty:
        top_issues["open_month"] = pd.to_datetime(top_issues["open_month"]).dt.strftime("%Y-%m")
        st.dataframe(top_issues, use_container_width=True)
        bar_df = top_issues.copy()
        bar_df["request_count"] = pd.to_numeric(bar_df["request_count"], errors="coerce").fillna(0)

        bar = (
            alt.Chart(bar_df)
            .mark_bar()
            .encode(
                x=alt.X("request_count:Q", title="Requests"),
                y=alt.Y("issue_type:N", sort="-x", title="Issue Type"),
                tooltip=["open_month", "issue_type", alt.Tooltip("request_count:Q", format=",")]
            )
        )
        st.altair_chart(bar, use_container_width=True)

        st.success(
            "Tip: If you repeatedly see the same issue type, "
            "it indicates a structural neighborhood pattern rather than a one-off complaint."
        )
    else:
        st.info("No issue data found for selected ZIP/months.")

with st.expander("How is Risk Classification calculated?"):
    st.markdown("""
- Priority bucket based on backlog + SLA delta + demand tier.
- Rolling 3-month averages used to reduce volatility.
- Comparison benchmark = city-wide weighted SLA.
    """)

# ========================================================
# Feedback Section (Lightweight & Professional)
# ========================================================

with st.expander("Feedback / Suggestions"):
    st.write(
        "If something feels confusing, inaccurate, or unclear, "
        "please open an issue on GitHub."
    )
    st.write(
        "GitHub Repository: "
        "https://github.com/GauravBohra2001/boston311-analytics"
    )
    
st.markdown("---")
st.caption("Built by Gaurav Bohra • Data Engineering & Analytics Project")
st.caption("Data source: Boston 311 (2024) • Last refreshed: March 2026")
st.caption("GitHub: https://github.com/GauravBohra2001/boston311-analytics")
