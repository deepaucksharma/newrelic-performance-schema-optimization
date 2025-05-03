-- New Relic Optimized Performance Schema Configuration for MySQL/Aurora (2025)
-- These scripts provide supplemental Performance Schema configurations
-- to complement AWS Performance Insights for optimal monitoring with New Relic.
--
-- PRIMARY RECOMMENDATION: Use AWS Performance Insights as your foundation,
-- and apply these configurations only as needed for specialized requirements.
--
-- Reminder: in RDS & Aurora parameter groups, use UNDERSCORES not hyphens

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
-- 2. Performance Schema Configuration (Supplemental to Performance Insights)
-- =====================================================================

-- NOTE: With Performance Insights enabled, many of these settings
-- are automatically managed. This script provides supplemental configurations
-- for specialized monitoring needs beyond what PI enables by default.

-- MySQL 8.0 Note: On MySQL 8.0, Performance Schema itself is typically ON
-- in default parameter groups, but most consumers are disabled until
-- explicitly enabled or managed by Performance Insights.

-- Additional Consumers for New Relic (if not enabled by PI)
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest',
  'global_instrumentation',
  'thread_instrumentation'
);

-- Ensure Statement Instruments are Enabled
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME LIKE 'statement/%';

-- Selectively Enable Valuable Wait Instruments 
-- MySQL 8.0.40+ has significantly improved lock table monitoring efficiency
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME IN (
  'wait/io/file/innodb/innodb_data_file',
  'wait/io/file/innodb/innodb_log_file',
  'wait/io/file/sql/binlog',
  'wait/lock/table/sql/handler'
);

-- Optional: Disable High-Volume, Low-Value Instruments
-- Consider enabling only specific instruments based on monitoring needs
UPDATE performance_schema.setup_instruments
SET ENABLED = 'NO', TIMED = 'NO'
WHERE NAME LIKE 'wait/sync/rwlock/%'
   OR NAME LIKE 'wait/sync/mutex/%'
   OR NAME LIKE 'wait/sync/cond/%';

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