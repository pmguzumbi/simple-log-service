
# Disaster Recovery Documentation

## Overview

This document outlines the disaster recovery (DR) strategy, procedures, and testing protocols for the Simple Log Service. The system is designed for high availability with automated failover and recovery capabilities.

## DR Objectives

### Recovery Time Objective (RTO)
**Target**: < 1 hour

The maximum acceptable time to restore service after a disaster.

**Components**:
- DynamoDB: < 5 minutes (automatic multi-AZ)
- Lambda: < 1 minute (automatic multi-AZ)
- API Gateway: < 1 minute (automatic multi-AZ)
- Manual intervention: < 30 minutes

### Recovery Point Objective (RPO)
**Target**: < 5 minutes

The maximum acceptable data loss measured in time.

**Components**:
- DynamoDB: < 1 second (continuous replication)
- CloudWatch Logs: < 5 minutes (batch upload)
- AWS Config: < 15 minutes (snapshot frequency)

## Architecture Resilience

### Multi-AZ Deployment

**DynamoDB**:
- Automatic replication across 3 availability zones
- Synchronous replication (no data loss)
- Automatic failover (transparent to application)
- No manual intervention required

**Lambda Functions**:
- Deployed across multiple availability zones
- Automatic failover by AWS
- Stateless design (no data loss)
- Cold start < 500ms

**API Gateway**:
- Regional endpoint (multi-AZ by default)
- Automatic failover
- No single point of failure

### Data Protection

**Point-in-Time Recovery (PITR)**:
```
Enabled: Yes
Retention: 35 days
Granularity: Per-second
Recovery Time: 5-30 minutes
```

**Automated Backups**:
```
Frequency: Continuous (PITR)
Retention: 35 days
Type: Incremental
Storage: S3 (encrypted)
```

**AWS Config Snapshots**:
```
Frequency: Every 24 hours
Retention: 7 years (compliance)
Storage: S3 (encrypted, versioned)
```

## Disaster Scenarios

### Scenario 1: Availability Zone Failure

**Impact**: Minimal to none

**Automatic Response**:
1. DynamoDB automatically fails over to healthy AZ
2. Lambda invocations route to healthy AZ
3. API Gateway routes traffic to healthy endpoints
4. No data loss (synchronous replication)

**Recovery Time**: < 1 minute (automatic)

**Manual Actions**: None required

**Verification**:
```bash
# Check DynamoDB status
aws dynamodb describe-table \
  --table-name simple-log-service-dev-logs \
  --query 'Table.TableStatus'

# Check Lambda health
aws lambda get-function \
  --function-name simple-log-service-dev-ingest-log \
  --query 'Configuration.State'

# Test API endpoint
curl -X GET https://your-api-endpoint/logs/recent
```

### Scenario 2: Regional Failure

**Impact**: Service unavailable until recovery

**Current State**: Single region deployment (eu-west-2)

**Recovery Options**:

**Option A: Restore in Same Region** (when available)
```
RTO: 1-2 hours
RPO: < 5 minutes
Steps: Redeploy infrastructure via Terraform
```

**Option B: Deploy to Alternate Region** (future enhancement)
```
RTO: 2-4 hours
RPO: < 5 minutes
Steps: Deploy to us-east-1 or eu-west-1
```

**Manual Actions**:
1. Verify region is unavailable
2. Update Terraform variables for new region
3. Deploy infrastructure: `terraform apply`
4. Restore DynamoDB from backup
5. Update DNS/endpoints
6. Verify functionality

### Scenario 3: DynamoDB Table Corruption

**Impact**: Data integrity issues

**Recovery Options**:

**Option A: Point-in-Time Recovery**
```bash
# Restore to specific timestamp
aws dynamodb restore-table-to-point-in-time \
  --source-table-name simple-log-service-dev-logs \
  --target-table-name simple-log-service-dev-logs-restored \
  --restore-date-time 2026-01-31T10:00:00Z

# Update Lambda environment variables
aws lambda update-function-configuration \
  --function-name simple-log-service-dev-ingest-log \
  --environment Variables={DYNAMODB_TABLE_NAME=simple-log-service-dev-logs-restored}
```

