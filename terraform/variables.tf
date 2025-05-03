variable "prefix" {
  description = "Prefix for all created resources"
  type        = string
  default     = "nr-mysql-ps"
}

variable "engine_family" {
  description = "MySQL/Aurora engine family"
  type        = string
  default     = "mysql8.0"
  validation {
    condition     = contains(["mysql8.0", "mysql5.7", "aurora-mysql8.0", "aurora-mysql5.7"], var.engine_family)
    error_message = "Engine family must be one of: mysql8.0, mysql5.7, aurora-mysql8.0, aurora-mysql5.7"
  }
}

variable "database_id" {
  description = "RDS Instance ID or Aurora Cluster ID"
  type        = string
}

variable "is_aurora" {
  description = "Whether target is Aurora cluster (true) or RDS instance (false)"
  type        = bool
  default     = false
}

variable "sql_bucket" {
  description = "S3 bucket for YAML configuration and Lambda code"
  type        = string
}

variable "create_bucket" {
  description = "Whether to create the S3 bucket (true) or use an existing one (false)"
  type        = bool
  default     = false
}

variable "sql_key" {
  description = "S3 key for YAML configuration file"
  type        = string
  default     = "target-config.yaml"
}

variable "lambda_code_key" {
  description = "S3 key for Lambda code zip file"
  type        = string
  default     = "lambda.zip"
}

variable "lambda_layer_key" {
  description = "S3 key for Lambda layer zip file"
  type        = string
  default     = "pymysql-pyyaml-layer.zip"
}

variable "vpc_id" {
  description = "VPC where Lambda will run (must have access to RDS/Aurora)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block allowed for Lambda egress; empty uses VPC CIDR automatically"
  type        = string
  default     = ""  # No open-egress by accident, will use VPC CIDR if empty
  # Optional – leave "" to auto-detect using the selected VPC data-source
}

variable "subnet_ids" {
  description = "Subnets where Lambda will run (must have access to RDS/Aurora)"
  type        = list(string)
}

variable "db_secret_arn" {
  description = "Optional SecretManager ARN for database credentials (if not using IAM auth)"
  type        = string
  default     = ""
}

variable "use_iam_auth" {
  description = "Use IAM authentication for database connection"
  type        = bool
  default     = true
}

variable "db_user" {
  description = "Database user for Lambda connection"
  type        = string
  default     = "lambda_perf_schema"
}

variable "new_relic_account_id" {
  description = "Optional: New Relic account ID for logging"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    ManagedBy = "terraform"
    Component = "new-relic-perf-schema"
  }
}

variable "create_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 30    # Aligned with CloudFormation default of 30 days
}

# --- NEW ---
variable "grant_update_note" {
  description = "Informational – ensure UPDATE privilege on performance_schema.*"
  type        = string
  default     = "Remember to GRANT SELECT,UPDATE ON performance_schema.* to the Lambda user."
}
