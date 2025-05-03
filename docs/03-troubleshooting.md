# Troubleshooting Guide: MySQL Performance Schema Monitoring

This guide addresses common issues and solutions for both Performance Insights and Lambda automation approaches.

## Performance Insights Issues

### Performance Insights Not Showing Data

**Symptoms**:
- Performance Insights dashboard is empty or shows "No data"
- Status says "Enabled" but no metrics appear

**Resolution**:
1. Verify Performance Insights is properly enabled on the instance
2. Ensure database has sufficient activity to generate metrics
3. Check if `performance_schema = 1` in database parameters
4. Validate that the RDS instance type supports Performance Insights
5. Wait 5-10 minutes for initial data collection

### Limited Metrics in Performance Insights

**Symptoms**:
- Only partial metrics appear in PI dashboard
- Missing statement details or wait events

**Resolution**:
1. Ensure you're using a compatible MySQL version (5.7+ recommended)
2. Check if Performance Schema is fully enabled
3. Consider supplementing with Parameter Group settings

## Parameter Group Issues

### Parameter Group Not Applied

**Symptoms**:
- Performance schema still shows as disabled (`performance_schema = 0`)
- No metrics appearing in New Relic
- Lambda function logs indicate failures

**Resolution**:
1. Verify parameter group is associated with your RDS/Aurora instance
2. Confirm instance has been rebooted after parameter group attachment
3. Check for "pending-reboot" status in AWS console
4. For Aurora, ensure parameter group is associated with the cluster

### Parameter Changes Not Taking Effect

**Symptoms**:
- Changes to parameter group don't appear when checking database variables

**Resolution**:
1. Verify you modified the correct parameter group
2. Check parameter is modifiable and not read-only
3. Confirm parameter applies at the correct level (instance vs. cluster)
4. Reboot the instance if the parameter requires a reboot
5. For Aurora, some parameters require cluster-level changes

## Lambda Automation Issues

### Lambda Execution Failures

**Symptoms**:
- CloudWatch logs show connection errors
- No changes applied after instance reboot
- Error messages in Lambda logs

**Common causes and fixes**:

| Issue | Resolution |
|-------|------------|
| **VPC/Network** | Ensure Lambda has proper subnet access to RDS/Aurora; confirm security groups allow port 3306 |
| **IAM Auth** | Verify IAM user exists **and** has `GRANT SELECT, UPDATE ON performance_schema.*` |
| **Permissions** | Confirm Lambda role has `rds-db:connect` permissions for target database |
| **S3 Access** | Check Lambda can access S3 bucket with YAML config |
| **Timeout** | Increase Lambda timeout if connection is slow |
| **Memory** | Increase Lambda memory if processing large configuration |

### Partial Configuration

**Symptoms**:
- Some metrics appear in New Relic, others missing
- Inconsistent behavior after failovers

**Resolution**:
1. Check for conflicts between Lambda configuration and Performance Insights
2. Review logs for partial application of settings
3. Verify `target-config.yaml` contains complete desired state
4. Manually run the verification queries in the [Implementation Guide](02-implementation.md)

### Lambda Not Triggered on Events

**Symptoms**:
- Lambda doesn't execute after database restarts or failovers

**Resolution**:
1. Check EventBridge rule configuration for correct event patterns
2. Verify Lambda permissions allow EventBridge invocation
3. Check CloudTrail for event delivery issues
4. Manually invoke Lambda to test functionality

## Performance & Overhead Concerns

If you observe higher than expected CPU usage:

1. Consider reducing the scope of enabled instruments
2. Focus on statement-level metrics rather than waits
3. Increase the `performance_schema_digests_size` if digest table is full
4. Check if P_S memory parameters need tuning
5. For MySQL 8.0, use Performance Insights in preference to custom configuration

## New Relic Integration Issues

**No metrics in New Relic**:

1. Verify New Relic Infrastructure agent is properly installed
2. Check that the MySQL integration is enabled with correct credentials
3. Ensure MySQL user has SELECT permissions on performance_schema
4. Review New Relic logs for connectivity issues
5. Validate that Performance Schema is enabled and properly configured

## Getting Support

If you encounter persistent issues:

1. **Gather diagnostics**:
   - Performance Insights dashboard screenshots (if enabled)
   - Lambda CloudWatch logs (if using Lambda automation)
   - Output of verification SQL queries
   - Current parameter group settings
   - AWS RDS/Aurora events from past 24 hours

2. **Contact New Relic Support**:
   - Email: db-support@newrelic.com
   - Include "Performance Schema Optimization" in subject line
   - Attach diagnostic information
