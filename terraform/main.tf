###############################################
# main.tf - Performance Schema Automation
###############################################

# Parameter Group configuration
resource "aws_db_parameter_group" "perf_schema" {
  name        = "${var.prefix}-perf-schema-optimized"
  family      = var.parameter_family
  description = "Optimized Performance Schema settings for New Relic monitoring"

  # Master switch
  parameter {
    name  = "performance_schema"
    value = "1"
  }

  # Consumer parameters - expose as many as available for your engine version
  parameter {
    name  = "performance-schema-consumer-events-statements-current"
    value = "1"
  }

  parameter {
    name  = "performance-schema-consumer-events-statements-history"
    value = "1"
  }

  parameter {
    name  = "performance-schema-consumer-events-statements-history-long"
    value = "0"
  }

  parameter {
    name  = "performance-schema-consumer-events-waits-current"
    value = "0"
  }

  # Memory/sizing parameters
  parameter {
    name  = "performance_schema_max_digest_length"
    value = var.max_digest_length
  }

  parameter {
    name  = "performance_schema_max_sql_text_length"
    value = var.max_sql_text_length
  }

  tags = var.tags
}

# Aurora DB Cluster Parameter Group (if needed)
resource "aws_rds_cluster_parameter_group" "perf_schema" {
  count = var.is_aurora ? 1 : 0

  name        = "${var.prefix}-perf-schema-cluster"
  family      = var.cluster_parameter_family
  description = "Cluster-level Performance Schema settings"

  parameter {
    name  = "performance_schema"
    value = "1"
  }

  tags = var.tags
}

# RDS Proxy configuration (optional but recommended)
resource "aws_db_proxy" "perf_schema_proxy" {
  count = var.create_proxy ? 1 : 0

  name                   = "${var.prefix}-perf-schema-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy_role[0].arn
  vpc_security_group_ids = [aws_security_group.proxy_sg[0].id]
  vpc_subnet_ids         = var.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = var.db_secret_arn
  }

  tags = var.tags
}

resource "aws_db_proxy_default_target_group" "perf_schema_target" {
  count = var.create_proxy ? 1 : 0

  db_proxy_name = aws_db_proxy.perf_schema_proxy[0].name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "perf_schema_target" {
  count = var.create_proxy ? 1 : 0

  db_proxy_name         = aws_db_proxy.perf_schema_proxy[0].name
  target_group_name     = aws_db_proxy_default_target_group.perf_schema_target[0].name
  db_cluster_identifier = var.is_aurora ? var.db_cluster_identifier : null
  db_instance_identifier = var.is_aurora ? null : var.db_instance_identifier
}

# Security Group for RDS Proxy
resource "aws_security_group" "proxy_sg" {
  count = var.create_proxy ? 1 : 0

  name        = "${var.prefix}-perf-schema-proxy-sg"
  description = "Security group for Performance Schema RDS Proxy"
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "proxy_egress" {
  count = var.create_proxy ? 1 : 0

  security_group_id        = aws_security_group.proxy_sg[0].id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.db_security_group_id
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.prefix}-perf-schema-lambda-sg"
  description = "Security group for Performance Schema Lambda function"
  vpc_id      = var.vpc_id

  # Primary egress rule - Security Group reference (for same-VPC connections)
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_group_id = var.create_proxy ? aws_security_group.proxy_sg[0].id : var.db_security_group_id
  }
  
  # Fallback egress rule - CIDR blocks (for cross-VPC connections)
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = var.db_subnet_cidrs
    description     = "Fallback for cross-VPC connections"
  }

  tags = var.tags
}