**RTO**: 15-30 minutes
**RPO**: < 1 minute

**Option B: On-Demand Backup Restore**
```bash
# List available backups
aws dynamodb list-backups \
  --table-name simple-log-service-dev-logs

# Restore from backup
aws dynamodb restore-table-from-backup \
  --target-table-name simple-log-service-dev-logs-restored \
  --backup-arn arn:aws:dynamodb:eu-west-2:033667696152:table/simple-log-service-dev-logs/backup/01234567890123-abcdef12
```

**RTO**: 20-40 minutes
**RPO**: Depends on backup age

### Scenario 4: Lambda Function Failure

**Impact**: Service degradation or unavailability

**Automatic Response**:
- Lambda retries failed invocations (up to 2 times)
- CloudWatch alarms trigger SNS notifications
- API Gateway returns 5xx errors

**Manual Actions**:
```bash
# Check Lambda errors
aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --since 1h

# Rollback to previous version
aws lambda update-function-code \
  --function-name simple-log-service-dev-ingest-log \
  --s3-bucket your-deployment-bucket \
  --s3-key lambda/previous-version.zip

# Or redeploy via Terraform
cd terraform
git checkout <previous-commit>
terraform apply
```

**RTO**: 5-15 minutes
**RPO**: 0 (no data loss)

### Scenario 5: API Gateway Failure

**Impact**: Service unavailable

**Automatic Response**:
- AWS automatically fails over within region
- CloudWatch alarms trigger

**Manual Actions**:
```bash
# Check API Gateway status
aws apigateway get-rest-api \
  --rest-api-id <api-id>

# Redeploy API Gateway
cd terraform
terraform taint aws_api_gateway_deployment.main
terraform apply

# Create new deployment
aws apigateway create-deployment \
  --rest-api-id <api-id> \
  --stage-name dev
```

**RTO**: 5-10 minutes
**RPO**: 0 (no data loss)

### Scenario 6: KMS Key Deletion

**Impact**: Cannot decrypt data

**Prevention**:
- 30-day deletion window (scheduled deletion)
- Deletion protection enabled
- CloudWatch alarms on key state changes

**Recovery**:
```bash
# Cancel key deletion (within 30 days)
aws kms cancel-key-deletion \
  --key-id <key-id>

# If key deleted, restore from backup
# Note: This requires redeploying with new key
cd terraform
terraform apply
```

**RTO**: 1-2 hours (if key deleted)
**RPO**: 0 (data preserved, re-encryption needed)

## DR Testing

### Test Schedule

| Test Type | Frequency | Duration | Impact |
|-----------|-----------|----------|--------|
| AZ Failover | Quarterly | 30 min | None (automatic) |
| PITR Restore | Quarterly | 1 hour | None (separate table) |
| Lambda Rollback | Monthly | 15 min | Minimal (dev only) |
| Full DR Drill | Annually | 4 hours | Planned downtime |

### Test Procedures

#### Test 1: Availability Zone Failover (FIS Experiment)

**Objective**: Verify automatic failover when AZ becomes unavailable

**Prerequisites**:
- FIS experiment template created
- IAM role for FIS configured
- CloudWatch alarms enabled

**Procedure**:
```bash
# Create FIS experiment template
aws fis create-experiment-template \
  --cli-input-json file://fis-az-failover.json

# Start experiment
aws fis start-experiment \
  --experiment-template-id <template-id>

# Monitor during experiment
watch -n 5 'aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=simple-log-service-dev-logs \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum'

# Verify no errors
python scripts/test_api.py
```

