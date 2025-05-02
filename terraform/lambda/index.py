import json
import boto3
import pymysql
import os
import logging
import hashlib
import time
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_IDENTIFIER = os.environ.get('DB_IDENTIFIER')
DB_SECRET_ARN = os.environ.get('DB_SECRET_ARN')
DB_USER = os.environ.get('DB_USER', 'lambda_perf_schema')
DB_USE_IAM_AUTH = os.environ.get('DB_USE_IAM_AUTH', 'true').lower() == 'true'
DB_IS_AURORA = os.environ.get('DB_IS_AURORA', 'false').lower() == 'true'
DB_PROXY_ENDPOINT = os.environ.get('DB_PROXY_ENDPOINT', '')
DB_HOST = os.environ.get('DB_HOST', '')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
PERFORMANCE_SCHEMA_HASH = os.environ.get('PERFORMANCE_SCHEMA_HASH', '')
SQL_UPDATE_STATEMENTS = os.environ.get('SQL_UPDATE_STATEMENTS', '')

# AWS region and current identity
session = boto3.session.Session()
REGION = session.region_name

def get_secret():
    """Retrieve database credentials from AWS Secrets Manager"""
    client = boto3.client('secretsmanager')
    try:
        response = client.get_secret_value(SecretId=DB_SECRET_ARN)
        secret_string = response['SecretString']
        return json.loads(secret_string)
    except ClientError as e:
        logger.error(f"Error retrieving secret: {e}")
        raise

def get_rds_endpoint():
    """Get the RDS endpoint for the specified DB instance or cluster"""
    if DB_PROXY_ENDPOINT:
        logger.info(f"Using RDS Proxy endpoint: {DB_PROXY_ENDPOINT}")
        return DB_PROXY_ENDPOINT
    
    if DB_HOST:
        logger.info(f"Using provided DB host: {DB_HOST}")
        return DB_HOST
    
    # If no proxy or host provided, get from RDS API
    try:
        if DB_IS_AURORA:
            rds = boto3.client('rds')
            response = rds.describe_db_clusters(DBClusterIdentifier=DB_IDENTIFIER)
            return response['DBClusters'][0]['Endpoint']
        else:
            rds = boto3.client('rds')
            response = rds.describe_db_instances(DBInstanceIdentifier=DB_IDENTIFIER)
            return response['DBInstances'][0]['Endpoint']['Address']
    except ClientError as e:
        logger.error(f"Error retrieving database endpoint: {e}")
        raise

def get_iam_auth_token(host, port, user):
    """Generate an IAM authentication token for DB access"""
    client = boto3.client('rds')
    try:
        token = client.generate_db_auth_token(
            DBHostname=host,
            Port=port,
            DBUsername=user,
            Region=REGION
        )
        return token
    except ClientError as e:
        logger.error(f"Error generating IAM auth token: {e}")
        raise

def connect_to_database(retry_attempts=3, retry_delay=2):
    """Connect to the database with retry logic"""
    # Get endpoint and credentials
    endpoint = get_rds_endpoint()
    port = 3306
    
    if DB_USE_IAM_AUTH:
        logger.info("Using IAM authentication")
        username = DB_USER
        password = get_iam_auth_token(endpoint, port, username)
    else:
        logger.info("Using Secrets Manager for authentication")
        secret = get_secret()
        username = secret.get('username', DB_USER)
        password = secret.get('password')
    
    # Attempt connection with retries
    conn = None
    last_error = None
    
    for attempt in range(retry_attempts):
        try:
            logger.info(f"Connection attempt {attempt + 1} to {endpoint}")
            conn = pymysql.connect(
                host=endpoint,
                user=username,
                password=password,
                port=port,
                connect_timeout=10,
                ssl={'ssl': True}
            )
            logger.info("Database connection successful")
            return conn
        except pymysql.MySQLError as e:
            last_error = e
            logger.warning(f"Connection attempt {attempt + 1} failed: {e}")
            if attempt < retry_attempts - 1:
                time.sleep(retry_delay)
    
    # If we get here, all attempts failed
    logger.error(f"All connection attempts failed: {last_error}")
    raise last_error

def get_current_perf_schema_hash(conn):
    """Get the current Performance Schema configuration hash"""
    try:
        with conn.cursor() as cursor:
            # First check if Performance Schema is enabled
            cursor.execute("SHOW VARIABLES LIKE 'performance_schema'")
            result = cursor.fetchone()
            if not result or result[1].lower() != 'on':
                logger.error("Performance Schema is not enabled")
                return None

            # Get current consumer configuration
            cursor.execute("""
                SELECT CONCAT(NAME, ':', ENABLED) 
                FROM performance_schema.setup_consumers 
                ORDER BY NAME
            """)
            consumer_rows = cursor.fetchall()
            consumer_state = ';'.join([row[0] for row in consumer_rows])
            
            # Get current instrument configuration sample
            cursor.execute("""
                SELECT COUNT(*) AS statement_count
                FROM performance_schema.setup_instruments
                WHERE NAME LIKE 'statement/%' AND ENABLED = 'YES'
            """)
            statement_count = cursor.fetchone()[0]
            
            cursor.execute("""
                SELECT COUNT(*) AS wait_count
                FROM performance_schema.setup_instruments
                WHERE NAME LIKE 'wait/%' AND ENABLED = 'YES'
            """)
            wait_count = cursor.fetchone()[0]

            # Create a hash from the current state
            state_string = f"{consumer_state};statements:{statement_count};waits:{wait_count}"
            current_hash = hashlib.sha256(state_string.encode()).hexdigest()
            
            logger.info(f"Current P_S state: {state_string}")
            logger.info(f"Current P_S hash: {current_hash}")
            
            return current_hash
            
    except Exception as e:
        logger.error(f"Error getting Performance Schema hash: {e}")
        raise

