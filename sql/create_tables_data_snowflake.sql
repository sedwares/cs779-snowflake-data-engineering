CREATE DATABASE IF NOT EXISTS DE_TERM_PROJECT;
CREATE SCHEMA IF NOT EXISTS DE_TERM_PROJECT.OPS;
CREATE SCHEMA IF NOT EXISTS DE_TERM_PROJECT.BRONZE;
CREATE SCHEMA IF NOT EXISTS DE_TERM_PROJECT.SILVER;
CREATE SCHEMA IF NOT EXISTS DE_TERM_PROJECT.GOLD;

USE WAREHOUSE DE_TERM_WH;
USE DATABASE DE_TERM_PROJECT;
USE SCHEMA OPS;

--SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();

--------------------------
--CREATING TABLES ON OPS
--------------------------

-- ---------- Lookup tables ----------
CREATE OR REPLACE TABLE CloudProvider (
  ProviderID      NUMBER(10,0)      NOT NULL,
  ProviderName    STRING            NOT NULL,
  CONSTRAINT PK_CloudProvider PRIMARY KEY (ProviderID)
);

CREATE OR REPLACE TABLE ResourceType (
  ResourceTypeID  NUMBER(10,0)      NOT NULL,
  TypeName        STRING            NOT NULL,
  CONSTRAINT PK_ResourceType PRIMARY KEY (ResourceTypeID)
);

CREATE OR REPLACE TABLE SourceType (
  SourceTypeID    NUMBER(10,0)      NOT NULL,
  TypeName        STRING            NOT NULL,
  CONSTRAINT PK_SourceType PRIMARY KEY (SourceTypeID)
);

CREATE OR REPLACE TABLE JobType (
  JobTypeID       NUMBER(10,0)      NOT NULL,
  TypeName        STRING            NOT NULL,
  CONSTRAINT PK_JobType PRIMARY KEY (JobTypeID)
);

CREATE OR REPLACE TABLE RunStatus (
  StatusID        NUMBER(10,0)      NOT NULL,
  StatusName      STRING            NOT NULL,
  CONSTRAINT PK_RunStatus PRIMARY KEY (StatusID)
);

-- ---------- Cloud + source metadata ----------
CREATE OR REPLACE TABLE CloudResource (
  ResourceID      NUMBER(10,0)      NOT NULL,
  ProviderID      NUMBER(10,0)      NOT NULL,
  ResourceTypeID  NUMBER(10,0)      NOT NULL,
  ResourceName    STRING            NOT NULL,
  Region          STRING,
  CostCenter      STRING,
  CONSTRAINT PK_CloudResource PRIMARY KEY (ResourceID),
  CONSTRAINT FK_CloudResource_Provider FOREIGN KEY (ProviderID)
    REFERENCES CloudProvider(ProviderID),
  CONSTRAINT FK_CloudResource_ResourceType FOREIGN KEY (ResourceTypeID)
    REFERENCES ResourceType(ResourceTypeID)
);

CREATE OR REPLACE TABLE DataSource (
  SourceID        NUMBER(10,0)      NOT NULL,
  SourceTypeID    NUMBER(10,0)      NOT NULL,
  SourceName      STRING            NOT NULL,
  ConnectionRef   STRING,
  OwnerTeam       STRING,
  CONSTRAINT PK_DataSource PRIMARY KEY (SourceID),
  CONSTRAINT FK_DataSource_SourceType FOREIGN KEY (SourceTypeID)
    REFERENCES SourceType(SourceTypeID)
);

-- ---------- Pipelines / datasets ----------
CREATE OR REPLACE TABLE Pipeline (
  PipelineID      NUMBER(10,0)      NOT NULL,
  PipelineName    STRING            NOT NULL,
  OwnerTeam       STRING,
  Criticality     STRING,
  SLA_Minutes     NUMBER(10,0),
  IsActive        BOOLEAN,
  CONSTRAINT PK_Pipeline PRIMARY KEY (PipelineID)
);

CREATE OR REPLACE TABLE Dataset (
  DatasetID          NUMBER(10,0)   NOT NULL,
  DatasetName        STRING         NOT NULL,
  Layer              STRING,
  Domain             STRING,
  IsFact             BOOLEAN,
  GrainDescription   STRING,
  CONSTRAINT PK_Dataset PRIMARY KEY (DatasetID)
  -- Optional: UNIQUE(DatasetName) if you want
);