**FIS Experiment Template** (`fis-az-failover.json`):
```json
{
  "description": "Test AZ failover for Simple Log Service",
  "targets": {
    "dynamodb-table": {
      "resourceType": "aws:dynamodb:table",
      "resourceArns": [
        "arn:aws:dynamodb:eu-west-2:033667696152:table/simple-log-service-dev-logs"
      ],
      "selectionMode": "ALL"
    }
  },
  "actions": {
    "simulate-az-failure": {
      "actionId": "aws:dynamodb:disrupt-connectivity",
      "parameters": {
        "duration": "PT5M",
        "availabilityZoneIdentifiers": ["eu-west-2a"]
      },
      "targets": {
        "Tables": "dynamodb-table"
      }
    }
  },
  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "arn:aws:cloudwatch:eu-west-2:033667696152:alarm:simple-log-service-dev-dynamodb-throttles"
    }
  ],
  "roleArn": "arn:aws:iam::033667696152:role/FISExperimentRole"
}
```

**Expected Results**:
- ✓ No service interruption
- ✓ No data loss
- ✓ Automatic failover to healthy AZ
- ✓ All API tests pass
- ✓ CloudWatch shows no errors

**Success Criteria**:
- API availability: 100.00%
- Error rate: 0.00%
- Data loss: 0 records

#### Test 2: Point-in-Time Recovery

**Objective**: Verify ability to restore data to specific point in time

**Procedure**:
```bash
# 1. Record current state
TIMESTAMP_BEFORE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
aws dynamodb scan \
  --table-name simple-log-service-dev-logs \
  --select COUNT

# 2. Ingest test data
python scripts/test_api.py

# 3. Wait 5 minutes
sleep 300

# 4. Record timestamp for restore
RESTORE_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 5. Ingest more data (to be excluded from restore)
python scripts/test_api.py

# 6. Restore to point in time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name simple-log-service-dev-logs \
  --target-table-name simple-log-service-dev-logs-pitr-test \
  --restore-date-time $RESTORE_TIMESTAMP

# 7. Wait for restore to complete
aws dynamodb wait table-exists \
  --table-name simple-log-service-dev-logs-pitr-test

# 8. Verify data
aws dynamodb scan \
  --table-name simple-log-service-dev-logs-pitr-test \
  --select COUNT

# 9. Cleanup
aws dynamodb delete-table \
  --table-name simple-log-service-dev-logs-pitr-test
```

**Expected Results**:
- ✓ Restore completes in < 30 minutes
- ✓ Data matches state at restore timestamp
- ✓ No data from after restore timestamp

**Success Criteria**:
- Restore time: < 30 minutes
- Data accuracy: 100.00%
- RPO achieved: < 1 minute

#### Test 3: Lambda Function Rollback

**Objective**: Verify ability to rollback Lambda to previous version

**Procedure**:
```bash
# 1. Record current version
CURRENT_VERSION=$(aws lambda get-function \
  --function-name simple-log-service-dev-ingest-log \
  --query 'Configuration.Version' \
  --output text)

# 2. Deploy new version (intentionally broken)
cd lambda/ingest_log
# Introduce error in code
sed -i 's/table.put_item/table.put_item_broken/' index.py
cd ../../terraform
terraform apply -auto-approve

# 3. Verify failure
python ../scripts/test_api.py
# Should fail

# 4. Rollback via Terraform
git checkout HEAD -- ../lambda/ingest_log/index.py
terraform apply -auto-approve

# 5. Verify recovery
python ../scripts/test_api.py
# Should succeed
```

**Expected Results**:
- ✓ Rollback completes in < 5 minutes
- ✓ Service restored to working state
- ✓ All tests pass after rollback

**Success Criteria**:
- Rollback time: < 5 minutes
- Service availability: Restored
- Data loss: 0 records

#### Test 4: Full Disaster Recovery Drill

**Objective**: Simulate complete regional failure and recovery

