# Getting Started with Performance Schema Optimization

This guide will help you quickly implement Performance Schema optimization for MySQL/Aurora monitoring with New Relic.

## Prerequisites

- AWS account with permissions to create resources
- MySQL 5.7+ or Aurora MySQL compatible database
- New Relic account with MySQL monitoring enabled
- Basic familiarity with AWS services (RDS, Lambda, CloudFormation or Terraform)

## Quick Start Options

Choose one of the following implementation methods:

### Option 1: CloudFormation Deployment (Recommended for AWS-Centric Teams)

1. Navigate to the `cloudformation` directory
2. Review the `README.md` file for detailed instructions
3. Deploy the CloudFormation template:
   ```bash
   aws cloudformation create-stack \
     --stack-name newrelic-perf-schema \
     --template-body file://performance-schema-automation.yaml \
     --parameters \
       ParameterKey=DatabaseIdentifier,ParameterValue=mydb \
       # Add other parameters as needed
     --capabilities CAPABILITY_IAM
   ```
4. Follow post-deployment steps in the CloudFormation README

### Option 2: Terraform Deployment (Recommended for Multi-Cloud Teams)

1. Navigate to the `terraform` directory
2. Review the `README.md` file for detailed instructions
3. Initialize and apply the Terraform module:
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
4. Follow post-deployment steps in the Terraform README

### Option 3: Manual Configuration (For One-Time Setup)

1. Navigate to the `sql` directory
2. Review the `README.md` file for detailed instructions
3. Connect to your database and execute the SQL scripts

## Verification

After implementation, verify the configuration:

1. Connect to your MySQL/Aurora database and run:
   ```sql
   SELECT NAME, ENABLED FROM performance_schema.setup_consumers
   WHERE NAME LIKE 'events_statements%';
   
   SELECT COUNT(*) FROM performance_schema.setup_instruments
   WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';
   ```

2. Check New Relic monitoring data:
   - Navigate to New Relic One > Databases
   - Select your MySQL/Aurora instance
   - Verify SQL query samples and digest statistics are appearing

## Next Steps

- Review and customize the SQL statements in the Lambda function for your specific workload
- Set up CloudWatch alarms for Performance Schema drift detection
- Consider automating deployment across multiple environments
- Explore additional Performance Schema instruments for specific monitoring needs

## Support and Troubleshooting

If you encounter issues:

1. Check the `docs/troubleshooting-guide.md` file for common issues and solutions
2. Review CloudWatch Logs for the Lambda function
3. Verify database connectivity and permissions
4. Contact New Relic support for assistance: db-support@newrelic.com

---

© New Relic, Inc. | Internal use and authorized customers only