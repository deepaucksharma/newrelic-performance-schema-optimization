# Technical Implementation Guide: MySQL Monitoring Optimization (2025)

## Introduction

This technical guide provides detailed implementation instructions for optimizing MySQL/Aurora monitoring on AWS to ensure optimal integration with New Relic. Our 2025 recommended approach prioritizes:

1. **AWS Performance Insights**: Let AWS manage Performance Schema with minimal configuration
2. **Parameter Groups**: Supplement with persistent settings via AWS Parameter Groups
3. **Runtime Configuration**: Optional automation for specialized monitoring needs

> **Primary Recommendation**: For most workloads, AWS Performance Insights should be your foundation, with the other layers applied only as needed for specialized requirements.

## Layer 0: AWS Performance Insights (Primary Recommendation)

### Step 1: Enable Performance Insights

Performance Insights can be enabled on new or existing instances:

```bash
# Enable Performance Insights on an existing instance
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --enable-performance-insights \
  --performance-insights-retention-period 7

# For Aurora cluster instances
aws rds modify-db-instance \
  --db-instance-identifier mycluster-instance1 \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

Performance Insights activation is non-disruptive and doesn't require a database restart.

### Step 2: Verify Performance Insights Status

Check that PI is properly enabled:

```bash
# Describe the instance to check Performance Insights status
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[*].PerformanceInsightsEnabled'
```

### Step 3: Configure New Relic Integration

No special configuration is needed beyond standard MySQL integration. However, ensure your monitoring user has adequate permissions:

```sql
GRANT SELECT ON performance_schema.* TO 'newrelic'@'%';
```

## Layer 1: Supplemental Parameter Group Configuration

### Step 1: Identify Available Parameters

Different MySQL/Aurora versions expose different parameters. Check your specific engine version:

```bash
# List available Performance Schema parameters for your DB parameter group family
aws rds describe-db-parameters \
  --db-parameter-group-name default.aurora-mysql8.0 \
  --source user \
  --query 'Parameters[?ParameterName.contains(@, `performance_schema`)]'
```

### Step 2: Create Supplemental Parameter Group

Create a custom parameter group with settings to complement Performance Insights:

- Set or confirm `performance_schema = 1` (ON) - may already be ON in MySQL 8.0
- Configure buffer sizes for optimal monitoring:
  - `performance_schema_digests_size = 10000`
  - `performance_schema_max_sql_text_length = 4096`
  - `performance_schema_events_statements_history_long_size = 10000`

See the Infrastructure as Code examples for implementation details.

### Step 3: Apply Parameter Group

Associate the parameter group with your RDS instance or Aurora cluster:

```bash
# For RDS instance
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --db-parameter-group-name perf-schema-optimized

# For Aurora cluster
aws rds modify-db-cluster \
  --db-cluster-identifier mycluster \
  --db-cluster-parameter-group-name perf-schema-cluster-optimized
```

Applying Parameter Group changes typically requires an instance reboot or scheduled maintenance.

## Layer 2: Runtime Configuration Automation (Optional)

> **Note**: With Performance Insights enabled (Layer 0), this layer is optional and only necessary for specialized monitoring requirements that PI doesn't address automatically.

### Step 1: Determine if Runtime Configuration is Needed

Performance Insights automatically manages core Performance Schema settings. You only need runtime configuration automation if:

1. You're using instance types where Performance Insights isn't available
2. You need to enable specific instruments or consumers not activated by PI
3. You have specialized monitoring requirements beyond standard PI configuration

If you determine runtime configuration is necessary, proceed with VPC setup:

### Step 2: Set Up VPC Configuration

Ensure your Lambda function can access your RDS/Aurora database:

1. Create or use a VPC with private subnets in the same VPC as your database
2. Set up appropriate security groups:
   - Lambda security group: Allow outbound to database port (3306)
   - Database security group: Allow inbound from Lambda security group on port 3306

### Step 2: Configure RDS Proxy (Recommended)

RDS Proxy improves Lambda connection efficiency and enables IAM authentication:

1. Create an RDS Proxy targeting your database
2. Configure IAM Authentication
3. Set appropriate security groups

### Step 3: Create IAM Role for Lambda

Create an IAM role with these permissions:

- `rds-db:connect` - For IAM DB authentication
- Lambda VPC execution permissions
- CloudWatch Logs permissions
- EventBridge permissions
- Secrets Manager permissions (if not using IAM auth)

Sample IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:region:account:dbuser:*/lambda_perf_schema"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 4: Create Database User for Automation

Create a dedicated database user for the automation:

```sql
-- For IAM authentication (recommended)
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';

