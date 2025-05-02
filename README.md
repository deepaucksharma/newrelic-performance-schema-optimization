# New Relic Performance Schema Optimization for MySQL/Aurora

This repository contains comprehensive resources for optimizing MySQL/Aurora Performance Schema (P_S) on AWS RDS and Aurora to ensure efficient monitoring with New Relic while minimizing system overhead and data costs.

## Repository Structure

- **docs/**: Documentation and guides
  - `customer-guide.md`: End-user friendly documentation
  - `implementation-guide.md`: Technical implementation instructions
  - `automation-comparison.md`: Analysis of implementation approaches
  - `troubleshooting-guide.md`: Solutions for common issues
  - `executive-summary.md`: Business-focused overview

- **terraform/**: Complete Terraform module for Performance Schema automation
  - `main.tf`: Core Terraform configuration
  - `variables.tf`: Input variables declaration
  - `outputs.tf`: Output variables

- **cloudformation/**: AWS CloudFormation template
  - `performance-schema-automation.yaml`: Complete CloudFormation template

- **lambda/**: Lambda function code
  - `index.py`: Python implementation for runtime configuration

- **sql/**: SQL scripts for configuration and verification
  - `perf-schema-configuration.sql`: Complete SQL configuration script

## Key Benefits

* **Reduced costs**: Lower New Relic data ingest volume (typically 40-70% savings)
* **Improved performance**: Minimal overhead on production databases
* **Focused monitoring**: Capture only metrics that drive actionable insights
* **Consistent visibility**: Automated configuration ensures persistent monitoring
* **Compliance**: Auditable, consistent monitoring configuration across environments

## Implementation Approach

This solution uses a multi-layered approach:

1. **Parameter Groups (Layer 0)**: Configure persistent settings via AWS Parameter Groups
2. **Lambda + EventBridge (Layer 1)**: Implement serverless automation for non-persistent settings that:
   - Responds to database restart/failover events
   - Performs scheduled verification
   - Detects and corrects configuration drift
   - Provides monitoring and alerting via CloudWatch

## Getting Started

Please refer to the [Implementation Guide](docs/implementation-guide.md) for detailed instructions on deploying this solution.

## Support

For assistance with Performance Schema optimization:

* Contact your New Relic Technical Account Manager
* Email our database specialists: db-support@newrelic.com
* Visit our documentation: [docs.newrelic.com/mysql-monitoring](https://docs.newrelic.com/mysql-monitoring)

---

© New Relic, Inc. | Internal use and authorized customers only# newrelic-performance-schema-optimization
