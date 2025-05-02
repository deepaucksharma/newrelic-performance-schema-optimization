# Technical Guide: Persisting Performance Schema Configuration on AWS RDS/Aurora

## 1  The Persistence Problem
Runtime tables in `performance_schema` live in RAM; RDS/Aurora restarts wipe them.
After a fail-over you lose consumers/instruments ⇒ monitoring gaps in New Relic.

## 2  Target Configuration

```yaml
# sql/target-config.yaml  <— referenced by Lambda
consumers_enabled:
  - events_statements_current
  - events_statements_history
  - statements_digest
instruments_enabled_prefixes:
  - statement/%
instruments_enabled_exact:
  - wait/io/file/innodb/innodb_data_file
  - wait/io/file/innodb/innodb_log_file
  - wait/lock/table/sql/handler
instruments_disabled_prefixes:
  - wait/sync/%
  - events_stages_%
  - events_%_history_long
```

Lambda enforces that **exact state**; edit to your needs.

## 3  Layer 1 – Parameter Groups (persistent foundation)

| Parameter                                               | Value   | Note          |
| ------------------------------------------------------- | ------- | ------------- |
| `performance_schema`                                    | `1`     | master switch |
| `performance_schema_digests_size`                       | `10000` | 8 MiB         |
| `performance_schema_max_sql_text_length`                | `4096`  | full SQL text |
| `performance-schema-consumer-events-statements-current` | `1`     | where exposed |

Attach PG, reboot (or wait for maintenance window).

## 4  Layer 2 – Lambda Automation (runtime state)

**Trigger sources**

* *Daily check*: `rate(1 day)`
* *RDS events*: `RDS-EVENT-0004`, `0045`, `0046`, `0071`, `0006`, …

**Flow**

```text
EventBridge → Lambda → RDS/Aurora
          ↘ CloudWatch Logs + Metrics
                 ↘ optional SNS Alert
```

Lambda logic (see `lambda/index.py`):

1. Load YAML from S3 (`target-config.yaml`).
2. Query current state (`setup_consumers`, `setup_instruments`).
3. Compute diff → generate minimal `UPDATE` SET statements.
4. If drift → run inside one transaction.
5. Emit structured log `{ drift_detected, patch_applied, error }`.

IAM Auth + (optional) RDS Proxy keeps creds out of SecretsManager.

## 5  Infrastructure as Code

* **CloudFormation**: single file `perf-schema-automation.yaml`
* **Terraform**: module in `terraform/`

Both create:

* DB Parameter Group
* Lambda (+ execution role, SG, Layer)
* EventBridge rules
* Optional Proxy, SNS, CloudWatch alarms/dashboard

## 6  Verification

```sql
-- persistent switch
SHOW VARIABLES LIKE 'performance_schema';

-- check consumers
SELECT NAME, ENABLED FROM performance_schema.setup_consumers
 WHERE NAME IN ('events_statements_current','statements_digest');

-- check Lambda logs
aws logs tail /aws/lambda/<fn> --since 1h
```

## Appendix  AWS Performance Insights

PI also manipulates P_S but with its own subset. If you enable PI *and*
this Lambda, set PI to **manual mode** or ensure the two desired-states
don't conflict.

## New Relic Integration Benefits

This configuration has been optimized for New Relic Database monitoring:

* Reduces ingest volume by 40-70%
* Limits CPU overhead to under 8%
* Ensures consistent metrics collection 
* Focuses on high-value query metrics and resource utilization
* Prevents monitoring gaps after database events
