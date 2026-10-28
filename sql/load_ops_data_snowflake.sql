USE WAREHOUSE DE_TERM_WH;
USE DATABASE DE_TERM_PROJECT;
USE SCHEMA OPS;

-- Term Project: Realistic OPS metadata dataset
-- Run AFTER creating tables (DDL). Uses explicit IDs for portability.

INSERT INTO DE_TERM_PROJECT.OPS.CloudProvider (ProviderID, ProviderName) VALUES
(1, 'Snowflake'),
(2, 'Azure'),
(3, 'AWS');

INSERT INTO DE_TERM_PROJECT.OPS.ResourceType (ResourceTypeID, TypeName) VALUES
(1, 'WAREHOUSE'),
(2, 'STORAGE'),
(3, 'STAGE');

INSERT INTO DE_TERM_PROJECT.OPS.SourceType (SourceTypeID, TypeName) VALUES
(1, 'API'),
(2, 'DATABASE'),
(3, 'FILE'),
(4, 'STREAM');

INSERT INTO DE_TERM_PROJECT.OPS.JobType (JobTypeID, TypeName) VALUES
(1, 'EXTRACT'),
(2, 'TRANSFORM'),
(3, 'LOAD');

INSERT INTO DE_TERM_PROJECT.OPS.RunStatus (StatusID, StatusName) VALUES
(1, 'RUNNING'),
(2, 'SUCCESS'),
(3, 'FAILED'),
(4, 'SKIPPED');

INSERT INTO DE_TERM_PROJECT.OPS.CloudResource (ResourceID, ProviderID, ResourceTypeID, ResourceName, Region, CostCenter) VALUES
(1, 1, 1, 'SF_WH_XS', 'us-east-1', 'DE-OPS'),
(2, 1, 1, 'SF_WH_S', 'us-east-1', 'DE-OPS'),
(3, 2, 2, 'AZ_BLOB_DEMO', 'eastus', 'DE-OPS');

INSERT INTO DE_TERM_PROJECT.OPS.DataSource (SourceID, SourceTypeID, SourceName, ConnectionRef, OwnerTeam) VALUES
(1, 1, 'AuthService_API', 'https://api.company.com/auth/events', 'Platform'),
(2, 1, 'BillingService_API', 'https://api.company.com/billing/events', 'Platform'),
(3, 2, 'CRM_Postgres', 'postgres://crm.prod:5432', 'SalesOps'),
(4, 3, 'SupportTickets_CSV', 'azure://blob/support/tickets/*.csv', 'Support');

INSERT INTO DE_TERM_PROJECT.OPS.Pipeline (PipelineID, PipelineName, OwnerTeam, Criticality, SLA_Minutes, IsActive) VALUES
(1, 'UserEvents_BronzeToGold', 'DataEng', 'HIGH', 60, TRUE),
(2, 'BillingEvents_BronzeToGold', 'DataEng', 'HIGH', 90, TRUE),
(3, 'CRM_Daily_Load', 'DataEng', 'MEDIUM', 180, TRUE);

INSERT INTO DE_TERM_PROJECT.OPS.PipelineSource (PipelineID, SourceID) VALUES
('1', '1'),
('2', '2'),
('3', '3');

INSERT INTO DE_TERM_PROJECT.OPS.Dataset (DatasetID, DatasetName, Layer, Domain, IsFact, GrainDescription) VALUES
(1, 'BRONZE.USER_EVENTS_RAW', 'BRONZE', 'Events', FALSE, '1 row per user event_id (raw JSON payload)'),
(2, 'SILVER.USER_EVENTS_CLEAN', 'SILVER', 'Events', FALSE, '1 row per user event_id (parsed + standardized)'),
(3, 'GOLD.FACT_USER_EVENTS', 'GOLD', 'Events', TRUE, 'Aggregated counts by date, source, event_type'),
(4, 'GOLD.DIM_USER', 'GOLD', 'Reference', FALSE, '1 row per user_id'),
(5, 'BRONZE.BILLING_EVENTS_RAW', 'BRONZE', 'Billing', FALSE, '1 row per billing event_id (raw JSON payload)'),
(6, 'SILVER.BILLING_EVENTS_CLEAN', 'SILVER', 'Billing', FALSE, '1 row per billing event_id (parsed + standardized)'),
(7, 'GOLD.FACT_BILLING_EVENTS', 'GOLD', 'Billing', TRUE, 'Aggregated billing events by date, type, currency'),
(8, 'BRONZE.CRM_ACCOUNTS_SNAPSHOT', 'BRONZE', 'CRM', FALSE, 'Daily snapshot of CRM accounts'),
(9, 'SILVER.CRM_ACCOUNTS_CLEAN', 'SILVER', 'CRM', FALSE, 'Cleaned CRM accounts with standard fields'),
(10, 'GOLD.DIM_ACCOUNT', 'GOLD', 'CRM', FALSE, 'Account dimension table');

