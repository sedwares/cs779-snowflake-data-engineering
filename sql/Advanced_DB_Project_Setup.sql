-- Create the Warehouse first
CREATE OR REPLACE WAREHOUSE DE_TERM_WH 
WITH WAREHOUSE_SIZE = 'XSMALL' 
AUTO_SUSPEND = 60 
AUTO_RESUME = TRUE;

USE WAREHOUSE DE_TERM_WH;
USE DATABASE DE_TERM_PROJECT;
USE SCHEMA OPS;

SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();

------------------------------------

--Show BRONZE raw JSON (5)
SELECT payload FROM BRONZE.USER_EVENTS_RAW LIMIT 3;

--Show SILVER parsed
SELECT * FROM SILVER.USER_EVENTS_CLEAN LIMIT 10;

--Show GOLD aggregation
SELECT * FROM GOLD.FACT_USER_EVENTS_DAILY ORDER BY event_date DESC;


-------------------------------------
--Recursive CTE (8)
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
WITH RECURSIVE lineage_cte AS (
    -- Anchor: start at a chosen upstream dataset
    SELECT
        UpstreamDatasetID,
        DownstreamDatasetID,
        1 AS level
    FROM DatasetLineage
    WHERE UpstreamDatasetID = 1

    UNION ALL

    -- Recursive step: walk downstream dependencies
    SELECT
        d.UpstreamDatasetID,
        d.DownstreamDatasetID,
        l.level + 1 AS level
    FROM DatasetLineage d
    JOIN lineage_cte l
      ON d.UpstreamDatasetID = l.DownstreamDatasetID
)
SELECT
    level,
    UpstreamDatasetID,
    DownstreamDatasetID
FROM lineage_cte
ORDER BY level, UpstreamDatasetID, DownstreamDatasetID;

------------------------------------

--EXPLAIN Recursive CTE (9)
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
EXPLAIN
WITH RECURSIVE lineage_cte AS (
    SELECT
        UpstreamDatasetID,
        DownstreamDatasetID,
        1 AS level
    FROM DatasetLineage
    WHERE UpstreamDatasetID = 1

    UNION ALL

    SELECT
        d.UpstreamDatasetID,
        d.DownstreamDatasetID,
        l.level + 1 AS level
    FROM DatasetLineage d
    JOIN lineage_cte l
      ON d.UpstreamDatasetID = l.DownstreamDatasetID
)
SELECT
    level,
    UpstreamDatasetID,
    DownstreamDatasetID
FROM lineage_cte
ORDER BY level, UpstreamDatasetID, DownstreamDatasetID;

------------------------------------

--Distributed Execution Analysis (Query Profile) (10)
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

WITH RECURSIVE lineage_cte AS (
    SELECT
        UpstreamDatasetID,
        DownstreamDatasetID,
        1 AS level
    FROM DatasetLineage
    WHERE UpstreamDatasetID = 1

    UNION ALL

    SELECT
        d.UpstreamDatasetID,
        d.DownstreamDatasetID,
        l.level + 1 AS level
    FROM DatasetLineage d
    JOIN lineage_cte l
      ON d.UpstreamDatasetID = l.DownstreamDatasetID
)
SELECT
    level,
    UpstreamDatasetID,
    DownstreamDatasetID
FROM lineage_cte
ORDER BY level;

---------------------------------

--Clustering Comparison (11)
ALTER TABLE DatasetLineage DROP CLUSTERING KEY; 

ALTER TABLE DatasetLineage
CLUSTER BY (UpstreamDatasetID);

ALTER SESSION SET USE_CACHED_RESULT = FALSE;

WITH RECURSIVE lineage_cte AS (
    SELECT
        UpstreamDatasetID,
        DownstreamDatasetID,
        1 AS level
    FROM DatasetLineage
    WHERE UpstreamDatasetID = 1

    UNION ALL

    SELECT
        d.UpstreamDatasetID,
        d.DownstreamDatasetID,
        l.level + 1 AS level
    FROM DatasetLineage d
    JOIN lineage_cte l
      ON d.UpstreamDatasetID = l.DownstreamDatasetID
)
SELECT
    level,
    UpstreamDatasetID,
    DownstreamDatasetID
FROM lineage_cte
ORDER BY level;


---------------------

SHOW TABLES IN SCHEMA OPS; --you can show cluster

-------------------------

--VARIANT (12)

SELECT RUNID
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
ORDER BY RUNID DESC
LIMIT 10;

ALTER TABLE DE_TERM_PROJECT.OPS.EXECUTIONRUN
ADD COLUMN IF NOT EXISTS RUN_PAYLOAD VARIANT;