**Procedure**:
```bash
# 1. Document current state
terraform output > dr-test-outputs-before.txt
aws dynamodb describe-table \
  --table-name simple-log-service-dev-logs > dr-test-table-before.json

# 2. Create on-demand backup
aws dynamodb create-backup \
  --table-name simple-log-service-dev-logs \
  --backup-name dr-test-backup-$(date +%Y%m%d-%H%M%S)

# 3. Destroy infrastructure (simulate regional failure)
cd terraform
terraform destroy -auto-approve

# 4. Wait 5 minutes (simulate detection time)
sleep 300

# 5. Redeploy infrastructure
terraform apply -auto-approve

# 6. Restore data from backup
BACKUP_ARN=$(aws dynamodb list-backups \
  --table-name simple-log-service-dev-logs \
  --query 'BackupSummaries[0].BackupArn' \
  --output text)

aws dynamodb restore-table-from-backup \
  --target-table-name simple-log-service-dev-logs-restored \
  --backup-arn $BACKUP_ARN

# 7. Wait for restore
aws dynamodb wait table-exists \
  --table-name simple-log-service-dev-logs-restored

# 8. Update Lambda to use restored table
aws lambda update-function-configuration \
  --function-name simple-log-service-dev-ingest-log \
  --environment Variables={DYNAMODB_TABLE_NAME=simple-log-service-dev-logs-restored}

aws lambda update-function-configuration \
  --function-name simple-log-service-dev-read-recent \
  --environment Variables={DYNAMODB_TABLE_NAME=simple-log-service-dev-logs-restored}

# 9. Verify functionality
python scripts/test_api.py

# 10. Document recovery time
echo "Recovery completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Expected Results**:
- ✓ Infrastructure redeployed in < 15 minutes
- ✓ Data restored in < 30 minutes
- ✓ Service fully functional
- ✓ All tests pass

**Success Criteria**:
- Total RTO: < 1 hour
- RPO: < 5 minutes
- Service availability: 100.00% after recovery

## Monitoring and Alerting

### CloudWatch Alarms

**Critical Alarms** (immediate action required):
- Lambda error rate > 5 in 5 minutes
- DynamoDB throttling > 10 in 5 minutes
- API Gateway 5xx errors > 5 in 5 minutes
- KMS key state change

**Warning Alarms** (investigation required):
- Lambda duration > 5 seconds
- DynamoDB capacity > 70.00%
- API Gateway 4xx errors > 50 in 5 minutes

### SNS Notifications

All alarms send notifications to:
- Email: Configured in `alarm_email` variable
- SMS: Optional (configure in SNS subscription)
- Slack: Optional (via Lambda integration)

### CloudWatch Dashboard

Monitor real-time metrics:
```
https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#dashboards:name=simple-log-service-dev-dashboard
```

**Key Metrics**:
- Lambda invocations and errors
- DynamoDB capacity utilization
- API Gateway request count and errors
- Custom business metrics

## Runbooks

### Runbook 1: Service Degradation

**Symptoms**:
- Increased latency
- Intermittent errors
- CloudWatch alarms firing

**Investigation**:
```bash
# Check Lambda errors
aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --since 1h | grep ERROR

