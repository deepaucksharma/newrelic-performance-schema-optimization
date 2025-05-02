# Reliably Configuring MySQL Performance Schema on AWS RDS/Aurora for New Relic Monitoring

**The core problem**  
`UPDATE` statements on `performance_schema.setup_*` tables are memory-only inside
RDS/Aurora. After every reboot, fail-over or version upgrade they disappear, breaking
New Relic monitoring and creating observation gaps.

**Solution in two layers**

| Layer | Purpose | How we implement |
|-------|---------|------------------|
| **Parameter Group** | Persistent baseline: `performance_schema = 1`, buffer sizes, any consumer flags exposed by AWS | 1× DB parameter group per engine family |
| **Lambda Automation** | Re-apply _all other_ consumer / instrument UPDATEs after every event & on a daily schedule | EventBridge rule → Lambda in VPC, IAM Auth, YAML target-state file in S3 |

> **Benefits**   Consistent metrics · 40-70 % ingest savings · < 8 % CPU overhead · zero manual re-configuration

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

### 3. Create Database User

Create the MySQL user for Lambda using IAM authentication:

```sql
CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
GRANT SELECT ON information_schema.* TO 'lambda_perf_schema'@'%';
FLUSH PRIVILEGES;
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

## Documentation

| Resource | Description |
|----------|-------------|
| [Technical Guide](docs/GUIDE.md) | Detailed explanation of the solution architecture |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Solutions for common issues |
| [CloudFormation Deployment](cloudformation/README.md) | CloudFormation template details |
| [Terraform Deployment](terraform/README.md) | Terraform module usage |
| [SQL Configuration](sql/README.md) | Understanding and customizing the target configuration |

## Customizing Configuration

To customize which Performance Schema components are enabled/disabled, edit the `sql/target-config.yaml` file and update it in S3.

## Support

For assistance, contact New Relic DB Engineering: db-support@newrelic.com

_Related AWS feature_: **Performance Insights** is a managed alternative; see Appendix in docs/GUIDE.md.