-- Junction: Pipeline ↔ DataSource (M:N)
CREATE OR REPLACE TABLE PipelineSource (
  PipelineID      NUMBER(10,0)      NOT NULL,
  SourceID        NUMBER(10,0)      NOT NULL,
  CONSTRAINT PK_PipelineSource PRIMARY KEY (PipelineID, SourceID),
  CONSTRAINT FK_PipelineSource_Pipeline FOREIGN KEY (PipelineID)
    REFERENCES Pipeline(PipelineID),
  CONSTRAINT FK_PipelineSource_Source FOREIGN KEY (SourceID)
    REFERENCES DataSource(SourceID)
);

-- ---------- Jobs + dependencies ----------
CREATE OR REPLACE TABLE Job (
  JobID           NUMBER(10,0)      NOT NULL,
  PipelineID      NUMBER(10,0)      NOT NULL,
  JobTypeID       NUMBER(10,0)      NOT NULL,
  JobName         STRING            NOT NULL,
  JobOrder        NUMBER(10,0),
  TargetDatasetID NUMBER(10,0),
  CONSTRAINT PK_Job PRIMARY KEY (JobID),
  CONSTRAINT FK_Job_Pipeline FOREIGN KEY (PipelineID)
    REFERENCES Pipeline(PipelineID),
  CONSTRAINT FK_Job_JobType FOREIGN KEY (JobTypeID)
    REFERENCES JobType(JobTypeID),
  CONSTRAINT FK_Job_TargetDataset FOREIGN KEY (TargetDatasetID)
    REFERENCES Dataset(DatasetID)
);

-- Self-referencing dependencies: Job ↔ Job (M:N via junction)
CREATE OR REPLACE TABLE JobDependency (
  ParentJobID     NUMBER(10,0)      NOT NULL,
  ChildJobID      NUMBER(10,0)      NOT NULL,
  DependencyType  STRING,
  CONSTRAINT PK_JobDependency PRIMARY KEY (ParentJobID, ChildJobID),
  CONSTRAINT FK_JobDependency_Parent FOREIGN KEY (ParentJobID)
    REFERENCES Job(JobID),
  CONSTRAINT FK_JobDependency_Child FOREIGN KEY (ChildJobID)
    REFERENCES Job(JobID)
);

-- ---------- Execution + failure logs ----------
CREATE OR REPLACE TABLE ExecutionRun (
  RunID             NUMBER(10,0)    NOT NULL,
  JobID             NUMBER(10,0)    NOT NULL,
  StatusID          NUMBER(10,0)    NOT NULL,
  StartTS           TIMESTAMP_NTZ,
  EndTS             TIMESTAMP_NTZ,
  RowsIn            NUMBER(18,0),
  RowsOut           NUMBER(18,0),
  ComputeResourceID NUMBER(10,0),
  CONSTRAINT PK_ExecutionRun PRIMARY KEY (RunID),
  CONSTRAINT FK_ExecutionRun_Job FOREIGN KEY (JobID)
    REFERENCES Job(JobID),
  CONSTRAINT FK_ExecutionRun_Status FOREIGN KEY (StatusID)
    REFERENCES RunStatus(StatusID),
  CONSTRAINT FK_ExecutionRun_ComputeResource FOREIGN KEY (ComputeResourceID)
    REFERENCES CloudResource(ResourceID)
);

CREATE OR REPLACE TABLE FailureLog (
  FailureID      NUMBER(10,0)       NOT NULL,
  RunID          NUMBER(10,0)       NOT NULL,
  ErrorTS        TIMESTAMP_NTZ,
  ErrorCode      STRING,
  ErrorMessage   STRING,
  RetryCount     NUMBER(10,0),
  CONSTRAINT PK_FailureLog PRIMARY KEY (FailureID),
  CONSTRAINT FK_FailureLog_Run FOREIGN KEY (RunID)
    REFERENCES ExecutionRun(RunID)
);

-- ---------- Data lineage ----------
CREATE OR REPLACE TABLE DatasetLineage (
  UpstreamDatasetID    NUMBER(10,0) NOT NULL,
  DownstreamDatasetID  NUMBER(10,0) NOT NULL,
  TransformJobID       NUMBER(10,0) NOT NULL,
  CONSTRAINT PK_DatasetLineage PRIMARY KEY (UpstreamDatasetID, DownstreamDatasetID),
  CONSTRAINT FK_Lineage_Upstream FOREIGN KEY (UpstreamDatasetID)
    REFERENCES Dataset(DatasetID),
  CONSTRAINT FK_Lineage_Downstream FOREIGN KEY (DownstreamDatasetID)
    REFERENCES Dataset(DatasetID),
  CONSTRAINT FK_Lineage_TransformJob FOREIGN KEY (TransformJobID)
    REFERENCES Job(JobID)
);

