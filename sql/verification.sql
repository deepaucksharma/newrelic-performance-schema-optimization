-- Performance Schema Verification Script
-- Use to validate configuration after deployment

-- 1. Check if Performance Schema is enabled (requires parameter group)
SELECT 'Performance Schema Status' AS check_name, 
       IF(@@performance_schema = 1, 'ENABLED', 'DISABLED') AS status,
       'Parameter Group setting' AS notes;

-- 2. Check configured buffer sizes
SELECT 'Buffer Sizes' AS check_name, 
       CONCAT(
         'Digest size: ', @@performance_schema_digests_size,
         ', SQL text length: ', @@performance_schema_max_sql_text_length
       ) AS status,
       'From Parameter Group' AS notes;

-- 3. Verify consumers are properly configured
SELECT 'Consumer Status' AS check_name,
       c.NAME as component,
       c.ENABLED as status,
       CASE 
         WHEN c.NAME IN ('events_statements_current', 'events_statements_history', 'statements_digest') 
           AND c.ENABLED = 'YES' THEN 'Correctly Enabled'
         WHEN c.NAME IN ('events_statements_current', 'events_statements_history', 'statements_digest') 
           AND c.ENABLED = 'NO' THEN 'ERROR: Should be Enabled'
         WHEN c.NAME LIKE '%_history_long' AND c.ENABLED = 'NO' THEN 'Correctly Disabled'
         WHEN c.NAME LIKE '%_history_long' AND c.ENABLED = 'YES' THEN 'WARNING: High memory usage'
         ELSE ''
       END AS notes
FROM performance_schema.setup_consumers c
WHERE c.NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest',
  'events_statements_history_long',
  'events_stages_history_long'
)
ORDER BY c.NAME;

-- 4. Check statement instruments (should all be enabled)
SELECT 'Statement Instruments' AS check_name,
       COUNT(*) AS total,
       SUM(IF(ENABLED='YES' AND TIMED='YES', 1, 0)) as enabled_and_timed,
       CASE
         WHEN COUNT(*) = SUM(IF(ENABLED='YES' AND TIMED='YES', 1, 0)) THEN 'OK: All Enabled'
         ELSE CONCAT('ERROR: ', COUNT(*) - SUM(IF(ENABLED='YES' AND TIMED='YES', 1, 0)), ' not properly enabled')
       END AS notes
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%';

-- 5. Check specific wait instruments
SELECT 'Critical Wait Events' AS check_name,
       NAME as component,
       CONCAT(ENABLED, '/', TIMED) as status,
       CASE
         WHEN ENABLED='YES' AND TIMED='YES' THEN 'Correctly Configured'
         ELSE 'ERROR: Should be Enabled/Timed'
       END AS notes
FROM performance_schema.setup_instruments
WHERE NAME IN (
  'wait/io/file/innodb/innodb_data_file',
  'wait/io/file/innodb/innodb_log_file',
  'wait/lock/table/sql/handler',
  'wait/lock/metadata/sql/mdl'
);

-- 6. Check disabled instruments
SELECT 'Disabled Instrument Groups' AS check_name,
       prefix AS component,
       CONCAT(enabled_count, '/', total_count) AS status,
       CASE
         WHEN enabled_count = 0 THEN 'OK: All Disabled'
         ELSE 'WARNING: Some instruments enabled'
       END AS notes
FROM (
  SELECT 
    CASE
      WHEN NAME LIKE 'wait/sync/%' THEN 'wait/sync/%'
      WHEN NAME LIKE 'idle%' THEN 'idle%'
      WHEN NAME LIKE 'memory/sql/%' THEN 'memory/sql/%'
      WHEN NAME LIKE 'events_stages_%' THEN 'events_stages_%'
    END AS prefix,
    COUNT(*) AS total_count,
    SUM(IF(ENABLED='YES', 1, 0)) AS enabled_count
  FROM performance_schema.setup_instruments
  WHERE 
    NAME LIKE 'wait/sync/%' OR
    NAME LIKE 'idle%' OR
    NAME LIKE 'memory/sql/%' OR
    NAME LIKE 'events_stages_%'
  GROUP BY prefix
) t
ORDER BY prefix;

-- 7. Check for active statement metrics
SELECT 'Active Statement Metrics' AS check_name,
       COUNT(*) AS count,
       IF(COUNT(*) > 0, 'OK: Metrics being collected', 'WARNING: No statement metrics yet') AS notes
FROM performance_schema.events_statements_current
WHERE SQL_TEXT IS NOT NULL
LIMIT 1;

-- 8. Check digest table status
SELECT 'Digest Table Status' AS check_name,
       CONCAT(
         COUNT(*), ' entries, ', 
         ROUND(100 * COUNT(*) / @@performance_schema_digests_size, 2), '% full'
       ) AS status,
       CASE
         WHEN COUNT(*) > @@performance_schema_digests_size * 0.9 
           THEN 'WARNING: Digest table nearly full, consider increasing performance_schema_digests_size'
         ELSE 'OK'
       END AS notes
FROM performance_schema.events_statements_summary_by_digest;

-- 9. Check for lost instrumentation
SELECT 'Lost Instrumentation Check' AS check_name,
       VARIABLE_VALUE AS count,
       CASE
         WHEN VARIABLE_VALUE > 0 THEN 'WARNING: Some instrumentation lost, increase buffer sizes'
         ELSE 'OK: No lost instrumentation'
       END AS notes
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'performance_schema_digest_lost';
