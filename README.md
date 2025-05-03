# Optimizing MySQL Performance Schema for New Relic Monitoring on AWS

This project provides solutions for reliable MySQL/Aurora Performance Schema configuration on AWS to ensure consistent New Relic monitoring.

**The core problem**  
Performance Schema settings in MySQL/Aurora are reset after database restarts, failovers, and upgrades, causing monitoring gaps and inconsistent metrics collection in New Relic.

**Our solution: A layered approach**

| Layer | Purpose | Implementation |
|-------|---------|----------------|
| **Performance Insights** | AWS-managed Performance Schema configuration that persists through restarts | Enable through AWS console or CLI |
| **Parameter Group** | Persistent baseline settings: `performance_schema = 1`, buffer sizes | 1× DB parameter group per engine family |
| **Lambda Automation** | Optional: Re-apply consumer/instrument settings after every restart | EventBridge → Lambda → RDS/Aurora |

> **Benefits:** Consistent metrics · 40-70% ingest savings · Minimal CPU overhead · Zero manual reconfiguration

## Key Features

- **AWS Performance Insights Integration**: Leverage AWS's built-in Performance Schema management
- **Persistent Configuration**: Ensure monitoring continues after database restarts and failovers
- **Optimized Metrics Collection**: Focus on high-value metrics while minimizing overhead
- **Flexible Deployment Options**: Use CloudFormation or Terraform for automated deployment
- **Comprehensive Documentation**: Clear guidance on implementation and troubleshooting

## Quickstart Guide

For most users, we recommend starting with AWS Performance Insights:

1. **Enable Performance Insights** in your RDS/Aurora console
2. **Apply supplemental Parameter Group** settings for optimal New Relic integration
3. **Configure New Relic** with appropriate database permissions

For specialized needs beyond what Performance Insights provides, use the Lambda automation:

1. **Deploy the automation** using CloudFormation or Terraform
2. **Create database user** with Performance Schema permissions
3. **Configure target state** using the YAML configuration file

Detailed instructions for both approaches are available in our [Implementation Guide](docs/02-implementation.md).

## Documentation

| Resource | Description |
|----------|-------------|
| [Overview](docs/00-overview.md) | Introduction and solution overview |
| [Strategy Guide](docs/01-strategy.md) | Decision tree and approach selection |
| [Implementation Guide](docs/02-implementation.md) | Step-by-step implementation instructions |
| [Troubleshooting Guide](docs/03-troubleshooting.md) | Solutions for common issues |
| [Performance Insights Guide](docs/pi.md) | Detailed guide for AWS Performance Insights setup |
| [Lambda Automation Guide](docs/lambda.md) | In-depth guide for the Lambda automation approach |
| [CloudFormation Deployment](cloudformation/README.md) | CloudFormation template details |
| [Terraform Deployment](terraform/README.md) | Terraform module usage |
| [SQL Configuration](sql/README.md) | Understanding and customizing the target configuration |

## Performance Insights vs. Lambda Automation

For most MySQL/Aurora workloads on AWS, we recommend:

1. **Start with Performance Insights** for simple, managed Performance Schema configuration
2. **Add Parameter Group settings** for optimizing buffer sizes and specific flags
3. **Use Lambda automation** only for specialized monitoring needs not covered by PI

See our [Strategy Guide](docs/01-strategy.md) for detailed recommendations.

## Support

For assistance, contact New Relic DB Engineering: db-support@newrelic.com
