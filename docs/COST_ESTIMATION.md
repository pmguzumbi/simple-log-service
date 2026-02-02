Simple Log Service - Cost Estimation & Optimization

Version: 2.0  
Last Updated: 2026-02-02  
Status: Production

Table of Contents
Overview
Monthly Cost Breakdown
Cost by Service
Usage Scenarios
Cost Optimization Strategies
Cost Monitoring
Budget Alerts

Overview

Simple Log Service is designed for cost efficiency using serverless, pay-per-use AWS services. This document provides detailed cost estimates and optimization strategies.

Pricing Region: us-east-1 (N. Virginia)  
Pricing Date: February 2026  
Currency: USD

Monthly Cost Breakdown

Base Infrastructure (Fixed Costs)

| Service | Component | Monthly Cost |
|---------|-----------|--------------|
| KMS | Customer-managed key | $1.00 |
| KMS | API requests (10K/month) | $0.03 |
| CloudWatch | Log storage (1 GB) | $0.50 |
| CloudWatch | Metrics (10 custom) | $0.30 |
| CloudWatch | Alarms (3 alarms) | $0.30 |
| Subtotal | Fixed Costs | $2.13 |

Variable Costs (Usage-Based)

Scenario: Low Volume (10K logs/day)

| Service | Usage | Unit Cost | Monthly Cost |
|---------|-------|-----------|--------------|
| API Gateway | 300K requests | $3.50/million | $1.05 |
| Lambda (Ingest) | 300K invocations | $0.20/million | $0.06 |
| Lambda (Ingest) | 7.5M GB-seconds | $0.0000166667/GB-sec | $0.13 |
| Lambda (Read) | 100K invocations | $0.20/million | $0.02 |
| Lambda (Read) | 2.5M GB-seconds | $0.0000166667/GB-sec | $0.04 |
| DynamoDB | 300K writes | $1.25/million | $0.38 |
| DynamoDB | 100K reads | $0.25/million | $0.03 |
| DynamoDB | 1 GB storage | $0.25/GB | $0.25 |
| Subtotal | Variable Costs | | $1.96 |
| Total | Low Volume | | $4.09/month |

Scenario: Medium Volume (100K logs/day)

| Service | Usage | Unit Cost | Monthly Cost |
|---------|-------|-----------|--------------|
| API Gateway | 3M requests | $3.50/million | $10.50 |
| Lambda (Ingest) | 3M invocations | $0.20/million | $0.60 |
| Lambda (Ingest) | 75M GB-seconds | $0.0000166667/GB-sec | $1.25 |
| Lambda (Read) | 1M invocations | $0.20/million | $0.20 |
| Lambda (Read) | 25M GB-seconds | $0.0000166667/GB-sec | $0.42 |
| DynamoDB | 3M writes | $1.25/million | $3.75 |
| DynamoDB | 1M reads | $0.25/million | $0.25 |
| DynamoDB | 10 GB storage | $0.25/GB | $2.50 |
| Subtotal | Variable Costs | | $19.47 |
| Total | Medium Volume | | $21.60/month |

Scenario: High Volume (1M logs/day)

| Service | Usage | Unit Cost | Monthly Cost |
|---------|-------|-----------|--------------|
| API Gateway | 30M requests | $3.50/million | $105.00 |
| Lambda (Ingest) | 30M invocations | $0.20/million | $6.00 |
| Lambda (Ingest) | 750M GB-seconds | $0.0000166667/GB-sec | $12.50 |
| Lambda (Read) | 10M invocations | $0.20/million | $2.00 |
| Lambda (Read) | 250M GB-seconds | $0.0000166667/GB-sec | $4.17 |
| DynamoDB | 30M writes | $1.25/million | $37.50 |
| DynamoDB | 10M reads | $0.25/million | $2.50 |
| DynamoDB | 100 GB storage | $0.25/GB | $25.00 |
| Subtotal | Variable Costs | | $194.67 |
| Total | High Volume | | $196.80/month |

Cost by Service

API Gateway

Pricing Model: Pay-per-request  
Unit Cost: $3.50 per million requests

Cost Breakdown:
• REST API requests: $3.50/million
• Data transfer out: $0.09/GB (first 10 TB)
• CloudWatch logs: Included in CloudWatch costs

Optimization:
• Enable caching for read-heavy workloads ($0.02/hour for 0.5 GB cache)
• Use regional endpoints (lower cost than edge-optimized)
• Implement request throttling to prevent abuse

Lambda

Pricing Model: Pay-per-invocation + compute time  
Unit Costs:
• Invocations: $0.20 per million
• Compute: $0.0000166667 per GB-second

Memory Configuration:
• Ingest Lambda: 256 MB
• Read Lambda: 256 MB

Average Duration:
• Ingest: 50ms (warm), 200ms (cold)
• Read: 100ms (warm), 250ms (cold)