# Check DynamoDB throttling
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=simple-log-service-dev-logs \
  --start-time $(date -u -d "1 hour ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check API Gateway errors
aws logs tail /aws/apigateway/simple-log-service-dev --since 1h | grep "5XX"
```

**Resolution**:
1. Identify root cause from logs
2. Scale DynamoDB capacity if throttling
3. Rollback Lambda if recent deployment
4. Restart API Gateway deployment if needed

### Runbook 2: Complete Service Outage

**Symptoms**:
- All API requests failing
- Multiple CloudWatch alarms
- No Lambda invocations

**Investigation**:
```bash
# Check AWS service health
aws health describe-events --filter eventTypeCategories=issue

# Check resource status
aws dynamodb describe-table --table-name simple-log-service-dev-logs
aws lambda get-function --function-name simple-log-service-dev-ingest-log
aws apigateway get-rest-api --rest-api-id <api-id>
```

**Resolution**:
1. If regional issue: Wait for AWS resolution or failover to alternate region
2. If configuration issue: Rollback via Terraform
3. If data corruption: Restore from PITR
4. If KMS issue: Verify key status and permissions

### Runbook 3: Data Loss Suspected

**Symptoms**:
- Missing log entries
- Inconsistent query results
- User reports of missing data

**Investigation**:
```bash
# Check DynamoDB table status
aws dynamodb describe-table \
  --table-name simple-log-service-dev-logs \
  --query 'Table.[TableStatus,ItemCount]'

# Check CloudWatch logs for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/simple-log-service-dev-ingest-log \
  --start-time $(date -u -d "24 hours ago" +%s)000 \
  --filter-pattern "ERROR"

# Verify PITR status
aws dynamodb describe-continuous-backups \
  --table-name simple-log-service-dev-logs
```

**Resolution**:
1. Determine time range of data loss
2. Restore from PITR to separate table
3. Compare data between tables
4. Merge missing data if needed
5. Investigate root cause

## Backup Strategy

### Automated Backups

**Point-in-Time Recovery**:
- Enabled by default
- Continuous backups
- 35-day retention
- Per-second granularity

**AWS Config Snapshots**:
- Daily snapshots
- 7-year retention
- Configuration history
- Compliance tracking

### Manual Backups

**On-Demand Backups**:
```bash
# Create backup before major changes
aws dynamodb create-backup \
  --table-name simple-log-service-dev-logs \
  --backup-name pre-deployment-$(date +%Y%m%d-%H%M%S)
```

**Recommended Schedule**:
- Before deployments
- Before schema changes
- Monthly for compliance
- Before DR testing

### Backup Verification

**Monthly Verification**:
```bash
# List recent backups
aws dynamodb list-backups \
  --table-name simple-log-service-dev-logs \
  --time-range-lower-bound $(date -u -d "30 days ago" +%s)

# Test restore (to separate table)
aws dynamodb restore-table-from-backup \
  --target-table-name simple-log-service-dev-logs-verify \
  --backup-arn <backup-arn>

# Verify data integrity
aws dynamodb scan \
  --table-name simple-log-service-dev-logs-verify \
  --select COUNT

# Cleanup
aws dynamodb delete-table \
  --table-name simple-log-service-dev-logs-verify
```

## Contact Information

### Escalation Path

**Level 1: On-Call Engineer**
- Response time: 15 minutes
- Authority: Restart services, scale resources

**Level 2: Senior Engineer**
- Response time: 30 minutes
- Authority: Rollback deployments, restore from backup

**Level 3: Engineering Manager**
- Response time: 1 hour
- Authority: Regional failover, major architecture changes

### Communication Channels

**During Incident**:
- Slack: #simple-log-service-incidents
- Email: ops-team@example.com
- Phone: On-call rotation

**Post-Incident**:
- Incident report: Within 24 hours
- Root cause analysis: Within 1 week
- Remediation plan: Within 2 weeks

## Continuous Improvement

### Post-Incident Review

After each incident or DR test:
1. Document timeline of events
2. Identify root cause
3. Assess RTO/RPO achievement
4. Update runbooks
5. Implement preventive measures

### Metrics Tracking

**Monthly Review**:
- Actual RTO vs. target
- Actual RPO vs. target
- Number of incidents
- Mean time to recovery (MTTR)
- Backup success rate

### Annual Review

- Update DR strategy
- Review and update RTO/RPO targets
- Assess multi-region requirements
- Update contact information
- Review and update runbooks

## Compliance

### Audit Trail

All DR activities logged in:
- CloudTrail: API calls
- CloudWatch Logs: Application logs
- AWS Config: Configuration changes
- S3: Backup metadata

### Retention Requirements

- CloudTrail logs: 90 days
- CloudWatch logs: 7 days (dev), 30 days (prod)
- AWS Config: 7 years
- Backups: 35 days (PITR), indefinite (on-demand)

### Documentation

- DR plan: Reviewed quarterly
- Runbooks: Updated after each incident
- Test results: Retained for 1 year
- Incident reports: Retained for 3 years
