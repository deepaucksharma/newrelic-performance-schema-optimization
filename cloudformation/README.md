# Performance Schema Automation CloudFormation Template

This directory contains a complete CloudFormation template for implementing Performance Schema (P_S) automation on AWS RDS and Aurora MySQL databases with New Relic monitoring.

## Template Features

- Creates optimized Parameter Groups for RDS/Aurora
- Deploys Lambda function for runtime configuration
- Configures EventBridge rules for automation triggers
- Sets up CloudWatch monitoring, alerting, and dashboards
- Implements security best practices with IAM and VPC configuration
- Optional RDS Proxy configuration for improved connection management
- Optional SNS notification system

## Deployment

### Using AWS Management Console

1. Navigate to the CloudFormation console
2. Click "Create stack" > "With new resources (standard)"
3. Select "Upload a template file" and upload `performance-schema-automation.yaml`
4. Follow the prompts to specify stack name and parameters
5. Review and create the stack

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name newrelic-perf-schema-optimization \
  --template-body file://performance-schema-automation.yaml \
  --parameters \
    ParameterKey=DatabaseIdentifier,ParameterValue=mydb \
    ParameterKey=IsAurora,ParameterValue=false \
    ParameterKey=DatabaseHost,ParameterValue=mydb.abcdefg.us-east-1.rds.amazonaws.com \
    ParameterKey=DatabaseSecretArn,ParameterValue=arn:aws:secretsmanager:region:account:secret:name \
    ParameterKey=VpcId,ParameterValue=vpc-01234567890abcdef \
    ParameterKey=SubnetIds,ParameterValue=subnet-1\\,subnet-2\\,subnet-3 \
    ParameterKey=DatabaseSecurityGroupId,ParameterValue=sg-01234567890abcdef \
    ParameterKey=ParameterGroupFamily,ParameterValue=mysql8.0 \
    ParameterKey=UseIamAuth,ParameterValue=true \
    ParameterKey=CreateRDSProxy,ParameterValue=true \
    ParameterKey=NotificationEmail,ParameterValue=alerts@example.com \
  --capabilities CAPABILITY_IAM
```

## Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| Prefix | Resource name prefix | "newrelic" | No |
| DatabaseIdentifier | RDS instance or Aurora cluster ID | - | Yes |
| IsAurora | Whether database is an Aurora cluster | "false" | No |
| DatabaseHost | Database hostname/endpoint | - | Yes |
| DatabaseSecretArn | ARN of Secrets Manager secret | - | Yes |
| VpcId | VPC ID | - | Yes |
| SubnetIds | List of subnet IDs | - | Yes |
| DatabaseSecurityGroupId | Security group ID of database | - | Yes |
| UseIamAuth | Use IAM authentication | "true" | No |
| CreateRDSProxy | Create an RDS Proxy | "true" | No |
| NotificationEmail | Email for notifications | "" | No |
| ParameterGroupFamily | DB parameter group family | "mysql8.0" | No |
| ClusterParameterGroupFamily | Aurora cluster parameter group family | "" | No |

## Post-Deployment Steps

After successful deployment:

1. Associate the created parameter group with your database:
   ```bash
   # For RDS instance
   aws rds modify-db-instance \
     --db-instance-identifier mydb \
     --db-parameter-group-name <stack-name>-perf-schema-optimized \
     --apply-immediately
   
   # For Aurora cluster
   aws rds modify-db-cluster \
     --db-cluster-identifier mycluster \
     --db-cluster-parameter-group-name <stack-name>-perf-schema-cluster \
     --apply-immediately
   ```

2. Create the database user required for the Lambda function:
   ```sql
   -- For IAM authentication
   CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';
   FLUSH PRIVILEGES;
   ```

3. Test the Lambda function by invoking it manually from the AWS Console or CLI

## Outputs

| Output | Description |
|--------|-------------|
| ParameterGroupName | Name of the created DB parameter group |
| ClusterParameterGroupName | Name of the created DB cluster parameter group (Aurora only) |
| LambdaFunctionName | Name of the Lambda function |
| LambdaFunctionArn | ARN of the Lambda function |
| ProxyEndpoint | Endpoint of the RDS Proxy (if created) |
| DashboardURL | URL of the CloudWatch dashboard |
| EventBridgeRules | Names of created EventBridge rules |
| NotificationTopicArn | ARN of the SNS topic (if created) |

## Cleanup

To remove all resources created by this template:

```bash
aws cloudformation delete-stack --stack-name <stack-name>
```

---

© New Relic, Inc. | Internal use and authorized customers only