# Architecture Documentation

## Overview

Simple Log Service is a serverless log management system built on AWS, designed for high availability, scalability, and security.

## Architecture Diagram

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS (TLS 1.2+)
       │ AWS SigV4 Auth
       ▼
┌─────────────────────┐
│   API Gateway       │
│   (Regional)        │
└──────┬──────────────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌─────────────┐   ┌─────────────┐
│  Lambda     │   │  Lambda     │
│  Ingest     │   │  Read       │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                ▼
        ┌───────────────┐
        │  DynamoDB     │
        │  (Multi-AZ)   │
        │  + GSI        │
        └───────┬───────┘
                │
                ▼
        ┌───────────────┐
        │  KMS Key      │
        │  (Encryption) │
        └───────────────┘
                │
                ▼
        ┌───────────────┐
        │  CloudWatch   │
        │  Logs/Metrics │
        └───────┬───────┘
                │
                ▼
        ┌───────────────┐
        │  SNS Topic    │
        │  (Alarms)     │
        └───────────────┘
                │
                ▼
        ┌───────────────┐
        │  AWS Config   │
        │  (Compliance) │
        └───────────────┘
```

## Components

### 1. API Gateway
- **Type**: REST API (Regional)
- **Authentication**: AWS SigV4
- **Endpoints**:
  - `POST /logs` - Ingest logs
  - `GET /logs/recent` - Retrieve recent logs
- **Features**:
  - Request throttling (5000 burst, 10000 steady)
  - CloudWatch logging
  - X-Ray tracing
  - CORS enabled

### 2. Lambda Functions

#### Ingest Lambda
- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Concurrency**: Unlimited
- **Function**: Validates and writes logs to DynamoDB

#### Read Lambda
- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Concurrency**: Unlimited
- **Function**: Queries DynamoDB for recent logs (24 hours)

### 3. DynamoDB Table

#### Schema
- **Table Name**: `simple-log-service-{env}-logs`
- **Partition Key**: `service_name` (String)
- **Sort Key**: `timestamp` (Number)
- **Billing**: Provisioned (5 RCU/WCU base, auto-scaling to 100)

#### Global Secondary Index
- **Index Name**: `TimestampIndex`
- **Partition Key**: `log_type` (String)
- **Sort Key**: `timestamp` (Number)
- **Projection**: ALL

#### Features
- Point-in-time recovery (35 days)
- Deletion protection
- KMS encryption at rest
- Auto-scaling (70% utilization target)

### 4. Security

#### Encryption
- **At Rest**: KMS customer-managed key
- **In Transit**: TLS 1.2+
- **Key Rotation**: Enabled (annual)

#### IAM
- **Lambda Execution Role**: Least privilege
- **API Gateway**: AWS SigV4 authentication
- **Temporary Credentials**: Required

#### Compliance
- AWS Config rules monitoring:
  - DynamoDB encryption
  - Lambda encryption
  - CloudWatch log encryption
  - S3 encryption and versioning
- SNS notifications for violations

### 5. Monitoring

#### CloudWatch Metrics
- Lambda invocations, errors, duration
- DynamoDB capacity, throttles
- API Gateway requests, errors
- Custom business metrics

#### Alarms
- Lambda error rate > 5 in 5 minutes
- Lambda duration > 5 seconds
- DynamoDB throttles > 10 in 5 minutes
- API 4xx errors > 50 in 5 minutes
- API 5xx errors > 5 in 5 minutes

#### Dashboard
- Real-time metrics visualization
- Performance trends
- Error tracking

### 6. High Availability

#### Multi-AZ Deployment
- DynamoDB: Automatic multi-AZ replication
- Lambda: Deployed across multiple AZs
- API Gateway: Regional endpoint

#### Disaster Recovery
- RTO: < 1 hour
- RPO: < 5 minutes
- Point-in-time recovery enabled
- Automated backups

## Data Flow

### Log Ingestion
1. Client signs request with AWS SigV4
2. API Gateway validates authentication
3. API Gateway invokes Ingest Lambda
4. Lambda validates log data
5. Lambda writes to DynamoDB
6. Lambda publishes CloudWatch metric
7. Response returned to client

### Log Retrieval
1. Client signs request with AWS SigV4
2. API Gateway validates authentication
3. API Gateway invokes Read Lambda
4. Lambda queries DynamoDB (by service or type)
5. Lambda filters logs (last 24 hours)
6. Lambda publishes CloudWatch metric
7. Logs returned to client

## Scalability

### Horizontal Scaling
- Lambda: Automatic (up to account limits)
- DynamoDB: Auto-scaling (5-100 capacity units)
- API Gateway: Automatic

### Performance Targets
- Ingestion: < 200ms p99
- Retrieval: < 300ms p99
- Throughput: > 1000 req/sec

## Cost Optimization

### Strategies
- Provisioned capacity with auto-scaling
- CloudWatch log retention (7 days)
- Lambda memory optimization (256 MB)
- Efficient DynamoDB queries (GSI usage)

### Estimated Monthly Cost
- **Development**: $15-25
- **Production**: $50-150 (moderate load)

See COST_ESTIMATION.md for detailed breakdown.

## Security Best Practices

1. **Authentication**: AWS SigV4 only
2. **Encryption**: KMS for all data
3. **Least Privilege**: IAM roles
4. **Monitoring**: CloudWatch + Config
5. **Compliance**: Automated checks
6. **Audit**: CloudTrail enabled
7. **Network**: Regional endpoints only

## Future Enhancements

1. **Log Retention**: TTL-based expiration
2. **Search**: OpenSearch integration
3. **Analytics**: Athena queries
4. **Streaming**: Kinesis integration
5. **Multi-Region**: Cross-region replication
