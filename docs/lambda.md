# Lambda Automation for Performance Schema

This guide details the Lambda automation approach for maintaining MySQL Performance Schema configuration on AWS RDS and Aurora.

## Why Use Lambda Automation?

While AWS Performance Insights is the recommended approach for most users, Lambda automation is valuable when:

1. You're using instance types where Performance Insights isn't available
2. You need to enable specific instruments or consumers not activated by PI
3. You have specialized monitoring requirements beyond standard PI configuration
4. You need to ensure consistent configuration across many databases

## How Lambda Automation Works

The Lambda function:

1. Is triggered by a daily schedule and RDS restart/failover events
2. Loads a YAML configuration file from S3 defining the desired state
3. Connects to the database and checks current Performance Schema settings
4. Calculates the difference between current and desired state
5. Applies the necessary SQL UPDATE statements in a transaction
6. Reports success or failure to CloudWatch logs

## Target Configuration

The YAML configuration file defines exactly which Performance Schema components should be enabled:

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

This configuration is optimized for New Relic monitoring, focusing on high-value metrics while minimizing overhead.

## Implementation Steps

### 1. Prepare S3 Storage

Upload the Lambda code and configuration files:

```bash
# Build Lambda package and layer
cd lambda
bash build.sh

# Upload files to S3
aws s3 cp lambda.zip s3://YOUR-BUCKET/lambda.zip
aws s3 cp pymysql-pyyaml-layer.zip s3://YOUR-BUCKET/pymysql-pyyaml-layer.zip
aws s3 cp ../sql/target-config.yaml s3://YOUR-BUCKET/target-config.yaml
```

### 2. Create Database User

Create a dedicated user with appropriate permissions:

```sql
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
GRANT SELECT ON information_schema.* TO 'lambda_perf_schema'@'%';
FLUSH PRIVILEGES;
```

### 3. Deploy Using CloudFormation or Terraform

#### CloudFormation Deployment:

```bash
aws cloudformation deploy \
  --template-file cloudformation/perf-schema-automation.yaml \
  --stack-name nr-perf-schema-optimizer \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      DatabaseId=YOUR-DB-ID \
      IsAurora=false \
      SqlBucket=YOUR-BUCKET \
      SqlKey=target-config.yaml \
      VpcId=vpc-xxxxx \
      SubnetIds='["subnet-xxxxx","subnet-yyyyy"]' \
      UseIamAuth=true \
      NewRelicAccountId=YOUR-NR-ACCOUNT
```

#### Terraform Deployment:

```bash
cd terraform
terraform init
terraform apply -var="database_id=YOUR-DB-ID" \
                -var="sql_bucket=YOUR-BUCKET" \
                -var="vpc_id=vpc-xxxxx" \
                -var="subnet_ids=[\"subnet-xxxxx\",\"subnet-yyyyy\"]"
```

### 4. Verify Deployment

After deployment, check:

1. That the Lambda function was created correctly
2. That EventBridge rules are configured
3. That the Lambda has appropriate IAM permissions
4. That the database user exists with correct permissions

## Lambda Architecture Details

### Trigger Sources

* **Daily check**: `rate(1 day)`
* **RDS events**: `RDS-EVENT-0004`, `0045`, `0046`, `0071`, `0006`, and others

### Flow Diagram

```text
EventBridge → Lambda → RDS/Aurora
          ↘ CloudWatch Logs + Metrics
                 ↘ optional SNS Alert
```

### Lambda Logic

The function performs these steps:

1. Load YAML from S3 (`target-config.yaml`)
2. Query current state (`setup_consumers`, `setup_instruments`)
3. Compute diff → generate minimal `UPDATE` SET statements
4. If drift → run inside one transaction
5. Emit structured log `{ drift_detected, patch_applied, error }`

## Using with Performance Insights

If you're using Performance Insights alongside Lambda automation:

1. **Ensure Compatible Configurations**: Make sure your Lambda target config doesn't undo PI's automated changes
2. **Consider Manual Mode for PI**: Some users may prefer to set PI to manual mode to prevent conflicts

## Customizing the Solution

To adapt the solution to your specific needs:

1. Modify the `target-config.yaml` file to include different instruments and consumers
2. Adjust the Lambda timeout and memory settings based on your database size
3. Add additional CloudWatch alarms or notifications
4. Incorporate RDS Proxy for improved connection management

## Troubleshooting

For common issues and their solutions, see the [Troubleshooting Guide](03-troubleshooting.md).
