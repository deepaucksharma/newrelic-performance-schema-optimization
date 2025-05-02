# Performance Schema SQL Configuration Scripts

This directory contains SQL scripts for configuring MySQL Performance Schema (P_S) for optimal integration with New Relic monitoring.

## Files

- `perf-schema-configuration.sql`: Complete SQL script for Performance Schema configuration and verification

## Manual Configuration

While the primary goal of this repository is to automate Performance Schema configuration, these scripts can also be used for manual configuration in environments where automation isn't feasible.

### Prerequisites

- MySQL 5.7+ or Aurora MySQL compatible database
- Database user with SELECT and UPDATE privileges on the performance_schema tables
- MySQL client or administration tool (MySQL Workbench, CLI, etc.)

### Steps for Manual Configuration

1. Connect to your MySQL/Aurora database:
   ```bash
   mysql -h your-db-host -u admin -p
   ```

2. Create a dedicated user for Performance Schema management (if using automation):
   ```sql
   -- For IAM authentication (recommended for AWS environments)
   CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
   FLUSH PRIVILEGES;
   
   -- For password authentication (alternative)
   CREATE USER 'perf_schema_admin'@'%' IDENTIFIED BY 'strong-password';
   GRANT SELECT, UPDATE ON performance_schema.* TO 'perf_schema_admin'@'%';
   FLUSH PRIVILEGES;
   ```

3. Apply the Performance Schema configuration:
   ```bash
   mysql -h your-db-host -u admin -p < perf-schema-configuration.sql
   ```

4. Verify the configuration was applied correctly:
   ```sql
   -- Check consumer settings
   SELECT NAME, ENABLED 
   FROM performance_schema.setup_consumers
   WHERE NAME LIKE 'events%'
   ORDER BY NAME;
   
   -- Check statement instruments
   SELECT COUNT(*) AS enabled_statements
   FROM performance_schema.setup_instruments
   WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';
   
   -- Check wait instruments (should be limited)
   SELECT COUNT(*) AS enabled_waits
   FROM performance_schema.setup_instruments
   WHERE NAME LIKE 'wait/%' AND ENABLED = 'YES';
   ```

## Using with AWS RDS Parameter Groups

For persistent Performance Schema settings, create a custom parameter group with:

| Parameter | Value | Notes |
|-----------|-------|-------|
| performance_schema | 1 | Master switch |
| performance_schema_consumer_events_statements_current | 1 | Required for SQL metrics |
| performance_schema_consumer_events_statements_history | 1 | Required for recent history |
| performance_schema_consumer_events_statements_history_long | 0 | High overhead |
| performance_schema_consumer_events_waits_current | 0 | High overhead |
| performance_schema_max_digest_length | 1024 | Balanced setting |
| performance_schema_max_sql_text_length | 4096 | Balanced setting |

## Integration with New Relic

After applying the Performance Schema configuration, verify the integration with New Relic:

1. Wait approximately 5 minutes for data collection
2. Navigate to New Relic One > Databases
3. Select your MySQL/Aurora instance
4. Verify that query samples and digest statistics are appearing

## Maintenance

The Performance Schema configuration in this script needs to be reapplied after database restarts or failovers. Consider implementing the automation solution in this repository for consistent configuration.

---

© New Relic, Inc. | Internal use and authorized customers only