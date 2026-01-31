# Cost Estimation

## Overview

This document provides detailed cost estimates for running the Simple Log Service on AWS. Costs are calculated for different usage tiers and environments.

## Pricing Assumptions (January 2026)

### AWS Service Pricing (eu-west-2)

| Service | Unit | Price |
|---------|------|-------|
| DynamoDB Write | Per WCU-hour | $0.00065 |
| DynamoDB Read | Per RCU-hour | $0.00013 |
| DynamoDB Storage | Per GB-month | $0.25 |
| Lambda Requests | Per 1M requests | $0.20 |
| Lambda Duration | Per GB-second | $0.0000166667 |
| API Gateway | Per 1M requests | $3.50 |
| CloudWatch Logs | Per GB ingested | $0.50 |
| CloudWatch Logs | Per GB stored | $0.03 |
| KMS | Per 10,000 requests | $0.03 |
| KMS | Per key per month | $1.00 |
| SNS | Per 1M requests | $0.50 |
| AWS Config | Per rule per month | $2.00 |
| AWS Config | Per item recorded | $0.003 |
| S3 Standard | Per GB-month | $0.023 |
| Data Transfer Out | Per GB | $0.09 |

## Cost Breakdown by Component

### 1. DynamoDB

#### Base Configuration (5 RCU/WCU)
```
Write Capacity: 5 WCU × 730 hours × $0.00065 = $2.37
Read Capacity: 5 RCU × 730 hours × $0.00013 = $0.47
GSI Write: 5 WCU × 730 hours × $0.00065 = $2.37
GSI Read: 5 RCU × 730 hours × $0.00013 = $0.47
Storage: 1 GB × $0.25 = $0.25
Point-in-Time Recovery: 1 GB × $0.20 = $0.20

Monthly Total: $6.13
```

#### Moderate Load (Average 20 RCU/WCU)
```
Write Capacity: 20 WCU × 730 hours × $0.00065 = $9.49
Read Capacity: 20 RCU × 730 hours × $0.00013 = $1.90
GSI Write: 20 WCU × 730 hours × $0.00065 = $9.49
GSI Read: 20 RCU × 730 hours × $0.00013 = $1.90
Storage: 10 GB × $0.25 = $2.50
Point-in-Time Recovery: 10 GB × $0.20 = $2.00

Monthly Total: $27.28
```

#### High Load (Average 50 RCU/WCU)
```
Write Capacity: 50 WCU × 730 hours × $0.00065 = $23.73
Read Capacity: 50 RCU × 730 hours × $0.00013 = $4.75
GSI Write: 50 WCU × 730 hours × $0.00065 = $23.73
GSI Read: 50 RCU × 730 hours × $0.00013 = $4.75
Storage: 50 GB × $0.25 = $12.50
Point-in-Time Recovery: 50 GB × $0.20 = $10.00

Monthly Total: $79.46
```

### 2. Lambda Functions

#### Low Volume (100K requests/month)
```
Requests: 100,000 × $0.20 / 1,000,000 = $0.02
Duration (256 MB, 100ms avg):
  - Compute: 100,000 × 0.1s × 0.25 GB × $0.0000166667 = $0.04

Monthly Total: $0.06
```

#### Moderate Volume (1M requests/month)
```
Requests: 1,000,000 × $0.20 / 1,000,000 = $0.20
Duration (256 MB, 100ms avg):
  - Compute: 1,000,000 × 0.1s × 0.25 GB × $0.0000166667 = $0.42

Monthly Total: $0.62
```

#### High Volume (10M requests/month)
```
Requests: 10,000,000 × $0.20 / 1,000,000 = $2.00
Duration (256 MB, 100ms avg):
  - Compute: 10,000,000 × 0.1s × 0.25 GB × $0.0000166667 = $4.17

Monthly Total: $6.17
```

### 3. API Gateway

#### Low Volume (100K requests/month)
```
Requests: 100,000 × $3.50 / 1,000,000 = $0.35

Monthly Total: $0.35
```

#### Moderate Volume (1M requests/month)
```
Requests: 1,000,000 × $3.50 / 1,000,000 = $3.50

Monthly Total: $3.50
```

