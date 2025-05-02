# Customer Guide: Optimizing MySQL Monitoring with New Relic and AWS (2025)

## Decision Tree: Choosing the Right Approach

| Requirement | Recommended Approach |
|-------------|---------------------|
| **Standard monitoring needs** | Start with **AWS Performance Insights** (PI) as primary solution ([Performance Insights Guide](performance-insights-guide.md)) |
| **PI not available** or **Enhanced granularity needed** | Use **Lambda Automation** approach (this guide + [Implementation Guide](implementation-guide.md)) |
| **Very large or complex workloads** | Use **PI + Parameter Group + Lambda** for comprehensive coverage |

> **New for 2025**: For most MySQL on AWS deployments, Performance Insights provides the simplest path to effective monitoring with minimal overhead. The Lambda automation approach detailed below should be considered complementary for specialized use cases.

## Introduction

This guide helps you optimize MySQL monitoring on AWS RDS and Aurora using New Relic, with a primary focus on leveraging AWS Performance Insights (PI) complemented by targeted Performance Schema (P_S) configurations where needed.

### The Challenge of Database Monitoring

Effective database monitoring provides critical performance insights, but improper configuration can:

1. **Generate excessive data volume** - increasing New Relic ingest costs
2. **Consume unnecessary system resources** - adding significant CPU overhead
3. **Create monitoring noise** - making it harder to identify real issues
4. **Reset consumer & instrument rows after restarts/failovers** - causing inconsistent observability (parameter group variables persist)

### Key Benefits of Our Recommended Approach

* **Reduced costs** - Lower New Relic data ingest volume (typically 40-70% savings)
* **Improved performance** - Typically adds less than 5% CPU overhead
* **Focused monitoring** - Capture only metrics that drive actionable insights
* **Consistent visibility** - AWS-managed configuration ensures persistent monitoring
* **Simplified management** - Let AWS do the heavy lifting via Performance Insights

## Primary Recommendation: Let AWS Do the Heavy Lifting

Our primary recommendation for 2025 is to leverage AWS Performance Insights (PI) as your foundation for monitoring MySQL/Aurora databases. Performance Insights:

- Automatically enables and configures core Performance Schema components
- Maintains configuration through instance restarts and failovers
- Provides comprehensive monitoring with minimal overhead
- Delivers persistent visibility without manual intervention

For a complete guide to implementing this approach, see our [Performance Insights Guide](performance-insights-guide.md).

## Supplemental Performance Schema Configuration

While Performance Insights handles the core configuration, you may want to supplement it with these settings for optimal New Relic integration:

### 1. Supplemental Parameter Group Settings

| Parameter | Recommended Value | Notes |
|-----------|-------------------|-------|
| `performance_schema` | `1` (ON) | Usually managed by PI, but ensure it's explicitly enabled |
| `performance_schema_digests_size` | `10000` | Ensures adequate memory for query digest storage |
| `performance_schema_max_sql_text_length` | `4096` | Capture full query text for better identification |
| `performance_schema_events_statements_history_long_size` | `10000` | Sufficient history for New Relic's longer-term analysis |

### 2. New Relic-Specific Optimizations

For workloads requiring specific insights beyond what Performance Insights enables automatically, you can apply these additional SQL configurations. Note that with Performance Insights, these typically only need to be applied for specialized monitoring needs:

```sql
-- For MySQL 8.0: Enable specific instruments for New Relic that may not be enabled by PI
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME LIKE 'statement/%';

-- Selectively enable important wait instruments that provide valuable context
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME IN (
  'wait/io/file/innodb/innodb_data_file',
  'wait/io/file/innodb/innodb_log_file',
  'wait/lock/table/sql/handler'
);

-- For specialized monitoring, you may need to enable these consumers
-- Note: Performance Insights typically manages these automatically
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest'
);
```

> **Important**: On MySQL 8.0.40+, lock table monitoring has significantly reduced overhead due to architectural improvements, making it more practical to monitor these events.

## Implementation Options

For modern MySQL monitoring on AWS in 2025, we recommend this approach:

1. **Primary Layer**: AWS Performance Insights (managed Performance Schema)
2. **Supplemental Layer**: Parameter Group adjustments for buffer sizes and specialized settings
3. **Optional Layer**: Targeted SQL configuration for specialized monitoring needs

Depending on your requirements, you can implement:

**Option A (Recommended): Performance Insights + Parameter Group**
- Enable Performance Insights for automatic Performance Schema management
- Apply supplemental Parameter Group settings for optimization
- Use New Relic's extended Performance Schema metrics

**Option B: Fully Automated Performance Schema Management**
Only necessary if Performance Insights doesn't meet your needs or isn't available:
- Complete Parameter Group configuration 
- Lambda + EventBridge automation for runtime settings
- Scheduled verification and maintenance

See our companion documents for detailed implementation guidance:
* [Performance Insights Guide](performance-insights-guide.md) (Recommended Primary Approach)
* [Technical Implementation Guide](implementation-guide.md) (Supplemental Configuration)
* [Automation Strategy Comparison](automation-comparison.md)
* [Infrastructure as Code Examples](../terraform/README.md)

## Verifying Your Configuration

### Performance Insights Verification

1. **AWS Console**: Navigate to RDS > Databases > Your Instance > Monitoring > Performance Insights
2. Verify that the dashboard is showing active data
3. Check that "Performance Schema" is listed as the data source

### Performance Schema Configuration Verification

For supplemental configurations, verify proper setup:

```sql
-- Check the overall Performance Schema state (should be ON)
-- On MySQL 8.0, this is typically enabled even in default Parameter Groups
SELECT @@performance_schema;

-- Verify key consumers are enabled (typically handled by PI)
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
WHERE NAME IN ('events_statements_current', 'events_statements_history', 'statements_digest');

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
