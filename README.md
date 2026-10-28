# CS779 — Snowflake Data Engineering: OPS Pipeline & Analytics Platform

**Boston University | MET CS 779 | Term Project**

## Project Overview
Designed and implemented a production-style data engineering platform on Snowflake featuring a 17-table OPS schema, a multi-layer data pipeline (Bronze → Silver → Gold), data quality monitoring, clustering optimization, and advanced Snowflake-native features.

## Architecture Highlights
- **17-table OPS schema** — Pipelines, Jobs, ExecutionRuns, DQ Rules, Failure Logs, Dataset Lineage
- **Multi-layer pipeline** — Bronze (raw JSONL) → Silver (cleaned CSV) → Gold (aggregated daily)
- **Data Quality framework** — DQRule + DQResult tables with blocking/non-blocking rules
- **Snowflake features used** — Time Travel, Clustering, Variant/JSONL ingestion, Recursive CTEs, Query Profiles, SLA monitoring

## Key Deliverables
| File | Description |
|------|-------------|
| `sql/Advanced_DB_Project_Setup.sql` | Warehouse, database & schema setup |
| `sql/create_tables_data_snowflake.sql` | All 17 OPS schema table definitions |
| `sql/load_ops_data_snowflake.sql` | Data loading & transformation scripts |
| `data/bronze_user_events_raw.jsonl` | Raw Bronze layer events |
| `data/silver_user_events_clean.csv` | Cleaned Silver layer |
| `data/gold_user_events_daily.csv` | Aggregated Gold layer |
| `diagrams/Snowflake_OPS_Schema_final.drawio` | Final ERD |
| `reports/SAHINS_Term_Project_Snowflake.pptx` | Final presentation |
| `reports/SAHINS_delta.mp4` | Demo walkthrough |

## Tech Stack
| Tool | Purpose |
|------|---------|
| Snowflake | Cloud data warehouse |
| SQL | Schema design, queries, DQ rules |
| JSONL / CSV | Bronze & Silver layer data formats |
| Draw.io | ERD & architecture diagrams |

## Schema Overview
```
CloudProvider → CloudResource → DataSource → Pipeline → Job → ExecutionRun
                                                           ↓
                                                     FailureLog
Pipeline → PipelineSource (junction)
Job → JobDependency (self-referencing)
Job → TargetDataset → DatasetLineage
ExecutionRun → DQResult ← DQRule ← Dataset
```

## Author
Sedar Sahin | Boston University
