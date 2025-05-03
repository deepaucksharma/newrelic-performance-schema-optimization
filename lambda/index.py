"""
Lambda: enforce Performance-Schema desired state on RDS/Aurora for New Relic monitoring.
Runtime: python3.12
"""
import json, os, time, logging, yaml, hashlib
import boto3, pymysql
from botocore.exceptions import ClientError
from botocore.config import Config

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

S3_BUCKET = os.environ["SQL_BUCKET"]
S3_KEY    = os.environ["SQL_KEY"]
DB_ID     = os.environ["DB_ID"]
IS_AURORA = os.environ["IS_AURORA"] == "true"
IAM_AUTH  = os.environ["IAM_AUTH"]  == "true"
DB_USER   = os.environ.get("DB_USER", "lambda_perf_schema")
DB_PORT   = int(os.environ.get("DB_PORT", "3306"))
NR_ACCOUNT = os.environ.get("NR_ACCOUNT", "")  # Optional New Relic account ID for logs

session = boto3.session.Session()
REGION  = session.region_name

# Configure S3 client with retries
s3_config = Config(
    retries = {
        'max_attempts': 3,
        'mode': 'standard'
    }
)

def _get_target_yaml():
    """Get and validate the target configuration YAML from S3."""
    s3 = boto3.client("s3", config=s3_config)
    obj = s3.get_object(Bucket=S3_BUCKET, Key=S3_KEY)
    
    # --- YAML validation --------------------------------------------------
    target_raw = yaml.safe_load(obj["Body"].read())
    expected_keys = {
        "consumers_enabled": list,
        "instruments_enabled_prefixes": list,
        "instruments_enabled_exact": list,
        "instruments_disabled_prefixes": list,
    }
    for k, t in expected_keys.items():
        if k not in target_raw or not isinstance(target_raw[k], t):
            raise ValueError(f"YAML missing or invalid key '{k}'")
    return target_raw

def _rds_endpoint():
    """Get the RDS endpoint based on instance or cluster ID."""
    rds = boto3.client("rds")
    if IS_AURORA:
        return rds.describe_db_clusters(DBClusterIdentifier=DB_ID)["DBClusters"][0]["Endpoint"]
    return rds.describe_db_instances(DBInstanceIdentifier=DB_ID)["DBInstances"][0]["Endpoint"]["Address"]

def _iam_token(host, user):
    """Generate IAM auth token for RDS."""
    return boto3.client("rds").generate_db_auth_token(
        DBHostname=host, Port=DB_PORT, DBUsername=user, Region=REGION)

def _connect():
    """Return a pymysql connection using the AWS CA bundle for SSL."""
    host = _rds_endpoint()
    pwd  = _iam_token(host, DB_USER) if IAM_AUTH else None

    # Use AWS SSL bundle; fail if bundle is missing to prevent downgrade
    ssl_cfg = {}
    ca_path = "/opt/python/rds-combined-ca-bundle.pem"
    if os.path.exists(ca_path):
        ssl_cfg["ca"] = ca_path
    else:
        raise RuntimeError("AWS CA bundle missing at {}. Cannot establish secure connection.".format(ca_path))

    return pymysql.connect(host=host,
                           user=DB_USER,
                           password=pwd,
                           port=DB_PORT,
                           connect_timeout=10,
                           read_timeout=10,
                           ssl=ssl_cfg)

def _current_state(cur):
    """Get current Performance Schema state."""
    cur.execute("SELECT NAME, ENABLED FROM performance_schema.setup_consumers")
    consumers = {n: e for n, e in cur.fetchall()}
    cur.execute("SELECT NAME, ENABLED, TIMED FROM performance_schema.setup_instruments")
    instr = {n: (e, t) for n, e, t in cur.fetchall()}
    return consumers, instr

def _diff(target, current):
    """Calculate the SQL commands needed to bring current state to match target state."""
    sql = []
    # consumers
    for name in target["consumers_enabled"]:
        if current[0].get(name) != "YES":
            sql.append(f"UPDATE performance_schema.setup_consumers "
                       f"SET ENABLED='YES' WHERE NAME='{name}'")
    # instruments enabled by prefix
    for prefix in target["instruments_enabled_prefixes"]:
        sql.append(f"UPDATE performance_schema.setup_instruments "
                   f"SET ENABLED='YES', TIMED='YES' "
                   f"WHERE NAME LIKE '{prefix}'")
    # exact enables
    for name in target["instruments_enabled_exact"]:
        if current[1].get(name, ("NO","NO")) != ("YES","YES"):
            sql.append(f"UPDATE performance_schema.setup_instruments "
                       f"SET ENABLED='YES', TIMED='YES' WHERE NAME='{name}'")
    # disables
    for prefix in target["instruments_disabled_prefixes"]:
        sql.append(f"UPDATE performance_schema.setup_instruments "
                   f"SET ENABLED='NO', TIMED='NO' WHERE NAME LIKE '{prefix}'")
    return sql

def lambda_handler(event, _):
    """Main Lambda handler function."""
    LOG.info("Event %s", json.dumps(event))
    result = {
        "database": DB_ID, 
        "drift_detected": False,
        "patch_applied": False, 
        "error": "",
        "nr_account": NR_ACCOUNT,
        "source": "new_relic_perf_schema_optimizer",
        "ts": int(time.time())
    }
    
    con = None  # Initialize connection variable outside try block for exception handling
    
    try:
        target = _get_target_yaml()
        con = _connect()
        with con.cursor() as cur:
            current = _current_state(cur)
            updates = _diff(target, current)
            result["drift_detected"] = bool(updates)
            result["update_count"] = len(updates)
            if updates:
                LOG.info(f"Applying {len(updates)} updates to Performance Schema")
                con.begin()
                for stmt in updates:
                    cur.execute(stmt)
                con.commit()
                result["patch_applied"] = True
                
                # Verify changes were applied
                post_current = _current_state(cur)
                post_updates = _diff(target, post_current)
                result["verification_success"] = len(post_updates) == 0
                
        LOG.info(json.dumps(result))
    except Exception as exc:
        # Roll back any open transaction just in case
        try:
            if con:
                con.rollback()
        except Exception:
            pass
        result["error"] = str(exc)
        LOG.error("Failure: %s", exc, exc_info=True)
    return result

# NOTE: The duplicate copy in terraform/lambda/ was removed.
