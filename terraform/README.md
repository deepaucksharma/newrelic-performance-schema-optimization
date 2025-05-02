# Performance Schema Automation Terraform Module

This directory contains a complete Terraform module for implementing Performance Schema (P_S) automation on AWS RDS and Aurora MySQL databases with New Relic monitoring.

## Module Features

- Creates optimized Parameter Groups for RDS/Aurora
- Deploys Lambda function for runtime configuration
- Configures EventBridge rules for automation triggers
- Sets up CloudWatch monitoring and alerting
- Implements security best practices with IAM and VPC configuration
- Optional RDS Proxy configuration for improved connection management

## Usage

```hcl
module "perf_schema_automation" {
  source = "path/to/this/module"

  # Basic configuration
  prefix               = "myapp"
  parameter_family     = "mysql8.0"
  is_aurora            = false
  
  # Database information
  db_instance_identifier    = "mydb"
  db_instance_resource_id   = "db-ABCDEF123456789"
  db_host                   = "mydb.abcdefg.us-east-1.rds.amazonaws.com"
  db_security_group_id      = "sg-01234567890abcdef"
  
  # Network configuration
  vpc_id               = "vpc-01234567890abcdef"
  subnet_ids           = ["subnet-1", "subnet-2", "subnet-3"]
  
  # Authentication
  db_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mydb-credentials-ABCDEF"
  use_iam_auth         = true
  
  # RDS Proxy configuration
  create_proxy         = true
  
  # Alerting
  sns_topic_arn        = "arn:aws:sns:us-east-1:123456789012:db-alerts"
  create_alarms        = true
  
  # Performance Schema configuration
  max_digest_length    = "1024"
  max_sql_text_length  = "4096"
  performance_schema_hash = "46b5fa75e2ee862b8903e17b8fc9a5ee22e9812fa86af68cc37c3e659ecfe0fd"
  
  # Tags
  tags = {
    Environment = "Production"
    Service     = "New Relic Monitoring"
    Managed_By  = "Terraform"
  }
}
```

## Aurora-Specific Configuration

For Aurora clusters, use these settings:

```hcl
module "perf_schema_automation" {
  source = "path/to/this/module"
  
  # Aurora-specific settings
  is_aurora              = true
  parameter_family       = "aurora-mysql8.0"
  cluster_parameter_family = "aurora-mysql8.0"
  db_cluster_identifier  = "mycluster"
  db_cluster_resource_id = "cluster-ABCDEF123456789"
  
  # ... other settings as above
}
```

## Input Variables

See [variables.tf](variables.tf) for a complete list of input variables and their descriptions.

## Outputs

See [outputs.tf](outputs.tf) for a complete list of outputs.

## Implementation Notes

1. **Database User Setup**: This module assumes you've created the `lambda_perf_schema` user in your database:

   ```sql
   -- For IAM authentication (recommended)
   CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
   ```

2. **Parameter Group Application**: After applying this module, you must associate the created parameter group with your RDS instance or Aurora cluster and restart the database to apply the settings.

3. **Secrets Manager**: When using password authentication, create a secret in AWS Secrets Manager with the format:
   ```json
   {
     "username": "lambda_perf_schema",
     "password": "your-secure-password"
   }
   ```

## Customization

You can customize the SQL statements applied to Performance Schema by modifying the `sql_update_statements` variable. The default statements are optimized for New Relic monitoring.

## Security Considerations

1. **IAM Authentication**: We strongly recommend using IAM authentication rather than password authentication for the database connection.

2. **VPC Configuration**: The Lambda function operates within your VPC and requires outbound connectivity to your database.

3. **Least Privilege**: The IAM roles are configured with least privilege principles.

## Monitoring

The module creates CloudWatch Logs metric filters and optionally CloudWatch Alarms to monitor Performance Schema configuration drift and error conditions.

---

© New Relic, Inc. | Internal use and authorized customers only