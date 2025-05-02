# Troubleshooting Guide: MySQL Performance Schema Persistence

## Common Issues and Solutions

### Parameter Group Not Applied

**Symptoms**:
- Performance schema still shows as disabled (`performance_schema = 0`)
- No metrics appearing in New Relic
- Lambda function logs indicate failures

**Resolution**:
1. Verify parameter group is associated with your RDS/Aurora instance
2. Confirm instance has been rebooted after parameter group attachment
3. Check for "pending-reboot" status in AWS console

### Lambda Execution Failures

**Symptoms**:
- CloudWatch logs show connection errors
- No changes applied after instance reboot
- Error messages in Lambda logs

**Common causes and fixes**:

| Issue | Resolution |
|-------|------------|
| **VPC/Network** | Ensure Lambda has proper subnet access to RDS/Aurora; confirm security groups allow port 3306 |
| **IAM Auth** | Verify IAM user exists in MySQL: `CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS'` |
| **Permissions** | Confirm Lambda role has `rds-db:connect` permissions for target database |
| **S3 Access** | Check Lambda can access S3 bucket with YAML config |

### Partial Configuration

**Symptoms**:
- Some metrics appear in New Relic, others missing
- Inconsistent behavior after failovers

**Resolution**:
1. Check for conflicts between Lambda configuration and Performance Insights
2. Review logs for partial application of settings
3. Verify `target-config.yaml` contains complete desired state
4. Manually run the verification queries in GUIDE.md

### CPU Overhead Concerns

If you observe higher than expected CPU usage:

1. Consider reducing the scope of enabled instruments
2. Focus on statement-level metrics rather than waits
3. Increase the `performance_schema_digests_size` if digest table is full
4. Check if P_S memory parameters need tuning

### New Relic Integration Issues

**No metrics in New Relic**:

1. Verify New Relic Infrastructure agent is properly installed
2. Check that the MySQL integration is enabled with correct credentials
3. Ensure MySQL user has SELECT permissions on performance_schema
4. Review New Relic logs for connectivity issues

## Getting Support

If you encounter persistent issues:

1. **Gather diagnostics**:
   - Lambda CloudWatch logs
   - Output of verification SQL queries
   - Current parameter group settings
   - AWS RDS/Aurora events from past 24 hours

2. **Contact New Relic Support**:
   - Email: db-support@newrelic.com
   - Include "Performance Schema Automation" in subject line
   - Attach diagnostic information