def apply_perf_schema_configuration(conn):
    """Apply the Performance Schema configuration SQL statements"""
    try:
        with conn.cursor() as cursor:
            # Split and execute each SQL statement
            statements = SQL_UPDATE_STATEMENTS.split(';')
            
            # Start transaction
            conn.begin()
            
            for stmt in statements:
                if stmt.strip():
                    logger.info(f"Executing: {stmt.strip()}")
                    cursor.execute(stmt)
            
            # Commit all changes
            conn.commit()
            logger.info("Performance Schema configuration applied successfully")
            return True
            
    except Exception as e:
        # Rollback on error
        if conn:
            conn.rollback()
        logger.error(f"Error applying Performance Schema configuration: {e}")
        raise

def send_notification(subject, message):
    """Send an SNS notification"""
    if not SNS_TOPIC_ARN:
        logger.info("No SNS topic provided, skipping notification")
        return
        
    try:
        sns = boto3.client('sns')
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject=subject
        )
        logger.info(f"Notification sent to {SNS_TOPIC_ARN}")
    except ClientError as e:
        logger.error(f"Error sending notification: {e}")

def lambda_handler(event, context):
    """Main Lambda handler"""
    logger.info(f"Performance Schema configuration check started for {DB_IDENTIFIER}")
    logger.info(f"Event: {json.dumps(event)}")
    
    event_source = event.get('source', '') if isinstance(event, dict) else ''
    detail_type = event.get('detail-type', '') if isinstance(event, dict) else ''
    
    # Extract trigger type for logging
    if event_source == 'aws.events' and 'scheduled' in detail_type.lower():
        trigger_type = 'scheduled'
    elif event_source == 'aws.rds':
        trigger_type = f"rds_event_{event.get('detail', {}).get('EventID', 'unknown')}"
    else:
        trigger_type = 'manual'
    
    result = {
        'database': DB_IDENTIFIER,
        'trigger_type': trigger_type,
        'drift_detected': False,
        'patch_applied': False,
        'error': ''
    }
    
    conn = None
    try:
        # Connect to the database
        conn = connect_to_database()
        
        # Get the current Performance Schema hash
        current_hash = get_current_perf_schema_hash(conn)
        
        if not current_hash:
            error_msg = "Could not retrieve Performance Schema state - may not be enabled"
            result['error'] = error_msg
            send_notification(
                f"Performance Schema Check Failed: {DB_IDENTIFIER}", 
                error_msg
            )
            return result
        
        # Compare with the expected hash
        if not PERFORMANCE_SCHEMA_HASH:
            logger.warning("No expected Performance Schema hash provided, will apply configuration regardless")
            drift_detected = True
        else:
            drift_detected = current_hash != PERFORMANCE_SCHEMA_HASH
        
        result['drift_detected'] = drift_detected
        
        if drift_detected:
            logger.info("Performance Schema drift detected, applying configuration")
            
            # Apply the Performance Schema configuration
            apply_perf_schema_configuration(conn)
            result['patch_applied'] = True
            
            # Get the new hash to verify
            new_hash = get_current_perf_schema_hash(conn)
            
            # Check if the configuration was successful
            if PERFORMANCE_SCHEMA_HASH and new_hash != PERFORMANCE_SCHEMA_HASH:
                logger.warning(f"Applied configuration but hash still doesn't match: {new_hash} vs {PERFORMANCE_SCHEMA_HASH}")
                send_notification(
                    f"Performance Schema Update Warning: {DB_IDENTIFIER}",
                    f"Performance Schema was updated but the configuration hash doesn't match the expected value.\nCurrent: {new_hash}\nExpected: {PERFORMANCE_SCHEMA_HASH}"
                )
            else:
                logger.info("Performance Schema configuration successfully applied and verified")
                send_notification(
                    f"Performance Schema Updated: {DB_IDENTIFIER}",
                    f"Performance Schema configuration was successfully applied to {DB_IDENTIFIER}"
                )
        else:
            logger.info("Performance Schema configuration is already correct")
    
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Error: {error_msg}")
        result['error'] = error_msg
        send_notification(
            f"Performance Schema Configuration Error: {DB_IDENTIFIER}",
            f"Error configuring Performance Schema on {DB_IDENTIFIER}: {error_msg}"
        )
    
    finally:
        # Close the database connection
        if conn:
            conn.close()
            logger.info("Database connection closed")
    
    # Log the result as JSON for metric extraction
    logger.info(json.dumps(result))
    return result