# Security Group rule allowing Lambda access to RDS Proxy
resource "aws_security_group_rule" "proxy_ingress" {
  count = var.create_proxy ? 1 : 0

  security_group_id        = aws_security_group.proxy_sg[0].id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_sg.id
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy_role" {
  count = var.create_proxy ? 1 : 0

  name = "${var.prefix}-perf-schema-proxy-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "proxy_policy" {
  count = var.create_proxy ? 1 : 0

  name = "${var.prefix}-perf-schema-proxy-policy"
  role = aws_iam_role.proxy_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect = "Allow",
        Resource = [var.db_secret_arn]
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix}-perf-schema-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.prefix}-perf-schema-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject"
        ],
        Effect   = "Allow",
        Resource = var.sql_s3_bucket != "" ? "arn:aws:s3:::${var.sql_s3_bucket}/${var.sql_s3_key}" : "*"
      },
      var.use_iam_auth ? {
        Action = [
          "rds-db:connect"
        ],
        Effect   = "Allow",
        Resource = var.is_aurora ? 
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:cluster-${var.db_cluster_resource_id}/lambda_perf_schema" :
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:dbi-${var.db_instance_resource_id}/lambda_perf_schema"
      } : {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = [var.db_secret_arn]
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "perf_schema_lambda" {
  function_name    = "${var.prefix}-perf-schema-configurator"
  description      = "Configures Performance Schema for New Relic monitoring"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128
  publish          = true

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DB_IDENTIFIER            = var.is_aurora ? var.db_cluster_identifier : var.db_instance_identifier
      DB_SECRET_ARN            = var.db_secret_arn
      DB_USER                  = "lambda_perf_schema"
      DB_USE_IAM_AUTH          = var.use_iam_auth ? "true" : "false"
      DB_IS_AURORA             = var.is_aurora ? "true" : "false"
      DB_PROXY_ENDPOINT        = var.create_proxy ? aws_db_proxy.perf_schema_proxy[0].endpoint : ""
      DB_HOST                  = var.db_host
      SNS_TOPIC_ARN            = var.sns_topic_arn
      PERFORMANCE_SCHEMA_HASH  = var.performance_schema_hash
      # SQL statements are stored in S3 to avoid hitting the 4KB env var limit
      SQL_S3_BUCKET            = var.sql_s3_bucket
      SQL_S3_KEY               = var.sql_s3_key
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  tags = var.tags
}

# Lambda Code and Dependencies
# Note: Before applying, run the following commands to prepare the Lambda package with dependencies:
# mkdir -p ${path.module}/lambda-build
# pip install pymysql -t ${path.module}/lambda-build
# cp ${path.module}/lambda/index.py ${path.module}/lambda-build/
# cd ${path.module}/lambda-build && zip -r ../lambda_function.zip .

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/lambda-build"
  depends_on  = [null_resource.install_dependencies]
}