#### High Volume (10M requests/month)
```
Requests: 10,000,000 × $3.50 / 1,000,000 = $35.00

Monthly Total: $35.00
```

### 4. CloudWatch

#### Low Volume
```
Logs Ingested: 1 GB × $0.50 = $0.50
Logs Stored: 0.5 GB × $0.03 = $0.02
Metrics: 10 custom metrics × $0.30 = $3.00
Alarms: 6 alarms × $0.10 = $0.60
Dashboard: 1 dashboard × $3.00 = $3.00

Monthly Total: $7.12
```

#### Moderate Volume
```
Logs Ingested: 5 GB × $0.50 = $2.50
Logs Stored: 2 GB × $0.03 = $0.06
Metrics: 20 custom metrics × $0.30 = $6.00
Alarms: 6 alarms × $0.10 = $0.60
Dashboard: 1 dashboard × $3.00 = $3.00

Monthly Total: $12.16
```

#### High Volume
```
Logs Ingested: 20 GB × $0.50 = $10.00
Logs Stored: 10 GB × $0.03 = $0.30
Metrics: 50 custom metrics × $0.30 = $15.00
Alarms: 10 alarms × $0.10 = $1.00
Dashboard: 1 dashboard × $3.00 = $3.00

Monthly Total: $29.30
```

### 5. KMS

```
Key: 1 key × $1.00 = $1.00
Requests (100K/month): 100,000 × $0.03 / 10,000 = $0.30

Monthly Total: $1.30
```

### 6. SNS

```
Notifications: 1,000 × $0.50 / 1,000,000 = $0.00
Email Delivery: Free

Monthly Total: $0.00 (negligible)
```

### 7. AWS Config (Optional)

```
Rules: 5 rules × $2.00 = $10.00
Configuration Items: 10,000 × $0.003 = $30.00

Monthly Total: $40.00
```

### 8. S3 (Config Bucket)

```
Storage: 1 GB × $0.023 = $0.02
Requests: Negligible

Monthly Total: $0.02
```

### 9. X-Ray (Optional)

```
Traces Recorded: 100,000 × $5.00 / 1,000,000 = $0.50
Traces Retrieved: 10,000 × $0.50 / 1,000,000 = $0.01

Monthly Total: $0.51
```

## Total Cost Estimates

### Development Environment (Low Volume)

| Component | Monthly Cost |
|-----------|--------------|
| DynamoDB | $6.13 |
| Lambda | $0.06 |
| API Gateway | $0.35 |
| CloudWatch | $7.12 |
| KMS | $1.30 |
| SNS | $0.00 |
| **Total** | **$14.96** |

**With AWS Config**: $54.98

### Staging Environment (Moderate Volume)

| Component | Monthly Cost |
|-----------|--------------|
| DynamoDB | $27.28 |
| Lambda | $0.62 |
| API Gateway | $3.50 |
| CloudWatch | $12.16 |
| KMS | $1.30 |
| SNS | $0.00 |
| AWS Config | $40.02 |
| **Total** | **$84.88** |

### Production Environment (High Volume)

| Component | Monthly Cost |
|-----------|--------------|
| DynamoDB | $79.46 |
| Lambda | $6.17 |
| API Gateway | $35.00 |
| CloudWatch | $29.30 |
| KMS | $1.30 |
| SNS | $0.00 |
| AWS Config | $40.02 |
| X-Ray | $0.51 |
| **Total** | **$191.76** |

## Cost Optimization Strategies

### 1. DynamoDB Optimization

**Strategy**: Use on-demand billing for unpredictable workloads
```
Savings: Up to 30% for variable traffic
Implementation: Change billing_mode to "PAY_PER_REQUEST"
```

**Strategy**: Implement TTL for automatic data expiration
```
Savings: Reduce storage costs by 50-70%
Implementation: Add TTL attribute to items
```

**Strategy**: Use DynamoDB Standard-IA for infrequently accessed data
```
Savings: 60% on storage costs
Implementation: Enable table class = STANDARD_INFREQUENT_ACCESS
```

### 2. Lambda Optimization

