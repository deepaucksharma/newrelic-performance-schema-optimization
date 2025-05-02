# Lambda Function for Performance Schema Management

This directory contains the AWS Lambda function that monitors and enforces Performance Schema configuration on RDS/Aurora MySQL instances.

## Components

- `index.py` - Core function code
- `requirements.txt` - Python dependencies
- `build.sh` - Build script to create deployment packages

## How It Works

The Lambda function:

1. Retrieves the desired configuration from the S3 bucket (defined in `target-config.yaml`)
2. Connects to the database using IAM Authentication or Secret Manager
3. Queries the current Performance Schema state
4. Computes the difference between current and desired state
5. Applies the minimal set of UPDATE statements to match the desired state
6. Logs the results with structured metadata for monitoring

## Building and Deployment

To build the Lambda package:

```bash
# Run the build script
./build.sh

# This creates:
# - lambda.zip - Main function code
# - pymysql-pyyaml-layer.zip - Dependencies layer
```

## Environment Variables

The Lambda function expects the following environment variables:

| Variable | Description |
|----------|-------------|
| `SQL_BUCKET` | S3 bucket containing the YAML configuration |
| `SQL_KEY` | S3 key (path) to the YAML configuration file |
| `DB_ID` | RDS instance ID or Aurora cluster ID |
| `IS_AURORA` | "true" for Aurora clusters, "false" for RDS instances |
| `IAM_AUTH` | "true" to use IAM auth, "false" for Secrets Manager |
| `DB_USER` | Database username (default: lambda_perf_schema) |
| `NR_ACCOUNT` | (Optional) New Relic account ID for logging |
| `SECRET_ARN` | (Optional) Secrets Manager ARN for DB credentials |

## Customization

To customize the function behavior:

1. Modify the `_diff()` function for different change logic
2. Add additional validation or error handling as needed
3. Extend structured logging for integration with other monitoring systems

## Testing

During development, you can test the function locally:

```python
# Set environment variables
import os
os.environ['SQL_BUCKET'] = 'my-bucket'
os.environ['SQL_KEY'] = 'target-config.yaml'
os.environ['DB_ID'] = 'my-db'
os.environ['IS_AURORA'] = 'false'
os.environ['IAM_AUTH'] = 'true'

# Execute the handler with a test event
import index
event = {'source': 'aws.events', 'detail-type': 'Scheduled Event'}
index.lambda_handler(event, None)
```

## Monitoring and Troubleshooting

The function emits structured JSON logs with the following fields:

- `database`: The target database identifier
- `drift_detected`: Whether configuration drift was found
- `patch_applied`: Whether changes were successfully applied
- `update_count`: Number of SQL statements executed
- `verification_success`: Whether post-update verification passed
- `error`: Error details if any occurred
- `nr_account`: New Relic account ID if provided
- `source`: Fixed identifier for log filtering

Check CloudWatch Logs for function execution details.
