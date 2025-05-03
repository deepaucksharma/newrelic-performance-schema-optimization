# Technical Implementation Guide: MySQL Monitoring Optimization

This guide provides detailed implementation instructions for optimizing MySQL/Aurora monitoring on AWS to ensure optimal integration with New Relic. Our recommended approach consists of multiple layers:

1. **AWS Performance Insights (Primary)**: Let AWS manage Performance Schema with minimal configuration
2. **Parameter Groups (Supplemental)**: Apply persistent settings via AWS Parameter Groups
3. **Lambda Automation (Optional)**: Runtime configuration for specialized monitoring needs

> **Primary Recommendation**: For most workloads, AWS Performance Insights should be your foundation, with the other layers applied only as needed for specialized requirements.

## The Persistence Problem

Runtime tables in `performance_schema` live in RAM; RDS/Aurora restarts wipe them. After a fail-over you lose consumers/instruments settings, which creates monitoring gaps in New Relic. While parameter group settings persist through restarts, many Performance Schema configurations can only be set via runtime SQL commands that don't persist.

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

## Layer 1: Parameter Group Configuration

### Step 1: Identify Available Parameters

Different MySQL/Aurora versions expose different parameters. Check your specific engine family:

```bash
# List available Performance Schema parameters for your DB parameter group family
aws rds describe-db-parameters \
  --db-parameter-group-name default.aurora-mysql8.0 \
  --source user \
  --query 'Parameters[?ParameterName.contains(@, `performance_schema`)]'
```

### Step 2: Create Parameter Group

Create a custom parameter group with these recommended settings:

| Parameter                                               | Value   | Note          |
| ------------------------------------------------------- | ------- | ------------- |
| `performance_schema`                                    | `1`     | master switch |
| `performance_schema_digests_size`                       | `10000` | 8 MiB         |
| `performance_schema_max_sql_text_length`                | `4096`  | full SQL text |
| `performance-schema-consumer-events-statements-current` | `1`     | where exposed |

You can create the parameter group using AWS CLI, Console, or Infrastructure as Code.

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

## Layer 2: Lambda Automation (Optional)

> **Note**: With Performance Insights enabled (Layer 0), this layer is optional and only necessary for specialized monitoring requirements that PI doesn't address automatically.

### When to Use Lambda Automation

You only need runtime configuration automation if:

1. You're using instance types where Performance Insights isn't available
2. You need to enable specific instruments or consumers not activated by PI
3. You have specialized monitoring requirements beyond standard PI configuration

### Target Configuration

The Lambda uses a YAML file to specify the desired Performance Schema state:

```yaml
# sql/target-config.yaml  <— referenced by Lambda
consumers_enabled:
  - events_statements_current
  - events_statements_history
  - statements_digest
instruments_enabled_prefixes:
  - statement/%
instruments_enabled_exact:
  - wait/io/file/innodb/innodb_data_file
  - wait/io/file/innodb/innodb_log_file
  - wait/lock/table/sql/handler
instruments_disabled_prefixes:
  - wait/sync/%
  - events_stages_%
  - events_%_history_long
```

Lambda enforces this **exact state** after every trigger event.

### Step 1: Set Up VPC Configuration

Ensure your Lambda function can access your RDS/Aurora database:

1. Create or use a VPC with private subnets in the same VPC as your database
2. Set up appropriate security groups:
   - **Lambda security group** (`${Prefix}-lambda-sg`): outbound TCP 3306 to the VPC.
   - **Database security group**: **add an *inbound* rule for TCP 3306 whose
     *source* is the Lambda security-group ID** (see the stack output
     `LambdaSecurityGroupId` or Terraform *security_group_id* output).  Without this rule the Lambda will time-out when
     connecting to MySQL.

### Step 2: Create IAM Role for Lambda

Create an IAM role with these permissions:

- `rds-db:connect` - For IAM DB authentication
- Lambda VPC execution permissions
- CloudWatch Logs permissions
- EventBridge permissions
- S3 permissions (for config file)
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

### Step 3: Create Database User for Automation

Create a dedicated database user for the automation:

```sql
-- For IAM authentication (recommended)
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';

-- Alternatively, for password authentication
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED BY 'complex-password-stored-in-secrets-manager';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
```

### Step 4: Deploy Lambda Function

The Lambda function logic follows this process:

1. Load YAML from S3 (`target-config.yaml`)
2. Query current state (`setup_consumers`, `setup_instruments`)
3. Compute diff → generate minimal `UPDATE` SET statements
4. If drift → run inside one transaction
5. Emit structured log `{ drift_detected, patch_applied, error }`

Create a Lambda function with:
- Runtime: Python 3.9+
- VPC configuration: Same VPC as your database
- Timeout: 30+ seconds
- Memory: 128+ MB
- Environment variables: Configuration settings

See the Infrastructure as Code examples in `/cloudformation` or `/terraform` directories.

### Step 5: Configure EventBridge Rules

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

### Step 6: Set Up Monitoring and Alerting

Create CloudWatch metric filters and alarms:

1. Extract metrics from Lambda logs:
   - PerfSchemaDriftDetected
   - PerfSchemaPatchSuccess
   - PerfSchemaPatchFailure

2. Create alarms:
   - Alert on persistent drift (PerfSchemaDriftDetected > 0 for multiple periods)
   - Alert on patch failures

## Infrastructure as Code

This solution can be deployed using:

* **CloudFormation**: Uses `cloudformation/perf-schema-automation.yaml`
* **Terraform**: Uses module in `terraform/`

Both create:
* DB Parameter Group
* Lambda (+ execution role, SG, Layer)
* EventBridge rules
* Optional CloudWatch alarms/dashboard

## Validation and Testing

### Verify Parameter Group Settings

```sql
-- Check if Performance Schema is enabled
SHOW VARIABLES LIKE 'performance_schema';
```

### Verify Runtime Settings

```sql
-- Check consumer configuration
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
WHERE NAME IN ('events_statements_current','statements_digest');

-- Check instrument configuration
SELECT COUNT(*) AS enabled_instruments 
FROM performance_schema.setup_instruments 
WHERE ENABLED = 'YES';

-- Check statement instruments
SELECT COUNT(*) AS enabled_statements
FROM performance_schema.setup_instruments 
WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';
```

### Verify Lambda Execution

Check the CloudWatch logs for your Lambda function:

```bash
aws logs tail /aws/lambda/[your-lambda-name] --since 1h
```

## Using Performance Insights with Lambda Automation

If you enable both Performance Insights and Lambda automation, you have two options:

1. **Configure PI in manual mode**: This prevents PI from automatically changing Performance Schema settings
2. **Ensure compatible configurations**: Make sure your Lambda target config doesn't conflict with PI's automated changes

For most workloads, we recommend letting Performance Insights manage core Performance Schema settings and only using Lambda for specialized configurations.

## New Relic Integration Benefits

This configuration has been optimized for New Relic Database monitoring:

* Reduces ingest volume by 40-70%
* Limits CPU overhead to under 8%
* Ensures consistent metrics collection 
* Focuses on high-value query metrics and resource utilization
* Prevents monitoring gaps after database events

---

For detailed troubleshooting guidance, see the [Troubleshooting Guide](03-troubleshooting.md).
