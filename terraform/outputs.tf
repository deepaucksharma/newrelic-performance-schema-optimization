output "parameter_group_name" {
  description = "Parameter Group to attach to RDS/Aurora"
  value       = aws_db_parameter_group.perf_schema.name
}

output "parameter_group_arn" {
  description = "Parameter Group ARN"
  value       = aws_db_parameter_group.perf_schema.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.perf_schema_fn.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.perf_schema_fn.arn
}

output "lambda_log_group_name" {
  description = "CloudWatch Log Group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "daily_check_rule_name" {
  description = "EventBridge rule for daily checks"
  value       = aws_cloudwatch_event_rule.daily_check.name
}

output "rds_events_rule_name" {
  description = "EventBridge rule for RDS events"
  value       = aws_cloudwatch_event_rule.rds_events.name
}

output "security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "db_user" {
  description = "Database user required for Lambda"
  value       = var.db_user
}

output "db_setup_command" {
  description = "Command to create the required database user with IAM auth"
  value       = var.use_iam_auth ? "CREATE USER '${var.db_user}'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS'" : "See Secrets Manager for credentials"
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = "1. Attach parameter group ${aws_db_parameter_group.perf_schema.name} to your RDS/Aurora instance\n2. Reboot the instance\n3. Check Lambda logs to verify configuration"
}