UPDATE DE_TERM_PROJECT.OPS.EXECUTIONRUN
SET RUN_PAYLOAD = PARSE_JSON('{
  "orchestrator": "Airflow",
  "dag_run_id": "manual__2026-02-23",
  "warehouse_size": "MEDIUM",
  "params": { "start_dataset_id": 1 },
  "notes": "VARIANT demo payload for presentation"
}')
WHERE RUNID = 25;

-- Presentation
SELECT
  RUNID,
  RUN_PAYLOAD:orchestrator::STRING AS orchestrator,
  RUN_PAYLOAD:warehouse_size::STRING AS warehouse_size,
  RUN_PAYLOAD:params:start_dataset_id::NUMBER AS start_dataset_id,
  RUN_PAYLOAD:notes::STRING AS notes
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
WHERE RUN_PAYLOAD IS NOT NULL
ORDER BY RUNID DESC;

-------------------------
--Time Travel (13)

--Past Version
SELECT *
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
AT (OFFSET => -60*5);

--Using Timestamp
SELECT *
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
AT (TIMESTAMP => '2026-02-23 12:45:00'::TIMESTAMP);

-- Presentation

ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT * -- Run this first
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
WHERE RUNID=20

--Update the row and run SELECT above
UPDATE DE_TERM_PROJECT.OPS.EXECUTIONRUN
SET RUN_PAYLOAD = PARSE_JSON('{
  "notes": "UPDATED for Time Travel demo",
  "ts": "now",
  "orchestrator": "Airflow"
}')
WHERE RUNID = 20;

--Run this before 30 seconds
SELECT RUNID, RUN_PAYLOAD
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
AT (OFFSET => -15)
WHERE RUNID = 20;

------------------------
--SLA Monitoring - 1 - Breach Detection (14)

SELECT
    RUNID,
    JOBID,
    DATEDIFF('second', STARTTS, ENDTS) AS runtime_seconds,
    CASE
        WHEN DATEDIFF('second', STARTTS, ENDTS) > 300
        THEN 'SLA_BREACH'
        ELSE 'OK'
    END AS sla_status
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN;

-------------------------

--SLA Monitoring - 2 - Aggregate Monitoring

SELECT
    JOBID,
    COUNT(*) AS total_runs,
    AVG(DATEDIFF('second', STARTTS, ENDTS)) AS avg_runtime_seconds,
    MAX(DATEDIFF('second', STARTTS, ENDTS)) AS max_runtime_seconds
FROM DE_TERM_PROJECT.OPS.EXECUTIONRUN
GROUP BY JOBID
ORDER BY avg_runtime_seconds DESC;


-------------------------

--Failures / monitoring view (15)

SELECT
  p.PipelineName,
  j.JobName,
  rs.StatusName,
  er.StartTS,
  fl.ErrorCode,
  fl.ErrorMessage
FROM OPS.ExecutionRun er
JOIN OPS.RunStatus rs ON er.StatusID = rs.StatusID
JOIN OPS.Job j        ON er.JobID = j.JobID
JOIN OPS.Pipeline p   ON j.PipelineID = p.PipelineID
LEFT JOIN OPS.FailureLog fl ON er.RunID = fl.RunID
ORDER BY er.StartTS DESC;

-------------------------

--Data Quality results (16)
SELECT
  d.DatasetName,
  r.RuleName,
  r.IsBlocking,
  qr.PassFail,
  qr.MetricValue,
  qr.ResultTS
FROM OPS.DQResult qr
JOIN OPS.DQRule r  ON qr.RuleID = r.RuleID
JOIN OPS.Dataset d ON r.DatasetID = d.DatasetID
ORDER BY qr.ResultTS DESC;

--SHOW TABLES LIKE 'DATASETLINEAGE' IN SCHEMA OPS;
--SELECT COUNT(*) FROM DatasetLineage;


----------------------------------------

--Generate rows 
CREATE OR REPLACE TABLE DatasetLineage AS
WITH groups AS (
  SELECT SEQ4() AS g
  FROM TABLE(GENERATOR(ROWCOUNT => 3000000)) -- 3 million chains
),
edges AS (
  SELECT g.g, e.seq AS n
  FROM groups g
  CROSS JOIN (
    SELECT SEQ4()+1 AS seq
    FROM TABLE(GENERATOR(ROWCOUNT => 9))
  ) e
)
SELECT
  (g * 1000) + n       AS UpstreamDatasetID,
  (g * 1000) + (n + 1) AS DownstreamDatasetID
FROM edges;

----------------------------------------