-- ---------- Data quality ----------
CREATE OR REPLACE TABLE DQRule (
  RuleID        NUMBER(10,0)        NOT NULL,
  DatasetID     NUMBER(10,0)        NOT NULL,
  RuleName      STRING              NOT NULL,
  RuleType      STRING,
  Threshold     NUMBER(18,6),
  IsBlocking    BOOLEAN,
  CONSTRAINT PK_DQRule PRIMARY KEY (RuleID),
  CONSTRAINT FK_DQRule_Dataset FOREIGN KEY (DatasetID)
    REFERENCES Dataset(DatasetID)
);

CREATE OR REPLACE TABLE DQResult (
  ResultID      NUMBER(10,0)        NOT NULL,
  RuleID        NUMBER(10,0)        NOT NULL,
  RunID         NUMBER(10,0)        NOT NULL,
  ResultTS      TIMESTAMP_NTZ,
  PassFail      BOOLEAN,
  MetricValue   NUMBER(18,6),
  CONSTRAINT PK_DQResult PRIMARY KEY (ResultID),
  CONSTRAINT FK_DQResult_Rule FOREIGN KEY (RuleID)
    REFERENCES DQRule(RuleID),
  CONSTRAINT FK_DQResult_Run FOREIGN KEY (RunID)
    REFERENCES ExecutionRun(RunID)
);

-- ---------- Quick verification ----------
SHOW TABLES IN SCHEMA OPS;


-- BRONZE TABLES

USE WAREHOUSE DE_TERM_WH;
USE DATABASE DE_TERM_PROJECT;

CREATE OR REPLACE TABLE BRONZE.USER_EVENTS_RAW (
  payload VARIANT,
  loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE STAGE BRONZE_USER_EVENTS_STAGE;
CREATE OR REPLACE FILE FORMAT JSONL_FORMAT TYPE = JSON;

SELECT COUNT(*) FROM BRONZE.USER_EVENTS_RAW;

SELECT COUNT(*) AS row_count
FROM BRONZE.USER_EVENTS_RAW;


-- SILVER TABLES

CREATE OR REPLACE TABLE SILVER.USER_EVENTS_CLEAN (
  event_id STRING NOT NULL,
  event_ts TIMESTAMP_NTZ NOT NULL,
  source_name STRING,
  user_id STRING,
  event_type STRING,
  device STRING,
  country STRING,
  ip STRING,
  ingest_ts TIMESTAMP_NTZ,
  loaded_at TIMESTAMP_NTZ
);


INSERT INTO SILVER.USER_EVENTS_CLEAN (
  event_id, event_ts, source_name, user_id, event_type, device, country, ip, ingest_ts, loaded_at
)
SELECT
  payload:event_id::STRING                         AS event_id,
  TO_TIMESTAMP_NTZ(payload:event_ts::STRING)       AS event_ts,
  payload:source_name::STRING                      AS source_name,
  payload:payload:user_id::STRING                  AS user_id,
  payload:payload:event_type::STRING               AS event_type,
  payload:payload:device::STRING                   AS device,
  payload:payload:country::STRING                  AS country,
  payload:payload:ip::STRING                       AS ip,
  TO_TIMESTAMP_NTZ(payload:ingest_ts::STRING)      AS ingest_ts,
  loaded_at
FROM BRONZE.USER_EVENTS_RAW;


SELECT COUNT(*) FROM SILVER.USER_EVENTS_CLEAN;

SELECT *
FROM SILVER.USER_EVENTS_CLEAN
ORDER BY event_ts DESC
LIMIT 10;


-- GOLD TABLES

CREATE OR REPLACE TABLE GOLD.FACT_USER_EVENTS_DAILY AS
SELECT
  CAST(event_ts AS DATE) AS event_date,
  event_type,
  COUNT(*) AS events_count
FROM SILVER.USER_EVENTS_CLEAN
GROUP BY 1,2;

SELECT *
FROM GOLD.FACT_USER_EVENTS_DAILY
ORDER BY event_date DESC, event_type;








