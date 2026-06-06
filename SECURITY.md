# Security Considerations

## Secrets Management

- Database credentials stored in Streamlit Cloud secrets
- Local development credentials stored in `.streamlit/secrets.toml`
- No credentials committed to repository
- Local secrets file is gitignored

## Database Security

- Neon-managed PostgreSQL
- Connection via pooled host for deployment
- Password-protected access
- Credentials rotated after migration/testing exposure

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

## Migration Security Note

- Supabase-specific extensions and realtime internals were not required for the application and were intentionally excluded from the final Neon runtime contract