Cost Calculation Example (Ingest):

Optimization:
• Use provisioned concurrency for predictable workloads ($0.0000041667/GB-second)
• Optimize memory allocation (256 MB is cost-effective)
• Reduce cold starts with Lambda SnapStart (Java only)

DynamoDB

Pricing Model: On-demand (pay-per-request)  
Unit Costs:
• Write requests: $1.25 per million
• Read requests: $0.25 per million
• Storage: $0.25 per GB-month

Cost Breakdown:
• 1 write request unit (WRU) = 1 KB
• 1 read request unit (RRU) = 4 KB
• Point-in-time recovery: 20% of storage cost
• Backups: $0.10 per GB-month

Optimization:
• Use on-demand for unpredictable workloads
• Switch to provisioned capacity for steady workloads (50% savings)
• Enable auto-scaling for provisioned capacity
• Archive old logs to S3 ($0.023/GB-month)

KMS

Pricing Model: Fixed + pay-per-request  
Unit Costs:
• Customer-managed key: $1.00/month
• API requests: $0.03 per 10,000 requests

Cost Breakdown:
• Key storage: $1.00/month
• Encrypt/decrypt operations: $0.03/10K
• Key rotation: Included

Optimization:
• Use AWS-managed keys for non-sensitive data (free)
• Batch encrypt/decrypt operations
• Cache decrypted data in Lambda (within security policy)

CloudWatch

Pricing Model: Pay-per-use  
Unit Costs:
• Log ingestion: $0.50 per GB
• Log storage: $0.03 per GB-month
• Metrics: $0.30 per custom metric
• Alarms: $0.10 per alarm

Cost Breakdown:
• Lambda logs: ~1 GB/month (low volume)
• API Gateway logs: ~0.5 GB/month (low volume)
• Custom metrics: 10 metrics × $0.30 = $3.00
• Alarms: 3 alarms × $0.10 = $0.30

Optimization:
• Set log retention to 7 days (vs. indefinite)
• Use log sampling for high-volume logs
• Aggregate metrics to reduce custom metric count
• Use CloudWatch Logs Insights instead of exporting to S3

Usage Scenarios

Scenario 1: Development Environment

Usage:
• 1K logs/day (30K/month)
• Minimal read operations
• 7-day log retention

Monthly Cost: ~$2.50

Breakdown:
• Fixed costs: $2.13
• API Gateway: $0.11
• Lambda: $0.05
• DynamoDB: $0.15
• CloudWatch: $0.06

Scenario 2: Small Production (Startup)

Usage:
• 50K logs/day (1.5M/month)
• Moderate read operations (500K/month)
• 7-day log retention

Monthly Cost: ~$10.50

Breakdown:
• Fixed costs: $2.13
• API Gateway: $5.25
• Lambda: $0.75
• DynamoDB: $2.00
• CloudWatch: $0.37

Scenario 3: Medium Production (SMB)

Usage:
• 100K logs/day (3M/month)
• High read operations (1M/month)
• 7-day log retention

Monthly Cost: ~$21.60

Breakdown:
• Fixed costs: $2.13
• API Gateway: $10.50
• Lambda: $1.47
• DynamoDB: $6.25
• CloudWatch: $1.25

Scenario 4: Large Production (Enterprise)

Usage:
• 1M logs/day (30M/month)
• Very high read operations (10M/month)
• 7-day log retention

Monthly Cost: ~$196.80

Breakdown:
• Fixed costs: $2.13
• API Gateway: $105.00
• Lambda: $24.67
• DynamoDB: $65.00
• CloudWatch: $0.00 (within free tier for logs)

Cost Optimization Strategies
DynamoDB Optimization

Switch to Provisioned Capacity (High Volume):
• Provisioned: $0.00065/WCU-hour, $0.00013/RCU-hour
• On-demand: $1.25/million writes, $0.25/million reads
• Savings: ~50% for steady workloads

Example (1M logs/day):
• On-demand: $37.50/month (writes)
• Provisioned: 350 WCU × $0.00065 × 730 hours = $16.61/month
• Savings: $20.89/month (56%)

Implementation:

API Gateway Caching

Enable Response Caching (Read-Heavy):
• Cache size: 0.5 GB
• Cost: $0.02/hour = $14.60/month
• Savings: Reduce Lambda invocations by 80%

Example (1M reads/day):
• Without cache: $2.00 (Lambda) + $2.50 (DynamoDB) = $4.50
• With cache: $0.40 (Lambda) + $0.50 (DynamoDB) + $14.60 (cache) = $15.50
• Net cost increase: $11.00 (not cost-effective for low volume)

Recommendation: Only enable for > 10M reads/month

Log Archival to S3

Archive Old Logs (> 30 days):
• DynamoDB: $0.25/GB-month
• S3 Standard: $0.023/GB-month
• Savings: 90.8%

Implementation:
• Use DynamoDB S
