#!/bin/bash
# Performance Insights Quick Start Script
# This script enables Performance Insights on an RDS/Aurora instance
# and configures New Relic for optimal monitoring.

# Display usage instructions
function show_usage {
  echo "Usage: $0 --db-identifier <db-identifier> [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --db-identifier      RDS DB instance identifier"
  echo ""
  echo "Options:"
  echo "  --region             AWS region (default: uses AWS CLI default)"
  echo "  --retention          Performance Insights retention period in days (default: 7)"
  echo "  --nr-config-path     Path to New Relic config file (optional)"
  echo "  --help               Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 --db-identifier my-mysql-instance --region us-west-2 --retention 7"
  exit 1
}

# Parse arguments
DB_IDENTIFIER=""
REGION=""
RETENTION="7"
NR_CONFIG_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-identifier)
      DB_IDENTIFIER="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --retention)
      RETENTION="$2"
      shift 2
      ;;
    --nr-config-path)
      NR_CONFIG_PATH="$2"
      shift 2
      ;;
    --help)
      show_usage
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Validate required parameters
if [ -z "$DB_IDENTIFIER" ]; then
  echo "Error: --db-identifier is required"
  show_usage
fi

# Set region parameter if provided
REGION_PARAM=""
if [ -n "$REGION" ]; then
  REGION_PARAM="--region $REGION"
fi

# Enable Performance Insights
echo "Enabling Performance Insights for $DB_IDENTIFIER..."
CMD="aws rds modify-db-instance $REGION_PARAM --db-instance-identifier $DB_IDENTIFIER --enable-performance-insights --performance-insights-retention-period $RETENTION --apply-immediately"
echo "Executing: $CMD"
eval $CMD

if [ $? -ne 0 ]; then
  echo "Error: Failed to enable Performance Insights"
  exit 1
fi

echo "Performance Insights enabled successfully!"
echo "Retention period: $RETENTION days"

# Update New Relic configuration if path provided
if [ -n "$NR_CONFIG_PATH" ]; then
  echo "Updating New Relic configuration at $NR_CONFIG_PATH..."
  
  # Check if the file exists
  if [ ! -f "$NR_CONFIG_PATH" ]; then
    echo "Error: New Relic config file not found at $NR_CONFIG_PATH"
    exit 1
  fi
  
  # Check if extended_performance_schema_metrics is already enabled
  if grep -q "extended_performance_schema_metrics: true" "$NR_CONFIG_PATH"; then
    echo "extended_performance_schema_metrics already enabled in New Relic config"
  else
    # Find the mysql: section or add it if it doesn't exist
    if grep -q "mysql:" "$NR_CONFIG_PATH"; then
      # Add extended_performance_schema_metrics under mysql section
      sed -i '/mysql:/a\  extended_performance_schema_metrics: true' "$NR_CONFIG_PATH"
    else
      # Add mysql section with extended_performance_schema_metrics
      echo -e "\nmysql:\n  extended_performance_schema_metrics: true" >> "$NR_CONFIG_PATH"
    fi
    
    echo "Updated New Relic config with extended_performance_schema_metrics: true"
  fi
fi

echo ""
echo "Next steps:"
echo "1. Ensure your New Relic MySQL monitoring is configured with:"
echo "   mysql:"
echo "     extended_performance_schema_metrics: true"
echo ""
echo "2. Ensure New Relic monitoring user has appropriate permissions:"
echo "   GRANT SELECT ON performance_schema.* TO 'newrelic'@'%';"
echo ""
echo "3. Wait for Performance Insights to collect data (usually within minutes)"
echo ""
echo "4. View database metrics in New Relic and AWS Performance Insights dashboard"
echo "   AWS Console: https://console.aws.amazon.com/rds/home?region=${REGION:-us-east-1}#performance-insights-v2:dashboard"
echo ""
echo "For more detailed configuration options, see our documentation:"
echo "  docs/performance-insights-guide.md"
