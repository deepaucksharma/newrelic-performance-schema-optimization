# MySQL Performance Schema Optimization for New Relic

This solution enables reliable MySQL Performance Schema configuration for New Relic monitoring on AWS RDS and Aurora. It solves the problem of performance schema settings being reset after database restarts and failovers, ensuring consistent metrics collection and optimal monitoring.

## The Challenge

Runtime tables in MySQL Performance Schema live in memory and are reset whenever a database instance restarts or fails over. This causes:

1. **Gaps in monitoring data** - After restarts, monitoring is incomplete until settings are manually reconfigured
2. **Inconsistent metrics collection** - Different configurations lead to varying levels of detail and overhead
3. **Management overhead** - Manual reconfiguration after every event is time-consuming and error-prone

## Our Solution

We offer a comprehensive approach with multiple layers of configuration:

1. **Primary Approach: AWS Performance Insights** - Let AWS manage Performance Schema automatically
2. **Supplemental Configuration: Parameter Groups** - Apply persistent settings via AWS Parameter Groups
3. **Optional Automation: Lambda Function** - For specialized monitoring needs beyond Performance Insights

## Getting Started

1. Review the [Strategy Guide](01-strategy.md) to decide which approach best fits your needs
2. Follow the [Implementation Guide](02-implementation.md) for step-by-step instructions
3. Consult the [Troubleshooting Guide](03-troubleshooting.md) if you encounter any issues

For most users, enabling AWS Performance Insights is the simplest and most effective approach, with the Lambda automation serving as an optional supplement for specialized monitoring requirements.