INSERT INTO DE_TERM_PROJECT.OPS.Job (JobID, PipelineID, JobTypeID, JobName, JobOrder, TargetDatasetID) VALUES
(1, 1, 1, 'Extract_UserEvents_To_Bronze', 1, 1),
(2, 1, 2, 'Transform_UserEvents_Bronze_To_Silver', 2, 2),
(3, 1, 3, 'Load_UserEvents_Silver_To_Gold', 3, 3),
(4, 2, 1, 'Extract_BillingEvents_To_Bronze', 1, 5),
(5, 2, 2, 'Transform_BillingEvents_Bronze_To_Silver', 2, 6),
(6, 2, 3, 'Load_BillingEvents_Silver_To_Gold', 3, 7),
(7, 3, 1, 'Extract_CRM_Accounts_Snapshot', 1, 8),
(8, 3, 2, 'Transform_CRM_Accounts_Clean', 2, 9),
(9, 3, 3, 'Load_CRM_Dim_Account', 3, 10);

INSERT INTO DE_TERM_PROJECT.OPS.JobDependency (ParentJobID, ChildJobID, DependencyType) VALUES
(1, 2, 'FINISH_TO_START'),
(2, 3, 'FINISH_TO_START'),
(4, 5, 'FINISH_TO_START'),
(5, 6, 'FINISH_TO_START'),
(7, 8, 'FINISH_TO_START'),
(8, 9, 'FINISH_TO_START');

INSERT INTO DE_TERM_PROJECT.OPS.DatasetLineage (UpstreamDatasetID, DownstreamDatasetID, TransformJobID) VALUES
('1', '2', '2'),
('2', '3', '3'),
('5', '6', '5'),
('6', '7', '6'),
('8', '9', '8'),
('9', '10', '9');

INSERT INTO DE_TERM_PROJECT.OPS.DQRule (RuleID, DatasetID, RuleName, RuleType, Threshold, IsBlocking) VALUES
(1, 2, 'user_event_id_not_null', 'NOT_NULL', NULL, TRUE),
(2, 2, 'min_user_events_row_count', 'ROW_COUNT_MIN', 1000.0, FALSE),
(3, 6, 'billing_event_id_not_null', 'NOT_NULL', NULL, TRUE),
(4, 6, 'min_billing_row_count', 'ROW_COUNT_MIN', 200.0, FALSE),
(5, 9, 'account_id_not_null', 'NOT_NULL', NULL, TRUE),
(6, 9, 'min_accounts_row_count', 'ROW_COUNT_MIN', 50.0, FALSE);

INSERT INTO DE_TERM_PROJECT.OPS.ExecutionRun (RunID, JobID, StatusID, StartTS, EndTS, RowsIn, RowsOut, ComputeResourceID) VALUES
(1, 1, 2, '2026-01-20 01:00:00', '2026-01-20 01:02:00', 0.0, 5200.0, 1),
(2, 2, 3, '2026-01-20 01:02:10', '2026-01-20 01:04:00', 5200.0, 0.0, 1),
(3, 3, 4, '2026-01-20 01:04:10', '2026-01-20 01:04:10', NULL, NULL, 1),
(4, 4, 2, '2026-01-20 01:10:00', '2026-01-20 01:12:00', 0.0, 800.0, 1),
(5, 5, 2, '2026-01-20 01:12:10', '2026-01-20 01:16:00', 800.0, 790.0, 1),
(6, 6, 2, '2026-01-20 01:16:10', '2026-01-20 01:18:00', 790.0, 45.0, 1),
(7, 7, 2, '2026-01-20 03:00:00', '2026-01-20 03:05:00', 0.0, 120.0, 2),
(8, 8, 2, '2026-01-20 03:05:10', '2026-01-20 03:12:00', 120.0, 118.0, 2),
(9, 9, 2, '2026-01-20 03:12:10', '2026-01-20 03:15:00', 118.0, 118.0, 2),
(10, 1, 2, '2026-01-21 01:00:00', '2026-01-21 01:02:00', 0.0, 5200.0, 1),
(11, 2, 2, '2026-01-21 01:02:10', '2026-01-21 01:06:00', 5200.0, 5150.0, 1),
(12, 3, 2, '2026-01-21 01:06:10', '2026-01-21 01:08:00', 5150.0, 120.0, 1),
(13, 4, 2, '2026-01-21 01:10:00', '2026-01-21 01:12:00', 0.0, 800.0, 1),
(14, 5, 3, '2026-01-21 01:12:10', '2026-01-21 01:14:00', 800.0, 0.0, 1),
(15, 6, 4, '2026-01-21 01:14:10', '2026-01-21 01:14:10', NULL, NULL, 1),
(16, 7, 2, '2026-01-21 03:00:00', '2026-01-21 03:05:00', 0.0, 120.0, 2),
(17, 8, 2, '2026-01-21 03:05:10', '2026-01-21 03:12:00', 120.0, 118.0, 2),
(18, 9, 2, '2026-01-21 03:12:10', '2026-01-21 03:15:00', 118.0, 118.0, 2),
(19, 1, 2, '2026-01-22 01:00:00', '2026-01-22 01:02:00', 0.0, 5200.0, 1),
(20, 2, 2, '2026-01-22 01:02:10', '2026-01-22 01:06:00', 5200.0, 5150.0, 1),
(21, 3, 2, '2026-01-22 01:06:10', '2026-01-22 01:08:00', 5150.0, 120.0, 1),
(22, 4, 2, '2026-01-22 01:10:00', '2026-01-22 01:12:00', 0.0, 800.0, 1),
(23, 5, 2, '2026-01-22 01:12:10', '2026-01-22 01:16:00', 800.0, 790.0, 1),
(24, 6, 2, '2026-01-22 01:16:10', '2026-01-22 01:18:00', 790.0, 45.0, 1),
(25, 7, 2, '2026-01-22 03:00:00', '2026-01-22 03:05:00', 0.0, 120.0, 2),
(26, 8, 3, '2026-01-22 03:05:10', '2026-01-22 03:08:00', 120.0, 0.0, 2),
(27, 9, 4, '2026-01-22 03:08:10', '2026-01-22 03:08:10', NULL, NULL, 2);

