# Getting Started with New Relic MySQL Performance Schema Optimization

This guide will help you quickly deploy the Performance Schema optimization solution for MySQL/Aurora on AWS.

## Solution Overview

The solution consists of two key components:

1. **Parameter Group** - Provides persistent baseline configuration 
2. **Lambda Automation** - Re-applies runtime configuration after events

## Quick Start

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

### 2. Deploy Using CloudFormation or Terraform

#### CloudFormation Deployment:

```bash
aws cloudformation deploy \
  --template-file cloudformation/perf-schema-automation.yaml \
  --stack-name nr-perf-schema-optimizer \
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

### 3. Create Database User

Create the MySQL user for Lambda using IAM authentication:

```sql
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT ON performance_schema.* TO 'lambda_perf_schema'@'%';
GRANT SELECT ON information_schema.* TO 'lambda_perf_schema'@'%';
```

### 4. Attach Parameter Group

1. Go to the AWS RDS console
2. Select your MySQL instance or Aurora cluster
3. Click "Modify"
4. Under "Additional configuration", select the newly created parameter group:
   - For CloudFormation: The group name is in stack outputs
   - For Terraform: Use the parameter_group_name output
5. Select "Apply immediately"
6. Click "Continue" and "Modify DB Instance"

### 5. Verify Configuration

After the database reboots:

```sql
-- Check if Performance Schema is enabled
SHOW VARIABLES LIKE 'performance_schema';

-- Check consumer status
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
 WHERE NAME IN ('events_statements_current','statements_digest');

-- Check instrument status
SELECT NAME, ENABLED, TIMED FROM performance_schema.setup_instruments
 WHERE NAME LIKE 'statement/%' LIMIT 5;
```

Also check the Lambda CloudWatch logs to verify successful execution.

## Customizing Configuration

To customize which Performance Schema components are enabled/disabled, edit the `sql/target-config.yaml` file and update it in S3.

## Monitoring and Troubleshooting

* Check CloudWatch logs for Lambda execution details
* Review the parameter group status in RDS console 
* See `docs/TROUBLESHOOTING.md` for common issues and solutions

## Additional Resources

* `docs/GUIDE.md` - Detailed technical guide
* `docs/TROUBLESHOOTING.md` - Troubleshooting common issues

## Support

For assistance, contact New Relic DB Engineering: db-support@newrelic.com
