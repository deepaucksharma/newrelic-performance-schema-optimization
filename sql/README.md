# SQL and Configuration Files

This directory contains SQL scripts and the target configuration YAML file for Performance Schema optimization.

## Files

- `target-config.yaml` - The canonical desired state specification for Performance Schema
- `perf-schema-configuration.sql` - SQL script with manual configuration commands
- `verification.sql` - Queries to verify the configuration is applied correctly

## Target Configuration YAML

The `target-config.yaml` file defines which Performance Schema components should be enabled and disabled. This file is read by the Lambda function to determine what changes to apply.

Key sections:

```yaml
consumers_enabled:
  # List of performance_schema.setup_consumers to enable
  - events_statements_current
  - events_statements_history
  - statements_digest

instruments_enabled_prefixes:
  # Instrument prefixes to enable (with wildcard matching)
  - statement/%
  - memory/performance_schema

instruments_enabled_exact:
  # Specific instruments to enable (exact matches)
  - wait/io/file/innodb/innodb_data_file
  - wait/io/file/innodb/innodb_log_file

instruments_disabled_prefixes:
  # Instrument prefixes to disable (with wildcard matching)
  - wait/sync/%
  - events_stages_%
```

## Customization

To customize the Performance Schema configuration:

1. Edit the `target-config.yaml` file according to your monitoring needs
2. Upload the modified file to your S3 bucket:
   ```bash
   aws s3 cp target-config.yaml s3://YOUR-BUCKET/target-config.yaml
   ```
3. The Lambda function will apply the changes on its next execution

## New Relic Optimization

The default configuration in `target-config.yaml` is optimized for New Relic MySQL monitoring:

- Enables statement digests for query performance tracking
- Captures key I/O and lock metrics
- Disables low-value or high-overhead instruments
- Provides optimal balance between monitoring and performance

This reduces data ingest volume by 40-70% while maintaining visibility into important metrics.

## Manual Configuration

If you need to manually configure Performance Schema, use the `perf-schema-configuration.sql` script as a reference. Execute these commands on your MySQL instance:

```bash
mysql -h YOUR_HOST -u admin -p < perf-schema-configuration.sql
```

Note that manual configuration will be lost after a reboot or failover, which is why the automated solution is recommended.

## Verification

To verify that the configuration has been applied correctly, you can use:

```sql
-- Check if Performance Schema is enabled
SHOW VARIABLES LIKE 'performance_schema';

-- Verify consumers are enabled
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
WHERE NAME IN ('events_statements_current','events_statements_history','statements_digest');

-- Check instrument status for statements (should be enabled)
SELECT NAME, ENABLED, TIMED FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%' LIMIT 5;

-- Check disabled instruments
SELECT COUNT(*) FROM performance_schema.setup_instruments
WHERE NAME LIKE 'wait/sync/%' AND ENABLED = 'NO';
```

## Additional Notes

- Changes to `performance_schema` variable itself require a database reboot
- The Lambda function only changes runtime configuration, not persistent variables
- For persistent settings, modify the Parameter Group in the IaC templates
