# Security Considerations

## Secrets Management

- Database credentials stored in Streamlit Cloud secrets
- No credentials committed to repository

## Database Security

- Supabase-managed PostgreSQL
- Connection via pooler host
- Password-protected access

## Input Validation

- ZIP codes validated using regex
- No dynamic raw SQL concatenation
- Query structure fixed and controlled

## Logging Privacy

- UUID-based session tracking
- No PII stored
- No IP tracking
- User agent stored for debugging only

## Data Exposure

- No raw dataset downloads exposed
- Aggregated metrics only
- No sensitive fields retained
