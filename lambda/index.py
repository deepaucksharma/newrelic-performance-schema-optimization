"""
Lambda: enforce Performance-Schema desired state on RDS/Aurora for New Relic monitoring.
Runtime: python3.12
"""
import json, os, time, logging, yaml, hashlib, re
import boto3, pymysql
from botocore.utils import get_default_ca_bundle
from botocore.exceptions import ClientError
from botocore.config import Config

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

# Global connection cache for reuse across Lambda invocations
CONN = None

S3_BUCKET = os.environ["SQL_BUCKET"]
S3_KEY    = os.environ["SQL_KEY"]
DB_ID     = os.environ["DB_ID"]
IS_AURORA = os.environ["IS_AURORA"] == "true"
IAM_AUTH  = os.environ["IAM_AUTH"]  == "true"
DB_USER   = os.environ.get("DB_USER", "lambda_perf_schema")
DB_PORT   = int(os.environ.get("DB_PORT", "3306"))
NR_ACCOUNT = os.environ.get("NR_ACCOUNT", "")  # Optional New Relic account ID for logs

# Regular expression for validating Performance Schema object names
# Only alphanumerics, underscores, forward slashes, and percent signs are allowed
SAFE_PATTERN = re.compile(r'^[A-Za-z0-9_/%]+$')

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
    
    # --- Security validation - prevent SQL injection ----------------------
    # Validate all string values against our safe pattern
    for name in target_raw["consumers_enabled"]:
        if not SAFE_PATTERN.fullmatch(name):
            raise ValueError(f"Invalid consumer name: {name}")
    
    for prefix in target_raw["instruments_enabled_prefixes"]:
        if not SAFE_PATTERN.fullmatch(prefix):
            raise ValueError(f"Invalid instrument prefix: {prefix}")
    
    for name in target_raw["instruments_enabled_exact"]:
        if not SAFE_PATTERN.fullmatch(name):
            raise ValueError(f"Invalid instrument name: {name}")
    
    for prefix in target_raw["instruments_disabled_prefixes"]:
        if not SAFE_PATTERN.fullmatch(prefix):
            raise ValueError(f"Invalid instrument prefix: {prefix}")
    
    # Validate that prefix wildcards end with %
    for lst_name in ("instruments_enabled_prefixes", "instruments_disabled_prefixes"):
        for p in target_raw[lst_name]:
            if not p.endswith('%'):
                raise ValueError(f"{lst_name} entry '{p}' must end with '%' for LIKE matching")
            
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

    ssl_cfg = {"ca": get_default_ca_bundle()}

    return pymysql.connect(host=host,
                           user=DB_USER,
                           password=pwd,
                           port=DB_PORT,
                           connect_timeout=10,
                           read_timeout=10,
                           ssl=ssl_cfg)

def _connect_cached():
    """Return a cached DB connection if valid, or create a new one."""
    global CONN
    try:
        # Check if we have a valid connection
        if CONN and CONN.open:
            # Ping with reconnect if needed
            CONN.ping(reconnect=True)
            return CONN
    except Exception as e:
        LOG.info(f"Connection reuse failed, creating new connection: {str(e)}")
        # Fall through to creating a new connection
    
    # Create a new connection
    CONN = _connect()
    return CONN

def _current_state(cur):
    """Get current Performance Schema state."""
    cur.execute("SELECT NAME, ENABLED FROM performance_schema.setup_consumers")
    consumers = {n: e for n, e in cur.fetchall()}
    cur.execute("SELECT NAME, ENABLED, TIMED FROM performance_schema.setup_instruments")
    instr = {n: (e, t) for n, e, t in cur.fetchall()}
    return consumers, instr

def _diff(target, current):
    """Calculate the SQL commands needed to bring current state to match target state."""
    sql_params = []
    # consumers
    for name in target["consumers_enabled"]:
        if current[0].get(name) != "YES":
            sql_params.append({
                "sql": "UPDATE performance_schema.setup_consumers SET ENABLED='YES' WHERE NAME=%s",
                "params": (name,)
            })
    # instruments enabled by prefix – only if needed
    for prefix in target["instruments_enabled_prefixes"]:
        needs = any(n.startswith(prefix.rstrip('%')) and v != ("YES","YES")
                    for n, v in current[1].items())
        if needs:
            sql_params.append({
                "sql": "UPDATE performance_schema.setup_instruments "
                       "SET ENABLED='YES', TIMED='YES' WHERE NAME LIKE %s",
                "params": (prefix,)
            })
    # exact enables
    for name in target["instruments_enabled_exact"]:
        if current[1].get(name, ("NO","NO")) != ("YES","YES"):
            sql_params.append({
                "sql": "UPDATE performance_schema.setup_instruments SET ENABLED='YES', TIMED='YES' WHERE NAME=%s",
                "params": (name,)
            })
    # disables
    for prefix in target["instruments_disabled_prefixes"]:
        needs = any(n.startswith(prefix.rstrip('%')) and current[1][n][0] == "YES"
                    for n in current[1])
        if needs:
            sql_params.append({
                "sql": "UPDATE performance_schema.setup_instruments "
                       "SET ENABLED='NO', TIMED='NO' WHERE NAME LIKE %s",
                "params": (prefix,)
            })
    return sql_params

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
        con = _connect_cached()
        with con.cursor() as cur:
            current = _current_state(cur)
            updates = _diff(target, current)
            result["drift_detected"] = bool(updates)
            result["update_count"] = len(updates)
            if updates:
                LOG.info(f"Applying {len(updates)} updates to Performance Schema")
                con.begin()
                for sql_param in updates:
                    cur.execute(sql_param["sql"], sql_param["params"])
                con.commit()
                result["patch_applied"] = True
                
                # Verify changes were applied
                post_current = _current_state(cur)
                post_updates = _diff(target, post_current)
                result["verification_success"] = len(post_updates) == 0
        
        # Redact sensitive fields from logs
        log_safe_result = {k: v for k, v in result.items() if k not in ("error", "database")}
        # Optional single-flag for CloudWatch Filters/Alarms
        # log_safe_result["had_error"] = bool(result["error"])
        LOG.info(json.dumps(log_safe_result))
    except Exception as exc:
        if con:  # unconditional rollback when possible
            try: con.rollback()
            except Exception: pass
        result["error"] = str(exc)
        LOG.error("Failure: %s", exc, exc_info=True)
    return result

# NOTE: The duplicate copy in terraform/lambda/ was removed.
