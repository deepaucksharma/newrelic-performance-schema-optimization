terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Change to your region
}

# Get current AWS account ID for ARN scoping
data "aws_caller_identity" "current" {}

locals {
  use_secret_manager = var.db_secret_arn != "" && var.use_iam_auth == false
}

# 1. Parameter Group (baseline)
resource "aws_db_parameter_group" "perf_schema" {
  name        = "${var.prefix}-param-group"
  family      = var.engine_family
  description = "New Relic optimized Performance Schema baseline"

  parameter { name = "performance_schema"                                      value = "1"      }
  parameter { name = "performance_schema_digests_size"                        value = "10000"  }
  parameter { name = "performance_schema_max_sql_text_length"                 value = "4096"   }

  tags = var.tags
}

# 1.5 S3 Bucket with versioning and encryption
resource "aws_s3_bucket" "config_bucket" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.sql_bucket
  
  tags = var.tags
}

resource "aws_s3_bucket_versioning" "config_bucket_versioning" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket_encryption" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. Lambda Layer
resource "aws_lambda_layer_version" "pymysql_layer" {
  layer_name = "${var.prefix}-pymysql-layer"
  description = "PyMySQL and PyYAML for Performance Schema Lambda"
  
  s3_bucket = var.sql_bucket
  s3_key    = var.lambda_layer_key
  
  compatible_runtimes = ["python3.12"]
}

# 3. Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name        = "${var.prefix}-lambda-sg"
  description = "New Relic Performance Schema Lambda outbound traffic"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Restrict to VPC CIDR block
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-lambda-sg"
  })
}

# 4. Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# 5. Lambda Role Policies
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "lambda_rds_access" {
  name        = "${var.prefix}-rds-access"
  description = "Allow Lambda to access RDS and describe instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "arn:aws:rds:*:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "arn:aws:rds-db:*:${data.aws_caller_identity.current.account_id}:dbuser:*/${var.db_user}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rds_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_rds_access.arn
}

resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.prefix}-s3-access"
  description = "Allow Lambda to access S3 configuration"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.sql_bucket}/${var.sql_key}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

# Secrets Manager access (conditional)
resource "aws_iam_policy" "lambda_secrets_access" {
  count       = local.use_secret_manager ? 1 : 0
  name        = "${var.prefix}-secrets-access"
  description = "Allow Lambda to access database credentials in Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_access" {
  count      = local.use_secret_manager ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_secrets_access[0].arn
}

# 6. Lambda Function
resource "aws_lambda_function" "perf_schema_fn" {
  function_name = "${var.prefix}-perf-schema-optimizer"
  description   = "New Relic Performance Schema configuration automation"
  
  s3_bucket = var.sql_bucket
  s3_key    = var.lambda_code_key
  
  runtime = "python3.12"
  handler = "index.lambda_handler"
  timeout = 45
  memory_size = 128
  
  role = aws_iam_role.lambda_role.arn
  
  layers = [aws_lambda_layer_version.pymysql_layer.arn]
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  environment {
    variables = {
      SQL_BUCKET = var.sql_bucket
      SQL_KEY    = var.sql_key
      DB_ID      = var.database_id
      IS_AURORA  = var.is_aurora ? "true" : "false"
      IAM_AUTH   = var.use_iam_auth ? "true" : "false"
      DB_USER    = var.db_user
      NR_ACCOUNT = var.new_relic_account_id
      SECRET_ARN = var.db_secret_arn
    }
  }
  
  lifecycle {
    ignore_changes = [s3_key] # Prevents recreation when you just upload a new ZIP under the same key
  }
  
  tags = var.tags
}

# 7. CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.perf_schema_fn.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# 8. EventBridge Rules
resource "aws_cloudwatch_event_rule" "daily_check" {
  name        = "${var.prefix}-daily-check"
  description = "Daily verification of Performance Schema configuration"
  
  schedule_expression = "rate(1 day)"
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "daily_check_target" {
  rule      = aws_cloudwatch_event_rule.daily_check.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.perf_schema_fn.arn
}

resource "aws_lambda_permission" "daily_check_permission" {
  statement_id  = "AllowExecutionFromCloudWatchDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perf_schema_fn.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_check.arn
}

resource "aws_cloudwatch_event_rule" "rds_events" {
  name        = "${var.prefix}-rds-events"
  description = "Trigger on RDS restart/failover events"
  
  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event", "RDS DB Cluster Event"]
    detail      = {
      EventID = [
        "RDS-EVENT-0004", # instance reboot
        "RDS-EVENT-0045", # failover complete
        "RDS-EVENT-0046", # failover start
        "RDS-EVENT-0071", # reboot recovery
        "RDS-EVENT-0006"  # restart
      ]
    }
  })
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "rds_events_target" {
  rule      = aws_cloudwatch_event_rule.rds_events.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.perf_schema_fn.arn
}

resource "aws_lambda_permission" "rds_events_permission" {
  statement_id  = "AllowExecutionFromCloudWatchRDSEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perf_schema_fn.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_events.arn
}

# 9. CloudWatch Alarms (optional)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.create_alarms ? 1 : 0
  alarm_name          = "${var.prefix}-lambda-errors"
  alarm_description   = "Alert on Performance Schema Lambda failures"
  
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  
  dimensions = {
    FunctionName = aws_lambda_function.perf_schema_fn.function_name
  }
  
  treat_missing_data = "notBreaching"
  
  tags = var.tags
}
