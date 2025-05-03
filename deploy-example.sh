#!/usr/bin/env bash
# Example deployment script for New Relic Performance Schema Optimization
# This script demonstrates the full deployment process

set -e  # Exit on error

# Configuration (modify these values)
S3_BUCKET="your-artifact-bucket"
DB_ID="your-database-id"
IS_AURORA="false"
VPC_ID="vpc-xxxxxxxx"
SUBNET_IDS='["subnet-xxxxxxxx","subnet-yyyyyyyy"]'
VPC_CIDR="" # Will be auto-detected if empty
NEW_RELIC_ACCOUNT="123456"
REGION="us-east-1"
ENGINE_FAMILY="mysql8.0"  # Options: mysql8.0, mysql5.7, aurora-mysql8.0, aurora-mysql5.7
STACK_NAME="nr-perf-schema-optimizer"

# Display banner and configuration
echo "=============================================================="
echo "    New Relic MySQL Performance Schema Optimization Deploy    "
echo "=============================================================="
echo ""
echo "Configuration:"
echo "  S3 Bucket:      $S3_BUCKET"
echo "  Database ID:    $DB_ID"
echo "  Is Aurora:      $IS_AURORA"
echo "  VPC ID:         $VPC_ID"
echo "  VPC CIDR:       $VPC_CIDR"
echo "  Region:         $REGION"
echo "  Engine Family:  $ENGINE_FAMILY"
echo "  Stack Name:     $STACK_NAME"
echo ""
echo "This script will:"
echo "  1. Build the Lambda function and layer"
echo "  2. Upload artifacts to S3"
echo "  3. Deploy CloudFormation stack"
echo "  4. Display next steps"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Set AWS region
export AWS_DEFAULT_REGION="$REGION"

# Auto-detect VPC CIDR if not set
if [ -z "$VPC_CIDR" ]; then
  echo "Auto-detecting VPC CIDR for VPC ID: $VPC_ID"
  VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
               --query 'Vpcs[0].CidrBlock' --output text)
  echo "Detected VPC CIDR: $VPC_CIDR"
fi

# 1. Build Lambda and dependencies
echo -e "\n[1/4] Building Lambda function and layer..."
cd lambda
bash build.sh
cd ..

echo -e "\n[2/4] Uploading artifacts to S3..."
# Upload Lambda artifacts
aws s3 cp lambda/lambda.zip "s3://$S3_BUCKET/lambda.zip"
aws s3 cp lambda/pymysql-pyyaml-layer.zip "s3://$S3_BUCKET/pymysql-pyyaml-layer.zip"

# Upload config
aws s3 cp sql/target-config.yaml "s3://$S3_BUCKET/target-config.yaml"

echo -e "\n[3/4] Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file cloudformation/perf-schema-automation.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      Prefix=nr-mysql-ps \
      EngineFamily="$ENGINE_FAMILY" \
      DatabaseId="$DB_ID" \
      IsAurora="$IS_AURORA" \
      SqlBucket="$S3_BUCKET" \
      SqlKey=target-config.yaml \
      VpcId="$VPC_ID" \
      SubnetIds="$SUBNET_IDS" \
      VpcCidr="$VPC_CIDR" \
      UseIamAuth=true \
      NewRelicAccountId="$NEW_RELIC_ACCOUNT"

echo -e "\n[4/4] Getting deployment details..."
# Get outputs from CloudFormation
PG_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='ParameterGroupName'].OutputValue" \
  --output text)

LAMBDA_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaName'].OutputValue" \
  --output text)

echo -e "\n=============================================================="
echo "                  Deployment Complete!                         "
echo "=============================================================="
echo ""
echo "Parameter Group: $PG_NAME"
echo "Lambda Function: $LAMBDA_NAME"
echo ""
echo "Next Steps:"
echo ""
echo "1. Create the database user:"
echo "   CREATE USER 'lambda_perf_schema'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';"
echo "   GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%';"
echo "   GRANT SELECT ON information_schema.* TO 'lambda_perf_schema'@'%';"
echo "   FLUSH PRIVILEGES;"
echo ""
echo "2. Attach the parameter group to your RDS/Aurora instance in the AWS console"
echo ""
echo "3. Reboot your database instance"
echo ""
echo "4. Verify the configuration with:"
echo "   mysql> SOURCE sql/verification.sql"
echo ""
echo "5. Check Lambda logs:"
echo "   aws logs tail /aws/lambda/$LAMBDA_NAME --since 30m"
echo ""
echo "For detailed documentation, see the docs directory."
echo "=============================================================="