# Null resource to install dependencies
resource "null_resource" "install_dependencies" {
  triggers = {
    always_run = "${timestamp()}" # Run on every apply to ensure fresh dependencies
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/lambda-build
      pip install pymysql -t ${path.module}/lambda-build
      cp ${path.module}/lambda/index.py ${path.module}/lambda-build/
    EOF
  }
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "perf_schema_daily" {
  name                = "${var.prefix}-perf-schema-daily-check"
  description         = "Daily check for Performance Schema configuration"
  schedule_expression = "rate(1 day)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "perf_schema_daily_target" {
  rule      = aws_cloudwatch_event_rule.perf_schema_daily.name
  target_id = "PerformanceSchemaLambda"
  arn       = aws_lambda_function.perf_schema_lambda.arn
}

resource "aws_cloudwatch_event_rule" "perf_schema_events" {
  name        = "${var.prefix}-perf-schema-db-events"
  description = "Detect database events that require Performance Schema reconfiguration"

  event_pattern = jsonencode({
    source      = ["aws.rds"],
    "detail-type" = ["RDS DB Instance Event"],
    detail = {
      EventID = [
        "RDS-EVENT-0004", # DB instance restarted
        "RDS-EVENT-0045", # Multi-AZ failover completed
        "RDS-EVENT-0046", # Multi-AZ failover to replica completed
        "RDS-EVENT-0071", # DB instance point-in-time restore completed
        "RDS-EVENT-0025", # DB instance recovery completed
        "RDS-EVENT-0006", # DB instance reboot completed
        "RDS-EVENT-0221", # Storage autoscaling initiated
        "RDS-EVENT-0225"  # Storage autoscaling completed
      ]
    }
  })

  tags = var.tags
}

# Specific rule for Aurora cluster events
resource "aws_cloudwatch_event_rule" "aurora_cluster_events" {
  count       = var.is_aurora ? 1 : 0
  name        = "${var.prefix}-perf-schema-aurora-cluster-events"
  description = "Detect Aurora cluster events that require Performance Schema reconfiguration"

  event_pattern = jsonencode({
    source      = ["aws.rds"],
    "detail-type" = ["RDS DB Cluster Event"],
    detail = {
      EventID = [
        "RDS-EVENT-0069", # Cluster failover completed
        "RDS-EVENT-0070", # Cluster failover initiated
        "RDS-EVENT-0071", # Cluster restore completed
        "RDS-EVENT-0091", # Writer instance changed
        "RDS-EVENT-0141", # Cluster topology changed
        "RDS-EVENT-0173"  # Cluster maintenance complete
      ]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "perf_schema_events_target" {
  rule      = aws_cloudwatch_event_rule.perf_schema_events.name
  target_id = "PerformanceSchemaLambda"
  arn       = aws_lambda_function.perf_schema_lambda.arn
}

resource "aws_cloudwatch_event_target" "aurora_cluster_events_target" {
  count     = var.is_aurora ? 1 : 0
  rule      = aws_cloudwatch_event_rule.aurora_cluster_events[0].name
  target_id = "PerformanceSchemaLambda"
  arn       = aws_lambda_function.perf_schema_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge_aurora_events" {
  count         = var.is_aurora ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeAuroraEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perf_schema_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.aurora_cluster_events[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_daily" {
  statement_id  = "AllowExecutionFromEventBridgeDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perf_schema_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.perf_schema_daily.arn
}

resource "aws_lambda_permission" "allow_eventbridge_events" {
  statement_id  = "AllowExecutionFromEventBridgeEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perf_schema_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.perf_schema_events.arn
}

# CloudWatch Logs Metric Filters
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.perf_schema_lambda.function_name}"
  retention_in_days = 30
  
  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "drift_detected" {
  name           = "${var.prefix}-perf-schema-drift-detected"
  pattern        = "{ $.drift_detected = true }"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name

  metric_transformation {
    name      = "PerfSchemaDriftDetected"
    namespace = "Custom/${var.prefix}/PerfSchema"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "patch_success" {
  name           = "${var.prefix}-perf-schema-patch-success"
  pattern        = "{ $.patch_applied = true }"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name

  metric_transformation {
    name      = "PerfSchemaPatchSuccess"
    namespace = "Custom/${var.prefix}/PerfSchema"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "patch_failure" {
  name           = "${var.prefix}-perf-schema-patch-failure"
  pattern        = "{ $.error != \"\" }"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name

  metric_transformation {
    name      = "PerfSchemaPatchFailure"
    namespace = "Custom/${var.prefix}/PerfSchema"
    value     = "1"
  }
}

# CloudWatch Alarm for persistent drift
resource "aws_cloudwatch_metric_alarm" "persistent_drift" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-perf-schema-persistent-drift"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PerfSchemaDriftDetected"
  namespace           = "Custom/${var.prefix}/PerfSchema"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Performance Schema configuration drift detected and not corrected"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  tags = var.tags
}

# CloudWatch Alarm for patch failures
resource "aws_cloudwatch_metric_alarm" "patch_failure" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-perf-schema-patch-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PerfSchemaPatchFailure"
  namespace           = "Custom/${var.prefix}/PerfSchema"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Performance Schema patch application failed"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  tags = var.tags
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}