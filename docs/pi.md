# AWS Performance Insights Guide

This guide focuses on using AWS Performance Insights as the primary solution for optimizing MySQL Performance Schema monitoring with New Relic.

## What is Performance Insights?

AWS Performance Insights (PI) is a database performance tuning and monitoring feature built into Amazon RDS that:

- Automatically configures and manages Performance Schema settings
- Maintains configuration through database restarts and failovers
- Provides a dashboard for visualizing and analyzing database load
- Adds minimal overhead to your database instance
- Comes at no additional cost for 7 days of data retention

## Benefits for New Relic Monitoring

Using Performance Insights with New Relic provides several key advantages:

1. **Persistent Configuration**: PI maintains Performance Schema settings through restarts
2. **Reduced Management Overhead**: No need for custom Lambda functions to maintain settings
3. **Optimized Performance**: PI manages instrumentation with minimal impact
4. **Complementary Visualizations**: Use both PI and New Relic dashboards

## Enabling Performance Insights

### Console Method

1. Navigate to the AWS RDS console
2. Select your database instance
3. Click "Modify"
4. In the "Performance Insights" section, select "Enable Performance Insights"
5. Set your retention period (7 days is free, longer periods have additional costs)
6. Apply changes immediately or during maintenance window

### CLI Method

```bash
# For a standalone RDS instance
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --enable-performance-insights \
  --performance-insights-retention-period 7

# For an Aurora instance
aws rds modify-db-instance \
  --db-instance-identifier mycluster-instance1 \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

### Verifying Performance Insights Activation

```bash
# Check if Performance Insights is enabled
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[*].PerformanceInsightsEnabled'
```

## Performance Schema Settings with PI

When you enable Performance Insights, it automatically:

1. Enables Performance Schema (`performance_schema = 1`)
2. Configures statement and digest consumers
3. Enables appropriate instrumentation
4. Maintains these settings through restarts

You can supplement these settings with additional parameter group configurations as detailed in the [Implementation Guide](02-implementation.md).

## Using Performance Insights with New Relic

### New Relic Database User Permissions

Ensure your New Relic monitoring user has the necessary permissions:

```sql
GRANT SELECT ON performance_schema.* TO 'newrelic'@'%';
```

### Verifying Data in New Relic

After configuring both Performance Insights and New Relic:

1. Navigate to New Relic One > Databases
2. Check that query samples and digest statistics are appearing
3. Verify that statement execution times are being recorded

## When to Supplement with Lambda Automation

The Lambda automation approach described in [lambda.md](lambda.md) is recommended when:

1. You're using an instance type that doesn't support Performance Insights
2. You need specialized instrumentation not enabled by PI
3. You have specific performance monitoring requirements

For most standard monitoring needs, Performance Insights alone is sufficient.

## Performance Considerations

Performance Insights is designed to have minimal impact on your database:

- Typically adds less than 1% CPU overhead
- Automatically manages memory usage for Performance Schema tables
- Dynamically adjusts collection based on system load

## Additional Resources

- [AWS Documentation: Performance Insights](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
- [New Relic Documentation: MySQL Monitoring](https://docs.newrelic.com/docs/infrastructure/mysql-integration/get-started/mysql-integration/)