**Strategy**: Right-size memory allocation
```
Current: 256 MB
Optimized: 128 MB (if sufficient)
Savings: 50% on compute costs
```

**Strategy**: Reduce cold starts with provisioned concurrency
```
Cost: $0.015 per GB-hour
Benefit: Faster response times
Use Case: Production only
```

### 3. CloudWatch Optimization

**Strategy**: Reduce log retention
```
Current: 7 days
Optimized: 3 days for dev
Savings: 40% on storage
```

**Strategy**: Use metric filters instead of custom metrics
```
Savings: $0.30 per metric per month
Implementation: Extract metrics from logs
```

### 4. API Gateway Optimization

**Strategy**: Use HTTP API instead of REST API
```
Savings: 70% on request costs
Limitation: Fewer features
```

**Strategy**: Enable caching
```
Cost: $0.02 per GB-hour
Benefit: Reduced Lambda invocations
```

### 5. AWS Config Optimization

**Strategy**: Disable in development
```
Savings: $40/month per environment
Risk: No compliance monitoring
```

**Strategy**: Reduce recording frequency
```
Savings: 50% on configuration items
Implementation: Record only on change
```

## Cost Monitoring

### Set Up Budget Alerts

```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget '{
    "BudgetName": "SimpleLogServiceBudget",
    "BudgetLimit": {
      "Amount": "100",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

### CloudWatch Cost Anomaly Detection

Enable AWS Cost Anomaly Detection:
1. Navigate to AWS Cost Management
2. Enable Cost Anomaly Detection
3. Set threshold: $10 increase
4. Configure SNS notifications

### Daily Cost Reports

```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

## Cost Allocation Tags

Apply tags for cost tracking:
```hcl
default_tags {
  tags = {
    Project     = "SimpleLogService"
    Environment = var.environment
    CostCenter  = "Engineering"
    Owner       = "DevOps"
  }
}
```

## Reserved Capacity (Production)

### DynamoDB Reserved Capacity

**Commitment**: 1 year
**Savings**: 53% compared to on-demand
**Minimum**: 100 WCU/RCU

```
Standard: 100 WCU × 730 hours × $0.00065 = $47.45/month
Reserved: 100 WCU × 730 hours × $0.00031 = $22.63/month
Savings: $24.82/month ($297.84/year)
```

## Free Tier Benefits (First 12 Months)

- **Lambda**: 1M requests + 400,000 GB-seconds/month
- **DynamoDB**: 25 GB storage + 25 WCU + 25 RCU
- **API Gateway**: 1M requests/month
- **CloudWatch**: 10 custom metrics + 10 alarms
- **KMS**: 20,000 requests/month

**Estimated Free Tier Savings**: $15-20/month

## Annual Cost Projection

### Development (with Free Tier)
```
Monthly: $0-5 (first 12 months)
Monthly: $15 (after 12 months)
Annual: $30-60 (first year)
Annual: $180 (subsequent years)
```

### Production (High Volume)
```
Monthly: $192
Annual: $2,304
With Reserved Capacity: $1,800/year
Savings: $504/year (21.88%)
```

## Cost Comparison

### vs. Self-Hosted Solution

| Component | AWS Serverless | Self-Hosted EC2 |
|-----------|----------------|-----------------|
| Compute | $6.17 | $50.00 |
| Storage | $79.46 | $30.00 |
| Monitoring | $29.30 | $0.00 |
| Backup | Included | $10.00 |
| **Total** | **$191.76** | **$90.00** |

**Note**: Self-hosted requires:
- Operational overhead
- Maintenance time
- Security patching
- Scaling management

**True Cost**: Self-hosted TCO is typically 2-3x higher when including operational costs.

## Conclusion

**Recommended Configuration**:
- **Development**: $15-25/month (without Config)
- **Staging**: $45-65/month (with Config)
- **Production**: $150-200/month (with Config + optimization)

**Cost Control Measures**:
1. Enable auto-scaling
2. Implement TTL for old logs
3. Use appropriate log retention
4. Monitor with budget alerts
5. Review costs monthly
6. Optimize based on usage patterns
