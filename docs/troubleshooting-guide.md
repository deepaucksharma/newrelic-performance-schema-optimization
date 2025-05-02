# Troubleshooting Guide: Performance Schema Automation

## Common Issues and Solutions

This guide addresses common issues encountered when implementing Performance Schema automation for New Relic monitoring on AWS RDS/Aurora.

## Database Connectivity Issues

### Symptom: Lambda Cannot Connect to Database

**Error messages:**
- `pymysql.err.OperationalError: (2003, "Can't connect to MySQL server on '...' (timed out)")`
- `Network Error: Connection timed out`

**Possible Causes and Solutions:**

1. **VPC Configuration**
   - **Issue:** Lambda function is in the wrong VPC or subnet
   - **Solution:** Verify Lambda is deployed in the same VPC as the database
   - **Verification:** Check Lambda configuration in AWS Console > Lambda > Configuration > VPC

2. **Security Group Rules**
   - **Issue:** Missing or incorrect security group rules
   - **Solution:** 
     - Ensure Lambda security group allows outbound traffic to DB/Proxy on port 3306
     - Ensure DB/Proxy security group allows inbound from Lambda security group on port 3306
   - **Verification:** Check security group rules in AWS Console > EC2 > Security Groups

3. **Database Endpoint Resolution**
   - **Issue:** Lambda can't resolve the database endpoint
   - **Solution:** Ensure private DNS resolution is enabled in the VPC
   - **Verification:** Check VPC settings in AWS Console > VPC > Your VPC > Edit DNS resolution

4. **Lambda Cold Start Timeout**
   - **Issue:** Connection attempt times out during Lambda cold start
   - **Solution:** 
     - Increase Lambda timeout (recommended: 30+ seconds)
     - Use RDS Proxy to reduce connection time
     - Consider Lambda Provisioned Concurrency for critical workloads
   - **Verification:** Check Lambda configuration and CloudWatch Logs for timeout errors

### Symptom: Lambda Connection Fails with Authentication Errors

**Error messages:**
- `Access denied for user 'lambda_perf_schema'@'...' (using password: YES)`
- `Authentication plugin 'AWSAuthenticationPlugin' cannot be loaded`

**Possible Causes and Solutions:**

1. **IAM Authentication Issues**
   - **Issue:** IAM user doesn't have rds-db:connect permission
   - **Solution:** Verify Lambda execution role has proper IAM permissions
   - **Verification:** Check IAM role policy in AWS Console > IAM > Roles

2. **Database User Configuration**
   - **Issue:** Database user doesn't exist or has incorrect authentication method
   - **Solution:** Verify database user is created correctly
   - **Verification:** Connect to database and run:
     ```sql
     SELECT user, host, plugin FROM mysql.user WHERE user = 'lambda_perf_schema';
     ```
     Should show `AWSAuthenticationPlugin` if using IAM auth

3. **Secrets Manager Misconfiguration**
   - **Issue:** Incorrect secret values in Secrets Manager
   - **Solution:** Verify secret contains correct username/password
   - **Verification:** Check secret values in AWS Console > Secrets Manager

4. **RDS Proxy Authentication**
   - **Issue:** RDS Proxy IAM authentication setting doesn't match expectation
   - **Solution:** Verify RDS Proxy IAM authentication is enabled if using IAM auth
   - **Verification:** Check RDS Proxy settings in AWS Console > RDS > Proxies

## Performance Schema Configuration Issues

### Symptom: Lambda Executes But Performance Schema Not Configured

**Error messages:**
- `MySQL Error: Access denied for user '...' for table 'setup_consumers'`
- `Error getting Performance Schema hash`

**Possible Causes and Solutions:**

1. **Insufficient Database Privileges**
   - **Issue:** Database user lacks UPDATE permission on performance_schema tables
   - **Solution:** Grant appropriate permissions to the database user
   - **Verification:** Run the following SQL:
     ```sql
     SHOW GRANTS FOR 'lambda_perf_schema'@'%';
     ```
     Should include `GRANT SELECT, UPDATE ON performance_schema.* TO 'lambda_perf_schema'@'%'`

2. **Performance Schema Disabled**
   - **Issue:** Performance Schema is not enabled at the system level
   - **Solution:** Verify performance_schema parameter is set to 1 in Parameter Group
   - **Verification:** Run the following SQL:
     ```sql
     SHOW VARIABLES LIKE 'performance_schema';
     ```
     Should return `ON`

3. **SQL Syntax Error**
   - **Issue:** SQL statements contain syntax errors
   - **Solution:** Verify SQL statements in Lambda environment variables
   - **Verification:** Test SQL statements manually on the database

4. **Engine Version Differences**
   - **Issue:** Your MySQL/Aurora version has different P_S structure
   - **Solution:** Adapt SQL queries to your specific engine version
   - **Verification:** Check MySQL version with `SELECT VERSION();`

### Symptom: Configuration Doesn't Persist After Restart/Failover

**Error message:**
- `Drift detected after recent restart`

**Possible Causes and Solutions:**

1. **EventBridge Rule Misconfiguration**
   - **Issue:** EventBridge rule not triggering Lambda for restart/failover events
   - **Solution:** Verify EventBridge rule pattern includes correct event IDs
   - **Verification:** Check EventBridge rules in AWS Console > EventBridge > Rules

