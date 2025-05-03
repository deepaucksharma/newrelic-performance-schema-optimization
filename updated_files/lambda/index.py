# ... imports omitted for brevity ...
def _connect():
    """Return a pymysql connection using the AWS CA bundle for SSL."""
    host = _rds_endpoint()
    pwd  = _iam_token(host, DB_USER) if IAM_AUTH else None

    # Use AWS SSL bundle; fallback to default ssl if bundle is missing
    ssl_cfg = {}
    ca_path = "/opt/python/rds-combined-ca-bundle.pem"
    if os.path.exists(ca_path):
        ssl_cfg["ca"] = ca_path

    return pymysql.connect(host=host,
                           user=DB_USER,
                           password=pwd,
                           port=DB_PORT,
                           connect_timeout=10,
                           ssl=ssl_cfg or True)