-- Alternatively, for password authentication
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED BY 'complex-password-stored-in-secrets-manager';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
```

### Step 5: Deploy Lambda Function

Create a Lambda function with:
- Runtime: Python 3.9+
- VPC configuration: Same VPC as your database
- Timeout: 30+ seconds
- Memory: 128+ MB
- Environment variables: Configuration settings

See the Lambda code examples for implementation details.

### Step 6: Configure EventBridge Rules

Create rules to trigger the Lambda:

1. **Scheduled rule**:
   - Schedule expression: `rate(1 day)` or `cron(0 0 * * ? *)`
   - Target: Your Lambda function

2. **RDS event rules**:
   - Event pattern: Match RDS/Aurora failover and restart events
   - Target: Your Lambda function

Sample event pattern:

```json
{
  "source": ["aws.rds"],
  "detail-type": ["RDS DB Instance Event", "RDS DB Cluster Event"],
  "detail": {
    "EventID": [
      "RDS-EVENT-0004", 
      "RDS-EVENT-0045", 
      "RDS-EVENT-0046", 
      "RDS-EVENT-0071", 
      "RDS-EVENT-0025", 
      "RDS-EVENT-0006"
    ]
  }
}
```

### Step 7: Set Up Monitoring and Alerting

Create CloudWatch metric filters and alarms:

1. Extract metrics from Lambda logs:
   - PerfSchemaDriftDetected
   - PerfSchemaPatchSuccess
   - PerfSchemaPatchFailure

2. Create alarms:
   - Alert on persistent drift (PerfSchemaDriftDetected > 0 for multiple periods)
   - Alert on patch failures

3. Create a CloudWatch dashboard for monitoring

## Validation and Testing

### Verify Parameter Group Settings

```sql
-- For MySQL 8.0, use targeted query to avoid hundreds of rows
SHOW VARIABLES WHERE Variable_name = 'performance_schema';
```

### Verify Runtime Settings

```sql
-- Check consumer configuration
SELECT NAME, ENABLED FROM performance_schema.setup_consumers;

-- Check instrument configuration
SELECT COUNT(*) AS enabled_instruments 
FROM performance_schema.setup_instruments 
WHERE ENABLED = 'YES';

-- Check statement instruments
SELECT COUNT(*) AS enabled_statements
FROM performance_schema.setup_instruments 
WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';
```

### Test Automation

1. **Scheduled execution**: Wait for scheduled execution or invoke Lambda manually
2. **Event-driven execution**: Trigger a manual failover or reboot
3. **Drift correction**: Manually change P_S settings to verify auto-correction

## Troubleshooting

### Common Issues

1. **Lambda cannot connect to database**:
   - Check VPC/subnet configuration
   - Verify security group rules
   - Ensure route tables allow traffic
   - Check RDS Proxy configuration (if used)

2. **Authentication failures**:
   - Verify IAM permissions
   - Check database user exists with correct authentication method
   - Validate database grants

3. **Lambda timeouts**:
   - Increase Lambda timeout
   - Optimize connection handling (RDS Proxy)
   - Implement better error handling

4. **Performance Schema not configured correctly**:
   - Check SQL statements for errors
   - Verify user has sufficient permissions
   - Check for database engine version differences

### Debugging

1. Review CloudWatch Logs for Lambda execution
2. Enable detailed logging in Lambda function
3. Test SQL statements directly against database
4. Verify event patterns trigger correctly

## Advanced Configuration

### Multi-Region Deployment

Deploy the solution in each AWS region with region-specific resources:
- Regional Parameter Groups
- Regional Lambda functions
- Regional EventBridge rules
- Regional RDS Proxies

### Multi-Account Deployment

Use AWS Organizations features:
- CloudFormation StackSets
- Service Catalog
- Terraform with remote state

### Blue/Green Deployments

1. Apply identical Parameter Groups to both Blue and Green environments
2. Ensure automation Lambda triggers after environment switch

---

© New Relic, Inc. | Internal use and authorized customers only