2. **Lambda Execution Failure**
   - **Issue:** Lambda triggered but fails to execute properly
   - **Solution:** Check CloudWatch Logs for Lambda execution errors
   - **Verification:** Review CloudWatch Logs in AWS Console > CloudWatch > Log Groups

3. **Database Unavailable During Reconfiguration**
   - **Issue:** Lambda tries to connect before database is fully available
   - **Solution:** Implement retry logic with appropriate delays
   - **Verification:** Add more detailed logging in the Lambda function

## Monitoring and Alerting Issues

### Symptom: Missing CloudWatch Metrics

**Issue:**
- Performance Schema metrics not appearing in CloudWatch

**Possible Causes and Solutions:**

1. **Log Format Mismatch**
   - **Issue:** Log lines don't match the expected format for metric filters
   - **Solution:** Ensure Lambda logs JSON objects with expected fields
   - **Verification:** Check CloudWatch Log Group metric filters

2. **Metric Namespace Mismatch**
   - **Issue:** Looking for metrics in the wrong namespace
   - **Solution:** Verify the correct metric namespace
   - **Verification:** Navigate to AWS Console > CloudWatch > Metrics > All metrics > Custom Namespaces

### Symptom: No Notifications Received

**Issue:**
- Not receiving SNS notifications for drift or errors

**Possible Causes and Solutions:**

1. **SNS Subscription Not Confirmed**
   - **Issue:** Email subscription requires confirmation
   - **Solution:** Check email for confirmation link and confirm
   - **Verification:** Check subscription status in AWS Console > SNS > Subscriptions

2. **Lambda Missing SNS Permissions**
   - **Issue:** Lambda doesn't have permission to publish to SNS
   - **Solution:** Add sns:Publish permission to Lambda role
   - **Verification:** Check IAM role policy in AWS Console > IAM > Roles

3. **Empty/Missing SNS_TOPIC_ARN Environment Variable**
   - **Issue:** Lambda doesn't know where to send notifications
   - **Solution:** Set SNS_TOPIC_ARN environment variable
   - **Verification:** Check Lambda environment variables

## Deployment and Infrastructure Issues

### Symptom: CloudFormation/Terraform Deployment Failures

**Error messages:**
- `CREATE_FAILED`
- `Resource creation failed`

**Possible Causes and Solutions:**

1. **Parameter Group Family Mismatch**
   - **Issue:** Specified parameter group family doesn't match database engine version
   - **Solution:** Use correct parameter group family
   - **Verification:** Check available parameter group families with AWS CLI:
     ```bash
     aws rds describe-db-engine-versions --engine mysql --query "DBEngineVersions[].DBParameterGroupFamily"
     ```

2. **Missing IAM Permissions for Deployment**
   - **Issue:** Insufficient permissions to create necessary resources
   - **Solution:** Ensure deployment user/role has sufficient permissions
   - **Verification:** Review IAM permissions and CloudFormation/Terraform error logs

3. **Resource Name Conflicts**
   - **Issue:** Resources with the same name already exist
   - **Solution:** Use unique prefix or delete/rename existing resources
   - **Verification:** Check for existing resources in AWS Console

## Advanced Troubleshooting

### Verifying Lambda Environment

Test Lambda with a simple test event to check basic connectivity:

1. Go to AWS Console > Lambda > Functions > Your Function
2. Create a new test event with empty JSON `{}`
3. Examine the execution results and CloudWatch Logs

### Manually Testing Database Connectivity

Use AWS Systems Manager Session Manager to test database connectivity:

1. Launch an EC2 instance in the same VPC as your database
2. Install the MySQL client:
   ```bash
   sudo yum install -y mysql
   ```
3. Test connection with IAM authentication:
   ```bash
   RDSHOST="your-db-endpoint"
   TOKEN="$(aws rds generate-db-auth-token --hostname $RDSHOST --port 3306 --username lambda_perf_schema)"
   mysql -h $RDSHOST --port 3306 --user lambda_perf_schema --password=$TOKEN --ssl-ca=/etc/pki/tls/certs/rds-ca-2019-root.pem
   ```

### Validating Performance Schema State

Run these SQL queries to check the current Performance Schema state:

```sql
-- Check if Performance Schema is enabled
SHOW VARIABLES LIKE 'performance_schema';

-- Check consumer configuration
SELECT NAME, ENABLED FROM performance_schema.setup_consumers;

-- Check statement instruments configuration
SELECT COUNT(*) AS enabled_statements
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES';

-- Check wait instruments configuration
SELECT COUNT(*) AS enabled_waits
FROM performance_schema.setup_instruments
WHERE NAME LIKE 'wait/%' AND ENABLED = 'YES';
```

## Getting Additional Help

If you continue to experience issues:

1. **Gather Diagnostics**:
   - CloudWatch Logs for Lambda function
   - Database configuration details
   - Deployment logs
   - Error messages
   - Current Performance Schema state

2. **Contact Support**:
   - Email: db-support@newrelic.com
   - Include all diagnostic information
   - Provide AWS account ID and region
   - Describe your database environment (RDS/Aurora, version, etc.)

---

© New Relic, Inc. | Internal use and authorized customers only