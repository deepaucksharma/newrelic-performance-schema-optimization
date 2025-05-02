-- New Relic Optimized Performance Schema Configuration for MySQL/Aurora
-- These scripts configure Performance Schema for optimal balance between 
-- monitoring visibility and performance overhead.

-- =====================================================================
-- 1. Database User Creation (Run as admin user)
-- =====================================================================

-- Option A: Create user for IAM Authentication (recommended)
CREATE USER IF NOT EXISTS 'lambda_perf_schema'@'%' 
  IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
FLUSH PRIVILEGES;

-- Option B: Create user with password authentication (if not using IAM)
-- CREATE USER IF NOT EXISTS 'lambda_perf_schema'@'%' 
--   IDENTIFIED BY 'use-a-strong-password-stored-in-secrets-manager';
-- GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
-- FLUSH PRIVILEGES;

-- =====================================================================
-- 2. Performance Schema Configuration (Applied via automation)
-- =====================================================================

-- Enable Required Consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest',
  'global_instrumentation',
  'thread_instrumentation'
);

-- Disable High-Overhead Consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'NO'
WHERE NAME IN (
  'events_statements_history_long',
  'events_stages_current',
  'events_stages_history',
  'events_stages_history_long',
  'events_waits_current', 
  'events_waits_history',
  'events_waits_history_long',
  'events_transactions_current',
  'events_transactions_history',
  'events_transactions_history_long'
);

-- Enable SQL Statement Tracking
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME LIKE 'statement/%';

-- Disable High-Volume, Low-Value Instruments
UPDATE performance_schema.setup_instruments
SET ENABLED = 'NO', TIMED = 'NO'
WHERE NAME LIKE 'wait/io/file/%'
   OR NAME LIKE 'wait/io/table/%'
   OR NAME LIKE 'wait/lock/metadata/%'
   OR NAME LIKE 'wait/lock/table/%'
   OR NAME LIKE 'wait/sync/rwlock/%'
   OR NAME LIKE 'wait/sync/mutex/%'
   OR NAME LIKE 'wait/sync/cond/%';

-- Selectively Enable Critical Wait Instruments for Diagnostics
-- Uncomment only if specifically needed for troubleshooting
-- UPDATE performance_schema.setup_instruments
-- SET ENABLED = 'YES', TIMED = 'YES' 
-- WHERE NAME IN (
--   'wait/io/file/innodb/innodb_data_file',
--   'wait/io/file/innodb/innodb_log_file',
--   'wait/io/file/sql/binlog',
--   'wait/lock/table/sql/handler'
-- );

-- =====================================================================
-- 3. Verification Queries (For manual checks)
-- =====================================================================

-- Check if Performance Schema is enabled
SELECT @@performance_schema;

-- Check consumer settings
SELECT NAME, ENABLED 
FROM performance_schema.setup_consumers
ORDER BY NAME;

-- Check instrument settings
SELECT COUNT(*) AS statement_instruments_enabled
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';

SELECT COUNT(*) AS wait_instruments_enabled
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'wait/%' AND ENABLED = 'YES';

-- Check for high-impact instruments that should be disabled
SELECT NAME, ENABLED, TIMED 
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'wait/sync/mutex/%' AND ENABLED = 'YES'
LIMIT 10;

-- =====================================================================
-- 4. Generate Configuration Hash (For drift detection)
-- =====================================================================

-- This query generates a state string for hashing in Lambda function
SELECT 
  GROUP_CONCAT(
    CONCAT(c.NAME, ':', c.ENABLED) 
    ORDER BY c.NAME SEPARATOR ';'
  ) AS consumer_state,
  (
    SELECT COUNT(*) 
    FROM performance_schema.setup_instruments 
    WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES'
  ) AS statement_count,
  (
    SELECT COUNT(*) 
    FROM performance_schema.setup_instruments 
    WHERE NAME LIKE 'wait/%' AND ENABLED = 'YES'
  ) AS wait_count
FROM 
  performance_schema.setup_consumers c;

-- =====================================================================
-- 5. New Relic Integration Verification (After configuration)
-- =====================================================================

-- These queries check data that should be visible in New Relic
-- after proper Performance Schema configuration

-- Check statement digests (should appear in New Relic)
SELECT 
  SCHEMA_NAME,
  DIGEST_TEXT,
  COUNT_STAR,
  SUM_TIMER_WAIT,
  MAX_TIMER_WAIT,
  SUM_ROWS_AFFECTED
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Check for statement history (should appear in New Relic)
SELECT 
  TRUNCATE(TIMER_WAIT/1000000000000, 6) as exec_time_sec,
  SQL_TEXT
FROM performance_schema.events_statements_history
ORDER BY TIMER_START DESC
LIMIT 5;

-- =====================================================================
-- 6. Cleanup (Use only when removing automation)
-- =====================================================================

-- Remove database user (only when decommissioning the automation)
-- DROP USER IF EXISTS 'lambda_perf_schema'@'%';

-- Reset Performance Schema to default settings (not recommended in production)
-- UPDATE performance_schema.setup_consumers SET ENABLED = 'YES';
-- UPDATE performance_schema.setup_instruments SET ENABLED = 'YES', TIMED = 'YES';