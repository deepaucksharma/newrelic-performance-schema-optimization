# Customer Guide: Optimizing Performance Schema for New Relic Monitoring

## Introduction

This guide helps you optimize MySQL Performance Schema (P_S) on AWS RDS and Aurora to ensure efficient monitoring with New Relic while minimizing system overhead and data costs.

### Why Optimize Performance Schema?

Performance Schema provides critical insights into your database performance, but the default configuration can:

1. **Generate excessive data volume** - increasing New Relic ingest costs
2. **Consume unnecessary system resources** - adding CPU overhead of 5-15%
3. **Create monitoring noise** - making it harder to identify real issues
4. **Reset after restarts/failovers** - causing inconsistent observability

### Key Benefits of Optimized Configuration

* **Reduced costs** - Lower New Relic data ingest volume (typically 40-70% savings)
* **Improved performance** - Minimal overhead on production databases
* **Focused monitoring** - Capture only metrics that drive actionable insights
* **Consistent visibility** - Automated configuration ensures persistent monitoring
* **Compliance** - Auditable, consistent monitoring configuration across environments

## New Relic Recommended Performance Schema Settings

The following configuration optimizes Performance Schema for most workloads monitored by New Relic:

### 1. Essential Parameter Group Settings

| Parameter | Recommended Value | Notes |
|-----------|-------------------|-------|
| `performance_schema` | `1` (ON) | Master switch for Performance Schema |
| `performance_schema_consumer_events_statements_current` | `1` (ON) | Required for SQL statement metrics |
| `performance_schema_consumer_events_statements_history` | `1` (ON) | Recent statement history |
| `performance_schema_consumer_events_statements_history_long` | `0` (OFF) | High overhead, disable unless needed |
| `performance_schema_consumer_events_waits_current` | `0` (OFF) | Enable only for deep diagnostics |
| `performance_schema_consumer_events_waits_history` | `0` (OFF) | High overhead, typically unnecessary |
| `performance_schema_max_digest_length` | `1024` | Balance between detail and memory usage |
| `performance_schema_max_sql_text_length` | `4096` | Capture adequate query text without excess |

### 2. Runtime SQL Configuration (Requires Automation)

These settings must be reapplied after any database restart or failover:

```sql
-- Enable only necessary statement consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest'
);

-- Disable high-overhead consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'NO'
WHERE NAME IN (
  'events_statements_history_long',
  'events_stages_current',
  'events_stages_history',
  'events_stages_history_long',
  'events_waits_current', 
  'events_waits_history',
  'events_waits_history_long'
);

-- Enable only statement instruments with timing
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME LIKE 'statement/%';

-- Disable high-volume, low-value instruments
UPDATE performance_schema.setup_instruments
SET ENABLED = 'NO', TIMED = 'NO'
WHERE NAME LIKE 'wait/io/file/%'
   OR NAME LIKE 'wait/io/table/%'
   OR NAME LIKE 'wait/lock/metadata/%'
   OR NAME LIKE 'wait/lock/table/%'
   OR NAME LIKE 'wait/sync/rwlock/%'
   OR NAME LIKE 'wait/sync/mutex/%'
   OR NAME LIKE 'wait/sync/cond/%';
```

## Implementation Options

AWS RDS/Aurora requires special handling for Performance Schema configuration:

1. **Parameter Groups**: Configure all available parameters via AWS Parameter Groups
2. **Runtime Configuration**: Implement automation to apply and maintain non-persistent settings

Our recommended approach is a multi-layered solution:

1. **Baseline Configuration**: AWS Parameter Groups via Infrastructure as Code
2. **Runtime Configuration**: Automated solution using Lambda and EventBridge

See our companion documents for detailed implementation guidance:
* [Technical Implementation Guide](implementation-guide.md)
* [Automation Strategy Comparison](automation-comparison.md)
* [Infrastructure as Code Examples](../terraform/README.md)

## Verifying Your Configuration

After implementing Performance Schema optimizations, verify proper configuration:

```sql
-- Verify consumers are configured correctly
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
WHERE NAME LIKE 'events%';

-- Verify instrument configuration
SELECT COUNT(*) AS enabled_instruments
FROM performance_schema.setup_instruments
WHERE ENABLED = 'YES';

-- Verify statement instruments are enabled
SELECT COUNT(*) AS enabled_statements
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';
```

## Monitoring with New Relic

Once properly configured, verify data in New Relic:

1. Navigate to **[one.newrelic.com](https://one.newrelic.com)** > **Databases**
2. Select your MySQL/Aurora instance
3. Verify the following data is present:
   * Query samples with execution times
   * Statement digest statistics
   * Query execution counts and latencies

## Getting Support

For assistance with Performance Schema optimization:

* Contact your New Relic Technical Account Manager
* Email our database specialists: db-support@newrelic.com
* Visit our documentation: [docs.newrelic.com/mysql-monitoring](https://docs.newrelic.com/mysql-monitoring)

---

© New Relic, Inc. | Internal use and authorized customers only