INSERT INTO DE_TERM_PROJECT.OPS.FailureLog (FailureID, RunID, ErrorTS, ErrorCode, ErrorMessage, RetryCount) VALUES
(1, 2, '2026-01-20 01:03:00', 'PARSER_ERR', 'Invalid JSON payload for event_id=UE-1042', 1),
(2, 14, '2026-01-21 01:13:00', 'SCHEMA_MISMATCH', 'Unexpected field ''payment_status'' in payload', 2),
(3, 26, '2026-01-22 03:06:00', 'CONSTRAINT_VIOLATION', 'Duplicate account_id detected during merge', 0);

INSERT INTO DE_TERM_PROJECT.OPS.DQResult (ResultID, RuleID, RunID, ResultTS, PassFail, MetricValue) VALUES
(1, 1, 2, '2026-01-20 01:03:30', FALSE, NULL),
(2, 2, 2, '2026-01-20 01:03:35', FALSE, 0.0),
(3, 3, 5, '2026-01-20 01:15:20', TRUE, NULL),
(4, 4, 5, '2026-01-20 01:15:25', TRUE, 790.0),
(5, 5, 8, '2026-01-20 03:10:00', TRUE, NULL),
(6, 6, 8, '2026-01-20 03:10:05', TRUE, 118.0),
(7, 1, 11, '2026-01-21 01:05:30', TRUE, NULL),
(8, 2, 11, '2026-01-21 01:05:35', TRUE, 5150.0),
(9, 3, 14, '2026-01-21 01:13:20', FALSE, NULL),
(10, 4, 14, '2026-01-21 01:13:25', FALSE, 0.0),
(11, 5, 17, '2026-01-21 03:10:00', TRUE, NULL),
(12, 6, 17, '2026-01-21 03:10:05', TRUE, 118.0),
(13, 1, 20, '2026-01-22 01:05:30', TRUE, NULL),
(14, 2, 20, '2026-01-22 01:05:35', TRUE, 5150.0),
(15, 3, 23, '2026-01-22 01:15:20', TRUE, NULL),
(16, 4, 23, '2026-01-22 01:15:25', TRUE, 790.0),
(17, 5, 26, '2026-01-22 03:06:30', FALSE, NULL),
(18, 6, 26, '2026-01-22 03:06:35', FALSE, 0.0);

-- Raw BRONZE events provided separately as JSONL files.

--TEST

SELECT 'CloudProvider'   AS table_name, COUNT(*) AS row_count FROM OPS.CloudProvider
UNION ALL SELECT 'ResourceType',    COUNT(*) FROM OPS.ResourceType
UNION ALL SELECT 'SourceType',      COUNT(*) FROM OPS.SourceType
UNION ALL SELECT 'JobType',         COUNT(*) FROM OPS.JobType
UNION ALL SELECT 'RunStatus',       COUNT(*) FROM OPS.RunStatus
UNION ALL SELECT 'CloudResource',   COUNT(*) FROM OPS.CloudResource
UNION ALL SELECT 'DataSource',      COUNT(*) FROM OPS.DataSource
UNION ALL SELECT 'Pipeline',        COUNT(*) FROM OPS.Pipeline
UNION ALL SELECT 'PipelineSource',  COUNT(*) FROM OPS.PipelineSource
UNION ALL SELECT 'Dataset',         COUNT(*) FROM OPS.Dataset
UNION ALL SELECT 'Job',             COUNT(*) FROM OPS.Job
UNION ALL SELECT 'JobDependency',   COUNT(*) FROM OPS.JobDependency
UNION ALL SELECT 'DatasetLineage',  COUNT(*) FROM OPS.DatasetLineage
UNION ALL SELECT 'DQRule',          COUNT(*) FROM OPS.DQRule
UNION ALL SELECT 'ExecutionRun',    COUNT(*) FROM OPS.ExecutionRun
UNION ALL SELECT 'FailureLog',      COUNT(*) FROM OPS.FailureLog
UNION ALL SELECT 'DQResult',        COUNT(*) FROM OPS.DQResult
ORDER BY table_name;


SELECT
  table_name,
  row_count
FROM DE_TERM_PROJECT.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'OPS'
ORDER BY table_name;




