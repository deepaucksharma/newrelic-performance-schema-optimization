# AWS Performance Insights: The Recommended Approach for New Relic MySQL Monitoring (2025)

## Introduction

In 2025, AWS Performance Insights (PI) represents the optimal primary approach for monitoring MySQL/Aurora on AWS. This guide explains how to leverage Performance Insights with New Relic to achieve maximum observability with minimal overhead and configuration effort.

## Why Performance Insights?

Performance Insights provides significant advantages for RDS/Aurora MySQL monitoring:

- **Zero-configuration monitoring**: PI automatically enables the core Performance Schema components needed for monitoring
- **Single-digit percentage overhead**: Typically adds less than 5% CPU overhead to production workloads
- **Persistent across reboots**: Maintains configuration through instance restarts and failovers
- **Enhanced visualization**: Built-in AWS dashboards complement New Relic's monitoring capabilities
- **Historical data retention**: Retains performance data for long-term analysis

## How Performance Insights Works

Performance Insights effectively becomes a "managed Performance Schema" solution that:

1. Automatically enables Performance Schema if disabled
2. Configures necessary consumers and instruments during runtime
3. Collects and aggregates metrics without requiring manual configuration
4. Exposes metrics via API and CloudWatch

> **Important Clarification**: While PI handles enabling core Performance Schema components, it doesn't typically modify buffer sizes (like performance_schema_digests_size, history_long_size, max_sql_text_length). You may still need to adjust these via Parameter Groups for high-diversity workloads to avoid query digest wrapping or truncation in New Relic.

## Setting Up Performance Insights

### 1. Enable Performance Insights

**Console Method:**
1. Navigate to the RDS or Aurora section of the AWS Console
2. Select your DB instance
3. Choose "Modify"
4. Under "Performance Insights", check "Enable Performance Insights"
5. Set the retention period (7 days free, or longer with additional cost)
6. Choose "Continue" and apply changes

**CLI Method:**
```bash
aws rds modify-db-instance \
  --db-instance-identifier your-instance-name \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

**Terraform Method:**
```hcl
resource "aws_db_instance" "example" {
  # Other configuration...
  performance_insights_enabled = true
  performance_insights_retention_period = 7 # 7 days free tier
}
```

### 2. Configure New Relic Integration

No special configuration is required for basic New Relic integration with Performance Insights. However, to maximize visibility:

1. Add to your New Relic MySQL configuration:
```yaml
mysql:
  extended_performance_schema_metrics: true
```

2. Ensure your New Relic monitoring user has appropriate permissions:
```sql
GRANT SELECT ON performance_schema.* TO 'newrelic'@'%';
```

Note: The once common practice of requiring full `PROCESS` and `REPLICATION CLIENT` privileges may be unnecessary for basic Performance Schema monitoring. Review your specific requirements before granting these broader permissions.

## Supplemental Parameter Group Settings

For workloads with high query diversity or to enhance New Relic's data collection beyond what PI configures, consider these Parameter Group settings:

```
performance_schema = 1
performance_schema_digests_size = 10000
performance_schema_events_statements_history_long_size = 10000
performance_schema_max_sql_text_length = 4096
```

These settings help ensure:
- Sufficient memory allocation for SQL digest storage
- Adequate history size for longer retention of statement history
- Complete capture of SQL query text for better identification

## Performance Schema Default State in Modern AWS MySQL

On modern RDS/Aurora MySQL 8.0 versions, the `performance_schema` variable itself may be ON in the default Parameter Group, but most data collection (consumers) remains disabled until explicitly enabled or managed by Performance Insights.

This is a key distinction from older MySQL 5.x versions, where the entire Performance Schema was typically disabled by default.

## Leveraging Recent MySQL 8.0 Improvements

MySQL 8.0.40+ includes significant improvements to the Performance Schema data_locks table design, with lock metadata sharding that drastically reduces contention. This means:

- Much lower overhead when monitoring lock waits
- Better scalability for high transaction workloads
- Improved stability when collecting lock metrics through Performance Schema

## Performance Insights Limitations

While Performance Insights is the recommended approach, be aware of these limitations:

- Limited customization compared to direct Performance Schema management
- Additional cost for extended retention periods beyond 7 days
- Not available on the smallest micro/nano instance classes (verify current support in AWS documentation)
- May not enable all consumers/instruments that specialized monitoring requires

## When to Supplement Performance Insights

Consider supplementing Performance Insights with direct Performance Schema configuration when:

1. You require specialized instrumentation not enabled by PI
2. You need higher collection granularity than PI provides
3. You're running on instance types where PI isn't available
4. You need to adjust buffer sizes for very high-diversity workloads

See our supplemental guides for these scenarios:
- [Implementation Guide](implementation-guide.md) for direct configuration
- [SQL Configuration Scripts](../sql/perf-schema-configuration.sql) for supplemental settings

## Integration with New Relic

Performance Insights works seamlessly with New Relic's MySQL integration:

1. New Relic collects Performance Schema metrics via its standard MySQL integration
2. PI ensures these metrics are available by maintaining the Performance Schema configuration
3. Combined, you get the best of both monitoring solutions with minimal setup effort

## Conclusion

In 2025, AWS Performance Insights represents the optimal starting point for monitoring MySQL/Aurora databases with New Relic. For most workloads, PI's automatic configuration delivers the perfect balance of comprehensive monitoring with minimal overhead and maintenance.

By following the "let AWS do the heavy lifting" approach with Performance Insights as your foundation, you achieve reliable, consistent monitoring while significantly reducing the operational burden of Performance Schema management.

---

© New Relic, Inc. | Internal use and authorized customers only