# Terraform Module for Performance Schema Automation

This directory contains a Terraform module for deploying the New Relic MySQL Performance Schema automation solution.

## Module Overview

The module creates all the resources needed to automatically maintain MySQL Performance Schema configuration on RDS/Aurora instances:

- DB Parameter Group with Performance Schema baseline settings
- Lambda function for runtime configuration management
- IAM roles and policies with least-privilege permissions
- Security group for Lambda VPC access
- EventBridge rules for scheduled and event-based triggers
- CloudWatch logging and optional alerting

## Prerequisites

Before using this module:

1. Build and upload the Lambda code:
   ```bash
   cd ../lambda
   ./build.sh
   aws s3 cp lambda.zip s3://YOUR-BUCKET/lambda.zip
   aws s3 cp pymysql-pyyaml-layer.zip s3://YOUR-BUCKET/pymysql-pyyaml-layer.zip
   ```

2. Upload the configuration YAML:
   ```bash
   aws s3 cp ../sql/target-config.yaml s3://YOUR-BUCKET/target-config.yaml
   ```

3. Ensure you have a VPC with subnets that can access your RDS/Aurora instances

## Usage

### Basic Usage

```hcl
module "perf_schema_automation" {
  source = "./path/to/module"

  database_id = "my-mysql-instance"
  sql_bucket  = "my-s3-bucket"
  vpc_id      = "vpc-12345678"
  subnet_ids  = ["subnet-1234abcd", "subnet-5678efgh"]
}
```

### Complete Example

```hcl
module "perf_schema_automation" {
  source = "./path/to/module"

  prefix         = "nr-mysql-perf"
  engine_family  = "mysql8.0"
  database_id    = "my-mysql-instance"
  is_aurora      = false
  sql_bucket     = "my-s3-bucket"
  sql_key        = "target-config.yaml"
  lambda_code_key = "lambda.zip"
  lambda_layer_key = "pymysql-pyyaml-layer.zip"
  vpc_id         = "vpc-12345678"
  subnet_ids     = ["subnet-1234abcd", "subnet-5678efgh"]
  use_iam_auth   = true
  db_user        = "lambda_perf_schema"
  new_relic_account_id = "12345"
  
  tags = {
    Environment = "production"
    Project     = "database-monitoring"
  }
  
  create_alarms = true
  log_retention_days = 30
}
```

## Input Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `prefix` | Prefix for resource names | `string` | `"nr-mysql-ps"` |
| `engine_family` | MySQL/Aurora engine family | `string` | `"mysql8.0"` |
| `database_id` | RDS instance or Aurora cluster ID | `string` | |
| `is_aurora` | Whether target is Aurora cluster | `bool` | `false` |
| `sql_bucket` | S3 bucket with config and code | `string` | |
| `sql_key` | S3 key for YAML config | `string` | `"target-config.yaml"` |
| `lambda_code_key` | S3 key for Lambda zip | `string` | `"lambda.zip"` |
| `lambda_layer_key` | S3 key for Lambda layer | `string` | `"pymysql-pyyaml-layer.zip"` |
| `vpc_id` | VPC ID for Lambda | `string` | |
| `subnet_ids` | Subnet IDs for Lambda | `list(string)` | |
| `db_secret_arn` | Secret ARN for credentials | `string` | `""` |
| `use_iam_auth` | Use IAM auth for DB | `bool` | `true` |
| `db_user` | Database username | `string` | `"lambda_perf_schema"` |
| `new_relic_account_id` | New Relic account ID | `string` | `""` |
| `tags` | Resource tags | `map(string)` | |
| `create_alarms` | Create CloudWatch alarms | `bool` | `true` |
| `log_retention_days` | Lambda log retention days | `number` | `14` |

## Outputs

| Name | Description |
|------|-------------|
| `parameter_group_name` | Created parameter group name |
| `parameter_group_arn` | Parameter group ARN |
| `lambda_function_name` | Lambda function name |
| `lambda_function_arn` | Lambda function ARN |
| `lambda_log_group_name` | CloudWatch log group name |
| `daily_check_rule_name` | Daily check EventBridge rule |
| `rds_events_rule_name` | RDS events EventBridge rule |
| `security_group_id` | Lambda security group ID |
| `db_user` | Database user name |
| `db_setup_command` | SQL command to create DB user |
| `next_steps` | Next steps after deployment |

## Post-Deployment

After successful deployment:

1. Attach the created parameter group to your RDS/Aurora instance
2. Create the required database user:
   ```sql
   CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
   GRANT SELECT ON information_schema.* TO 'lambda_perf_schema'@'%';
   FLUSH PRIVILEGES;
   ```
3. Reboot your database instance
4. Check CloudWatch logs to verify successful execution

## Customization

To customize the Performance Schema configuration, modify the `target-config.yaml` file and update it in S3. The Lambda function will use this configuration on its next execution.

## Using in Existing Infrastructure

To use this module with existing resources:

```hcl
# For existing VPC and subnets
module "perf_schema_automation" {
  source = "./path/to/module"
  
  database_id = aws_db_instance.existing.id
  vpc_id      = data.aws_vpc.existing.id
  subnet_ids  = data.aws_subnets.private.ids
  sql_bucket  = aws_s3_bucket.existing.id
  # ... other variables
}
```
