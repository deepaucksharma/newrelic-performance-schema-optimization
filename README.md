# New Relic MySQL Monitoring Optimization for AWS (2025)

This repository contains comprehensive resources for optimizing MySQL/Aurora monitoring on AWS RDS and Aurora to ensure efficient integration with New Relic while minimizing system overhead and data costs. Our primary recommendation for 2025 is to leverage AWS Performance Insights as your foundation, supplemented by targeted Performance Schema configurations where needed.

## Repository Structure

- **docs/**: Documentation and guides
  - `performance-insights-guide.md`: Primary recommended approach using AWS PI
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
* **Improved performance**: Typically adds only 2-8% CPU overhead on MySQL 8.0.38+
* **Focused monitoring**: Capture only metrics that drive actionable insights
* **Consistent visibility**: Automated configuration ensures persistent monitoring
* **Compliance**: Auditable, consistent monitoring configuration across environments

## Implementation Approach

Our 2025 recommended approach uses a tiered strategy that prioritizes AWS-managed solutions:

1. **Performance Insights (Primary Layer)**: Let AWS do the heavy lifting by enabling Performance Insights to automatically manage Performance Schema
2. **Parameter Groups (Supplemental Layer)**: Configure buffer sizes and other persistent settings via AWS Parameter Groups
3. **Lambda + EventBridge (Optional Layer)**: Implement serverless automation only for specialized requirements not addressed by Performance Insights:
   - Responds to database restart/failover events
   - Performs scheduled verification
   - Detects and corrects configuration drift
   - Provides monitoring and alerting via CloudWatch

## Getting Started

For most MySQL on AWS workloads, start with our [Performance Insights Guide](docs/performance-insights-guide.md) to implement the primary recommended approach. For specialized requirements, refer to the [Implementation Guide](docs/implementation-guide.md) for detailed instructions on supplemental configurations.

## Support

For assistance with Performance Schema optimization:

* Contact your New Relic Technical Account Manager
* Email our database specialists: db-support@newrelic.com
* Visit our documentation: [docs.newrelic.com/mysql-monitoring](https://docs.newrelic.com/mysql-monitoring)

---

© New Relic, Inc. | Internal use and authorized customers only# newrelic-performance-schema-optimization
