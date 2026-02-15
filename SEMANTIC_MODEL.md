```markdown
# Power BI Semantic Modeling Layer

Before building the hosted Streamlit application, a semantic model was created in Power BI.

## Objectives

- Design dimensional structure
- Define business metrics via DAX
- Validate aggregation logic before SQL implementation

## Model Structure

**Fact Table:**
- 311 service requests

**Dimensions:**
- Date
- ZIP
- Department (if applicable)

## Key Measures

- Total Requests
- Open Requests
- Closed Requests
- SLA Compliance Rate
- Median Resolution Time

## Design Influence

The Power BI model informed:
- SQL view structure
- Monthly aggregation logic
- SLA eligibility calculation

This ensured consistency between BI tool logic and database logic.
```