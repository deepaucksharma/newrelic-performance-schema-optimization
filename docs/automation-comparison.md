# Automation Strategy Comparison for Performance Schema Management

> **Note**: This is an appendix document. For the main documentation flow, please start with [00-overview.md](00-overview.md).

## Overview

This document compares different approaches for automating Performance Schema (P_S) configuration on AWS RDS/Aurora. Each approach has different trade-offs in terms of implementation complexity, security, reliability, and operational overhead.

## Problem Context

Performance Schema settings managed via `UPDATE` statements to `performance_schema.setup_consumers` and `performance_schema.setup_instruments` do not persist across database restarts, failovers, or upgrades. While some settings can be controlled via Parameter Groups, fine-grained control requires runtime SQL statements.

## Automation Strategy Comparison

| Strategy | Description | Complexity | Security | Resilience | Best For | Limitations |
|----------|-------------|------------|----------|------------|----------|-------------|
| **Baseline: Parameter Groups Only** | Configure only what's available via AWS Parameter Groups | Low | High | High | Simple environments with basic monitoring needs | Limited granularity; can't control many specific instruments |
| **Lambda + EventBridge** | Serverless function triggered by schedules and DB events | Medium | High | High | Production environments; mature cloud teams | Requires proper IAM/VPC configuration |
| **CloudFormation Custom Resource** | Lambda function triggered by CFN stack operations | High | High | Medium | Infrastructure-as-Code centric teams | Runs only during stack operations; needs companion scheduled solution |
| **RDS Event Subscription + Lambda** | Lambda triggered by RDS event notifications | Medium | High | Medium-High | Event-driven architectures | May miss some events; requires additional scheduled checks |
| **EC2 Instance + Cron** | Dedicated EC2 instance running scheduled script | Medium | Medium | Medium | Teams with existing EC2 automation infrastructure | Additional infrastructure to manage; single point of failure |
| **CI/CD Pipeline Job** | Scheduled pipeline job running configuration script | Medium | Medium | Low | Dev/test environments; teams with strong CI/CD practices | Not event-driven; manual intervention needed after failovers |
| **Systems Manager Automation** | SSM documents executed on schedule | Medium | High | Medium | Organizations standardized on AWS Systems Manager | Requires additional configuration; not natively event-triggered |

## Recommended Multi-Layered Approach

For most production environments, we recommend a combination of:

1. **Parameter Groups (Layer 0)**: Configure all available P_S parameters via AWS Parameter Groups
2. **Lambda + EventBridge (Layer 1)**: Implement self-healing automation for non-persistent settings

This approach provides:
- Native AWS integration
- Event-driven responsiveness
- Scheduled verification
- Minimal infrastructure overhead
- Strong security posture

## Implementation Complexity Analysis

| Component | Implementation Effort | Maintenance Effort | Security Complexity | Required Expertise |
|-----------|----------------------|---------------------|---------------------|-------------------|
| Parameter Groups | Low | Low | Low | AWS RDS basics |
| Lambda Function | Medium | Low | Medium | Python/Node.js, AWS Lambda, database connectivity |
| EventBridge Rules | Low | Low | Low | AWS EventBridge basics |
| VPC Configuration | Medium | Low | Medium | AWS networking fundamentals |
| IAM Roles/Policies | Medium | Low | Medium | AWS IAM, security best practices |
| RDS Proxy | Medium | Low | Low | AWS RDS advanced features |
| CloudWatch Monitoring | Medium | Low | Low | AWS CloudWatch, alerting patterns |

## Security Considerations by Approach

| Strategy | Authentication Options | Network Security | Credential Management | Audit Trail |
|----------|------------------------|------------------|------------------------|------------|
| **Lambda + EventBridge** | IAM DB Auth (best), Secrets Manager | VPC, Security Groups | IAM roles, Secrets Manager | CloudTrail, CloudWatch Logs |
| **CloudFormation Custom Resource** | IAM DB Auth, Secrets Manager | VPC, Security Groups | IAM roles, CFN parameters | CloudTrail, CloudWatch Logs, CFN Events |
| **EC2 Instance + Cron** | IAM DB Auth, Secrets Manager, Instance Profile | VPC, Security Groups | IAM roles, Parameter Store | CloudTrail, Custom Logs |
| **CI/CD Pipeline Job** | IAM DB Auth, Pipeline Secrets | VPC Connectivity | Pipeline secrets, IAM roles | Pipeline Logs |
| **Systems Manager Automation** | IAM DB Auth, SSM Parameters | VPC, Security Groups | IAM roles, Parameter Store | CloudTrail, SSM Logs |

## Cost Comparison (Monthly Estimates)

| Strategy | Component Costs | Total Estimated Cost | Notes |
|----------|-----------------|----------------------|-------|
| **Lambda + EventBridge** | Lambda: ~$0-5<br>EventBridge: ~$0-1<br>RDS Proxy: ~$40 (t4g.small) | $5-50 | Cost varies by invocation frequency; RDS Proxy optional but recommended |
| **CloudFormation Custom Resource** | Lambda: ~$0-1 | $0-1 | Minimal cost due to infrequent invocation |
| **EC2 Instance + Cron** | EC2 t4g.micro: ~$10<br>EBS: ~$1-5 | $10-15 | Always-on infrastructure cost |
| **CI/CD Pipeline Job** | CI/CD minutes: ~$0-5 | $0-5 | Cost depends on pipeline provider |
| **Systems Manager Automation** | SSM Automation: ~$0-5 | $0-5 | Minimal cost for automation documents |

## Real-World Considerations

- **Multi-Region Deployments**: For global applications, implement the solution in each AWS region
- **Multi-Account Setups**: Use AWS Organizations and StackSets/Terraform for consistent deployment
- **High-Security Environments**: Prioritize IAM DB Authentication and VPC isolation
- **Operational Visibility**: Implement CloudWatch dashboards and alerts for automation health
- **Compliance Requirements**: Add AWS Config rules to verify consistent configuration

## Conclusion

The Lambda + EventBridge approach provides the best balance of automation, security, and operational efficiency for most production environments. Organizations with specific constraints or preferences may choose alternative approaches, but should ensure they address the fundamental challenges of configuration persistence and event-driven reconfiguration.

---

© New Relic, Inc. | Internal use and authorized customers only