# CloudFormation Template for Performance Schema Automation

This directory contains the AWS CloudFormation template for deploying the complete Performance Schema automation solution.

## Template Overview

The `perf-schema-automation.yaml` template creates all resources needed to automatically maintain MySQL Performance Schema configuration on RDS/Aurora:

- RDS Parameter Group with Performance Schema baseline settings
- Lambda function to apply and maintain runtime configurations
- IAM roles and policies with least-privilege permissions
- Security group for Lambda VPC access
- EventBridge rules for scheduled and event-based triggers
- CloudWatch logging and optional alerting

## Prerequisites

Before deploying the template:

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

## Deployment

### Using AWS CLI

```bash
# Helper – grab the VPC CIDR so you can feed VpcCidr without hard-coding
VpcCidr=$(aws ec2 describe-vpcs --vpc-ids <vpc-id> --query 'Vpcs[0].CidrBlock' --output text)

aws cloudformation deploy \
  --template-file perf-schema-automation.yaml \
  --stack-name nr-perf-schema-optimizer \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      Prefix=nr-mysql-ps \
      EngineFamily=mysql8.0 \
      DatabaseId=YOUR-DB-ID \
      IsAurora=false \
      SqlBucket=YOUR-BUCKET \
      SqlKey=target-config.yaml \
      VpcId=vpc-xxxxx \
      SubnetIds='["subnet-xxxxx","subnet-yyyyy"]' \
      # Optional when you want locked-down egress
      VpcCidr=$VpcCidr \
      UseIamAuth=true \
      NewRelicAccountId=YOUR-NR-ACCOUNT
```

### Using AWS Console

1. Navigate to CloudFormation in the AWS Console
2. Click "Create stack" > "With new resources"
3. Upload the template file
4. Fill in the parameters as described below
5. Follow the prompts to complete stack creation

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `Prefix` | Prefix for all resource names | nr-mysql-ps |
| `EngineFamily` | MySQL/Aurora engine family | mysql8.0 |
| `DatabaseId` | RDS Instance ID or Aurora Cluster ID | (required) |
| `IsAurora` | Whether target is Aurora cluster | false |
| `SqlBucket` | S3 bucket with configuration and code | (required) |
| `SqlKey` | S3 key for configuration YAML | target-config.yaml |
| `VpcId` | VPC ID where Lambda will run | (required) |
| `SubnetIds` | Subnet IDs where Lambda will run | (required) |
| `DBSecretArn` | Secrets Manager ARN for credentials | (optional) |
| `UseIamAuth` | Use IAM authentication for DB | true |
| `NewRelicAccountId` | New Relic account ID for logging | (optional) |

## Outputs

The CloudFormation stack provides the following outputs:

- `ParameterGroupName`: Name of the created parameter group
- `LambdaName`: Name of the Lambda function
- `LambdaLogGroupName`: Name of the CloudWatch log group
- `DailyCheckRuleName`: Name of the daily schedule rule
- `RDSEventsRuleName`: Name of the RDS events rule
- `DB_USER`: Database user needed for Lambda access

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
3. **Add an inbound rule on the RDS/Aurora security group to allow TCP 3306 from the Lambda security group ID output by the stack (e.g. `nr-mysql-ps-lambda-sg`).**
   ```bash
   # Using AWS CLI to add the inbound rule
   aws ec2 authorize-security-group-ingress \
     --group-id <your-db-security-group-id> \
     --protocol tcp --port 3306 \
     --source-group $(aws cloudformation describe-stacks --stack-name nr-perf-schema-optimizer \
       --query "Stacks[0].Outputs[?OutputKey=='LambdaSecurityGroupId'].OutputValue" --output text)
   # If you exposed LambdaSecurityGroupId (see template output section)
   ```
4. Reboot your database instance
4. Check CloudWatch logs to verify successful execution

## Updating the Stack

When updating the template or parameters:

```bash
aws cloudformation update-stack \
  --stack-name nr-perf-schema-optimizer \
  --template-body file://perf-schema-automation.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=Prefix,ParameterValue=nr-mysql-ps \
               ParameterKey=DatabaseId,ParameterValue=YOUR-DB-ID \
               # Add other parameters as needed
```

## Cleanup

To remove all created resources:

```bash
aws cloudformation delete-stack --stack-name nr-perf-schema-optimizer
```

Note: This will not remove the parameter group from any RDS instances it's attached to. You'll need to modify those instances to use a different parameter group first.
