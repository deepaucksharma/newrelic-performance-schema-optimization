# Performance Schema Lambda Function

This directory contains the Lambda function code for the Performance Schema automation solution. The actual Lambda function implementation is included in the CloudFormation template and Terraform module for direct deployment, but this directory provides the standalone version for reference and testing.

## Usage

The Lambda function in this directory can be used for:
1. Manual testing and debugging
2. Custom deployment scenarios
3. Reference implementation

## Implementation

See the `index.py` file for the complete Python implementation. The function performs the following:

1. Connects to the MySQL/Aurora database using IAM or password authentication
2. Verifies the current Performance Schema configuration
3. Detects configuration drift from the expected state
4. Applies the optimized configuration when drift is detected
5. Validates the changes were applied correctly
6. Sends notifications to SNS (if configured)

## Dependencies

The function requires:
- Python 3.9+
- PyMySQL
- AWS SDK for Python (boto3)

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| DB_IDENTIFIER | RDS instance or Aurora cluster ID | "mydb" |
| DB_SECRET_ARN | ARN of Secrets Manager secret | "arn:aws:secretsmanager:..." |
| DB_USER | Database username | "lambda_perf_schema" |
| DB_USE_IAM_AUTH | Use IAM authentication | "true" or "false" |
| DB_IS_AURORA | Is Aurora database | "true" or "false" |
| DB_PROXY_ENDPOINT | RDS Proxy endpoint | "myproxy.proxy-abcdefg.region.rds.amazonaws.com" |
| DB_HOST | Database host | "mydb.abcdefg.region.rds.amazonaws.com" |
| SNS_TOPIC_ARN | ARN of SNS topic for notifications | "arn:aws:sns:..." |
| PERFORMANCE_SCHEMA_HASH | Expected hash of configuration | "46b5fa75e2ee..." |
| SQL_UPDATE_STATEMENTS | SQL statements to apply | "UPDATE performance_schema..." |

## Testing

To test this function locally before deployment:

1. Set up a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install pymysql boto3
   ```

2. Create a test event file (test_event.json):
   ```json
   {
     "source": "manual.test",
     "detail-type": "Manual Invocation"
   }
   ```

3. Test with AWS SAM Local or directly with the AWS CLI Lambda invoke command.

---

© New Relic, Inc. | Internal use and authorized customers only