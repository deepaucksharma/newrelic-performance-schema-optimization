###############################################
# outputs.tf - Performance Schema Automation
###############################################

output "parameter_group_id" {
  description = "ID of the created DB parameter group"
  value       = aws_db_parameter_group.perf_schema.id
}

output "cluster_parameter_group_id" {
  description = "ID of the created DB cluster parameter group (Aurora only)"
  value       = var.is_aurora ? aws_rds_cluster_parameter_group.perf_schema[0].id : null
}

output "lambda_function_name" {
  description = "Name of the Performance Schema configurator Lambda function"
  value       = aws_lambda_function.perf_schema_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Performance Schema configurator Lambda function"
  value       = aws_lambda_function.perf_schema_lambda.arn
}

output "lambda_iam_role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  value       = aws_iam_role.lambda_role.arn
}

output "rds_proxy_endpoint" {
  description = "Endpoint of the RDS Proxy (if created)"
  value       = var.create_proxy ? aws_db_proxy.perf_schema_proxy[0].endpoint : null
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch Log Group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "eventbridge_rules" {
  description = "List of created EventBridge rule names"
  value       = [aws_cloudwatch_event_rule.perf_schema_daily.name, aws_cloudwatch_event_rule.perf_schema_events.name]
}

output "security_group_ids" {
  description = "Map of created security group IDs"
  value       = {
    lambda   = aws_security_group.lambda_sg.id,
    rds_proxy = var.create_proxy ? aws_security_group.proxy_sg[0].id : null
  }
}