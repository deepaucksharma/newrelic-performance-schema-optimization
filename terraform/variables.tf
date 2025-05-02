###############################################
# variables.tf - Performance Schema Automation
###############################################

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "newrelic"
}

variable "parameter_family" {
  description = "DB parameter group family (e.g., mysql8.0, aurora-mysql8.0)"
  type        = string
}

variable "cluster_parameter_family" {
  description = "DB cluster parameter group family for Aurora"
  type        = string
  default     = ""
}

variable "is_aurora" {
  description = "Whether the database is an Aurora cluster"
  type        = bool
  default     = false
}

variable "db_instance_identifier" {
  description = "RDS DB instance identifier"
  type        = string
  default     = ""
}

variable "db_instance_resource_id" {
  description = "RDS DB instance resource ID for IAM authentication"
  type        = string
  default     = ""
}

variable "db_cluster_identifier" {
  description = "Aurora DB cluster identifier"
  type        = string
  default     = ""
}

variable "db_cluster_resource_id" {
  description = "Aurora DB cluster resource ID for IAM authentication"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "Database hostname or endpoint"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  type        = string
}

variable "db_security_group_id" {
  description = "Security group ID of the database"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda and RDS Proxy"
  type        = list(string)
}

variable "create_proxy" {
  description = "Whether to create an RDS Proxy"
  type        = bool
  default     = true
}

variable "use_iam_auth" {
  description = "Whether to use IAM authentication for database access"
  type        = bool
  default     = true
}

variable "max_digest_length" {
  description = "Value for performance_schema_max_digest_length parameter"
  type        = string
  default     = "1024"
}

variable "max_sql_text_length" {
  description = "Value for performance_schema_max_sql_text_length parameter"
  type        = string
  default     = "4096"
}

variable "performance_schema_hash" {
  description = "Expected hash value of properly configured Performance Schema setup"
  type        = string
}

variable "sql_update_statements" {
  description = "SQL statements to apply for Performance Schema configuration"
  type        = string
  default     = <<-EOT
-- Enable statement consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME IN (
  'events_statements_current',
  'events_statements_history',
  'statements_digest'
);

-- Disable high-overhead consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'NO'
WHERE NAME IN (
  'events_statements_history_long',
  'events_stages_current',
  'events_stages_history',
  'events_stages_history_long',
  'events_waits_current', 
  'events_waits_history',
  'events_waits_history_long'
);

-- Enable statement instruments
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES' 
WHERE NAME LIKE 'statement/%';

-- Disable high-overhead instruments
UPDATE performance_schema.setup_instruments
SET ENABLED = 'NO', TIMED = 'NO'
WHERE NAME LIKE 'wait/io/file/%'
   OR NAME LIKE 'wait/io/table/%'
   OR NAME LIKE 'wait/lock/metadata/%'
   OR NAME LIKE 'wait/lock/table/%'
   OR NAME LIKE 'wait/sync/rwlock/%'
   OR NAME LIKE 'wait/sync/mutex/%'
   OR NAME LIKE 'wait/sync/cond/%';
EOT
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  type        = string
  default     = ""
}

variable "create_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Managed_By  = "Terraform"
    Service     = "New Relic MySQL Monitoring"
    Environment = "Production"
  }
}