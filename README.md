# Reliably Configuring MySQL Performance Schema on AWS RDS/Aurora for New Relic Monitoring

**The core problem**  
`UPDATE` statements on `performance_schema.setup_*` tables are memory-only inside
RDS/Aurora. After every reboot, fail-over or version upgrade they disappear, breaking
New Relic monitoring and creating observation gaps.

**Solution in two layers**

| Layer | Purpose | How we implement |
|-------|---------|------------------|
| **Parameter Group** | Persistent baseline: `performance_schema = 1`, buffer sizes, any consumer flags exposed by AWS | 1× DB parameter group per engine family |
| **Lambda Automation** | Re-apply _all other_ consumer / instrument UPDATEs after every event & on a daily schedule | EventBridge rule → Lambda in VPC, IAM Auth, YAML target-state file in S3 |

> **Benefits**   Consistent metrics · 40-70 % ingest savings · < 8 % CPU overhead · zero manual re-configuration

### Get started
| Step | Action | Docs |
|------|--------|------|
| 1 | Review [_Target Configuration_](docs/GUIDE.md#2-target-configuration) | docs/GUIDE.md |
| 2 | Deploy via **CloudFormation** or **Terraform** | cloudformation/, terraform/ |
| 3 | Attach parameter group & reboot | See IaC documentation |
| 4 | Verify with the SQL in [_Verification_](docs/GUIDE.md#6-verification) | docs/GUIDE.md |

**Need help?**   New Relic DB engineering: db-support@newrelic.com

_Related AWS feature_: **Performance Insights** is a managed alternative; see Appendix in docs/GUIDE.md.
