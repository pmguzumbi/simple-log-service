
# Simple Log Service - Architecture Documentation

**Version:** 2.0  
**Last Updated:** 2026-02-02  
**Status:** Production

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Security Architecture](#security-architecture)
6. [Network Architecture](#network-architecture)
7. [Scalability & Performance](#scalability--performance)
8. [Disaster Recovery](#disaster-recovery)
9. [Design Decisions](#design-decisions)

---

## Overview

Simple Log Service is a serverless, event-driven logging platform built on AWS infrastructure. The architecture follows AWS Well-Architected Framework principles with emphasis on security, reliability, and operational excellence.

**Architecture Principles:**
- **Serverless-First**: No server management, automatic scaling
- **Security by Design**: Encryption, IAM, least privilege
- **Infrastructure as Code**: 100% Terraform-managed
- **Event-Driven**: Asynchronous processing
- **Cost-Optimized**: Pay-per-use pricing model

---

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
│  (Applications, Services, Monitoring Tools)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTPS + AWS SigV4
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                    API Gateway (REST)                            │
│  - IAM Authorization                                             │
│  - Request Validation                                            │
│  - CloudWatch Logging                                            │
│  - Throttling & Rate Limiting                                    │
└────────────┬───────────────────────────┬────────────────────────┘
             │                           │
             │ POST /logs                │ GET /logs/recent
             │                           │
┌────────────▼──────────┐    ┌──────────▼─────────────┐
│   Ingest Lambda       │    │   Read Recent Lambda   │
│   - Validation        │    │   - Query DynamoDB     │
│   - Enrichment        │    │   - Filter & Sort      │
│   - Write to DynamoDB │    │   - Format Response    │
└────────────┬──────────┘    └──────────┬─────────────┘
             │                           │
             │                           │
             └───────────┬───────────────┘
                         │
                         │ KMS Encrypted
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                      DynamoDB Table                              │
│  - Partition Key: service_name                                   │
│  - Sort Key: timestamp                                           │
│  - KMS Encryption                                                │
│  - Point-in-Time Recovery                                        │
│  - Deletion Protection                                           │
└──────────────────────────────────────────────────────────────────┘
                         │
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                    Monitoring Layer                              │
│  - CloudWatch Metrics                                            │
│  - CloudWatch Alarms                                             │
│  - SNS Notifications                                             │
│  - AWS Config Rules                                              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. API Gateway

**Type:** REST API  
**Region:** us-east-1  
**Authorization:** AWS_IAM

**Endpoints:**
- `POST /logs` - Log ingestion endpoint
- `GET /logs/recent` - Log retrieval endpoint

**Features:**
- Request/response validation
- CloudWatch access logging (7-day retention)
- Request throttling (10,000 requests/second)
- CORS disabled (internal use only)
- Stage: `prod`

**Integration:**
- Lambda proxy integration
- Asynchronous invocation
- Automatic retry on failure

---

### 2. Lambda Functions

#### Ingest Lambda

**Function Name:** `simple-log-service-ingest-prod`  
**Runtime:** Python 3.12  
**Memory:** 256 MB  
**Timeout:** 30 seconds  
**Concurrency:** 100 (reserved)

**Responsibilities:**
- Validate incoming log payload
- Generate unique log ID (UUID v4)
- Add timestamp if not provided
- Enrich with metadata
- Write to DynamoDB
- Return success/error response

**Environment Variables:**
- `DYNAMODB_TABLE_NAME`: Target table name
- `LOG_LEVEL`: INFO

**IAM Permissions:**
- `dynamodb:PutItem` on logs table
- `kms:Decrypt` on KMS key
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

---

#### Read Recent Lambda

**Function Name:** `simple-log-service-read-recent-prod`  
**Runtime:** Python 3.12  
**Memory:** 256 MB  
**Timeout:** 30 seconds  
**Concurrency:** 100 (reserved)

**Responsibilities:**
- Parse query parameters
- Query/scan DynamoDB
- Filter by service_name (if provided)
- Sort by timestamp (descending)
- Limit results (default: 100, max: 1000)
- Format and return response

**Environment Variables:**
- `DYNAMODB_TABLE_NAME`: Target table name
- `LOG_LEVEL`: INFO

**IAM Permissions:**
- `dynamodb:Query`, `dynamodb:Scan` on logs table
- `kms:Decrypt` on KMS key
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

---

### 3. DynamoDB Table

**Table Name:** `simple-log-service-logs-prod`  
**Billing Mode:** On-Demand (Pay-per-request)  
**Region:** us-east-1

**Schema:**
- **Partition Key:** `service_name` (String)
- **Sort Key:** `timestamp` (String, ISO 8601 format)

**Attributes:**
- `log_id` (String) - UUID v4
- `log_type` (String) - application, system, audit, etc.
- `level` (String) - INFO, WARN, ERROR, DEBUG
- `message` (String) - Log message content
- `metadata` (Map) - Optional additional data

**Features:**
- KMS encryption with customer-managed key
- Point-in-time recovery (35-day retention)
- Deletion protection enabled
- CloudWatch contributor insights enabled
- Automatic scaling (on-demand)

**Access Patterns:**
1. Query by service_name + timestamp range
2. Scan all recent logs (last 24 hours)
3. Query by service_name + level filter

---

### 4. KMS Encryption

**Key Alias:** `alias/simple-log-service-prod`  
**Key Type:** Symmetric (AES-256)  
**Key Rotation:** Enabled (annual)

**Usage:**
- DynamoDB table encryption
- CloudWatch log encryption
- Lambda environment variable encryption

**Key Policy:**
- Root account full access
- Lambda execution roles: Decrypt only
- DynamoDB service: Encrypt/Decrypt

---

### 5. IAM Roles

#### Ingest Role

**Role Name:** `simple-log-service-ingest-prod`  
**External ID:** `simple-log-service-ingest-prod`  
**Trust Policy:** Allows assumption by authenticated principals

**Permissions:**
- `dynamodb:PutItem` on logs table
- `execute-api:Invoke` on POST /logs endpoint
- `kms:Decrypt` on KMS key

---

#### Read Role

**Role Name:** `simple-log-service-read-prod`  
**External ID:** `simple-log-service-read-prod`  
**Trust Policy:** Allows assumption by authenticated principals

**Permissions:**
- `dynamodb:Query`, `dynamodb:Scan` on logs table
- `execute-api:Invoke` on GET /logs/recent endpoint
- `kms:Decrypt` on KMS key

---

#### Full Access Role

**Role Name:** `simple-log-service-full-access-prod`  
**External ID:** `simple-log-service-full-prod`  
**Trust Policy:** Allows assumption by authenticated principals

**Permissions:**
- All DynamoDB operations on logs table
- All API Gateway operations
- KMS Encrypt/Decrypt

---

### 6. CloudWatch Monitoring

**Log Groups:**
- `/aws/lambda/simple-log-service-ingest-prod` (7-day retention)
- `/aws/lambda/simple-log-service-read-recent-prod` (7-day retention)
- `/aws/apigateway/simple-log-service-prod` (7-day retention)

**Alarms:**
- Lambda error rate > 5% (5-minute period)
- DynamoDB throttled requests > 10 (1-minute period)
- API Gateway 5xx errors > 10 (5-minute period)

**Metrics:**
- Lambda invocations, duration, errors
- DynamoDB consumed capacity, throttles
- API Gateway request count, latency, errors

---

## Data Flow

### Ingest Flow (POST /logs)

```
1. Client → API Gateway
   - AWS SigV4 signed request
   - JSON payload with log data

2. API Gateway → Ingest Lambda
   - IAM authorization check
   - Request validation
   - Lambda proxy integration

3. Ingest Lambda Processing
   - Validate required fields
   - Generate log_id (UUID v4)
   - Add/validate timestamp
   - Enrich with metadata

4. Ingest Lambda → DynamoDB
   - PutItem operation
   - KMS encryption
   - Conditional write (idempotency)

5. DynamoDB → Ingest Lambda
   - Success/failure response
   - Consumed capacity units

6. Ingest Lambda → API Gateway
   - HTTP 201 (success) or 400/500 (error)
   - Response body with log_id

7. API Gateway → Client
   - Final response
   - CloudWatch logging
```

---

### Read Flow (GET /logs/recent)

```
1. Client → API Gateway
   - AWS SigV4 signed request
   - Query parameters (service_name, limit)

2. API Gateway → Read Lambda
   - IAM authorization check
   - Query parameter validation
   - Lambda proxy integration

3. Read Lambda Processing
   - Parse query parameters
   - Build DynamoDB query/scan
   - Apply filters and limits

4. Read Lambda → DynamoDB
   - Query (if service_name provided)
   - Scan (if no service_name)
   - KMS decryption

5. DynamoDB → Read Lambda
   - Log items
   - Consumed capacity units

6. Read Lambda Processing
   - Sort by timestamp (descending)
   - Format response
   - Apply limit

7. Read Lambda → API Gateway
   - HTTP 200 (success) or 400/500 (error)
   - Response body with logs array

8. API Gateway → Client
   - Final response
   - CloudWatch logging
```

---

## Security Architecture

### Defense in Depth

**Layer 1: Network**
- HTTPS only (TLS 1.2+)
- No public endpoints (API Gateway regional)
- VPC endpoints (optional for enhanced security)

**Layer 2: Authentication**
- AWS SigV4 request signing
- IAM role assumption with external IDs
- Temporary credentials (15-minute sessions)

**Layer 3: Authorization**
- IAM policies (least privilege)
- Resource-based policies
- API Gateway IAM authorizer

**Layer 4: Encryption**
- In-transit: TLS 1.2+
- At-rest: KMS customer-managed keys
- Key rotation: Annual

**Layer 5: Monitoring**
- CloudWatch logs (encrypted)
- CloudTrail audit logs
- AWS Config compliance checks
- SNS notifications for violations

---

### Threat Model

**Threats Mitigated:**
- ✅ Unauthorized access (IAM + external IDs)
- ✅ Data interception (TLS encryption)
- ✅ Data tampering (request signing)
- ✅ Data exposure (KMS encryption)
- ✅ Privilege escalation (least privilege policies)
- ✅ Denial of service (throttling + rate limiting)

**Residual Risks:**
- ⚠️ Compromised AWS credentials (mitigated by MFA + rotation)
- ⚠️ Insider threats (mitigated by CloudTrail + monitoring)
- ⚠️ DDoS attacks (mitigated by AWS Shield + throttling)

---

## Network Architecture

### Regional Deployment

**Primary Region:** us-east-1 (N. Virginia)

**Availability:**
- Multi-AZ by default (DynamoDB, Lambda)
- Regional API Gateway endpoint
- Cross-AZ replication (DynamoDB)

**Connectivity:**
- Public internet (HTTPS)
- Optional: VPC endpoints for private connectivity
- Optional: AWS PrivateLink for on-premises access

---

## Scalability & Performance

### Horizontal Scaling

**API Gateway:**
- Automatic scaling (10,000 requests/second default)
- Burst capacity: 5,000 requests
- Regional endpoint (low latency)

**Lambda:**
- Concurrent executions: 100 (reserved)
- Automatic scaling up to account limit (1,000)
- Cold start: ~200ms (Python 3.12)
- Warm execution: ~10-50ms

**DynamoDB:**
- On-demand capacity mode (automatic scaling)
- Unlimited throughput (within account limits)
- Adaptive capacity for hot partitions
- Global secondary indexes (optional for future)

---

### Performance Characteristics

**Latency:**
- API Gateway: ~10-20ms
- Lambda (warm): ~10-50ms
- DynamoDB: ~5-10ms (single-digit millisecond)
- **Total (P50):** ~50-100ms
- **Total (P99):** ~200-500ms

**Throughput:**
- Ingest: 1,000+ logs/second
- Read: 500+ queries/second
- Burst: 5,000 requests/second

---

## Disaster Recovery

### Backup Strategy

**DynamoDB:**
- Point-in-time recovery (35 days)
- Continuous backups
- On-demand backups (manual)
- Cross-region replication (optional)

**Lambda:**
- Code stored in S3 (versioned)
- Terraform state backup (S3 + versioning)
- Infrastructure as Code (recreate anytime)

**Configuration:**
- Terraform state in S3 (versioned)
- Git repository (version control)
- Automated backups (GitHub)

---

### Recovery Objectives

**RTO (Recovery Time Objective):** 1 hour
- Redeploy infrastructure via Terraform
- Restore DynamoDB from point-in-time recovery

**RPO (Recovery Point Objective):** 5 minutes
- DynamoDB continuous backups
- Minimal data loss

---

## Design Decisions

### Why Serverless?

**Advantages:**
- ✅ No server management
- ✅ Automatic scaling
- ✅ Pay-per-use pricing
- ✅ High availability (multi-AZ)
- ✅ Built-in monitoring

**Trade-offs:**
- ⚠️ Cold start latency (~200ms)
- ⚠️ Vendor lock-in (AWS-specific)
- ⚠️ Limited execution time (15 minutes max)

---

### Why DynamoDB?

**Advantages:**
- ✅ Single-digit millisecond latency
- ✅ Automatic scaling (on-demand)
- ✅ Built-in encryption
- ✅ Point-in-time recovery
- ✅ No server management

**Trade-offs:**
- ⚠️ Limited query patterns (partition + sort key)
- ⚠️ No complex joins or aggregations
- ⚠️ Cost increases with throughput

See `DATABASE_DESIGN.md` for detailed justification.

---

### Why API Gateway?

**Advantages:**
- ✅ Built-in IAM authorization
- ✅ Request/response validation
- ✅ Throttling and rate limiting
- ✅ CloudWatch integration
- ✅ Automatic HTTPS

**Trade-offs:**
- ⚠️ Additional latency (~10-20ms)
- ⚠️ Cost per request ($3.50/million)
- ⚠️ Limited to REST/HTTP protocols

---

### Why KMS Customer-Managed Keys?

**Advantages:**
- ✅ Full control over key lifecycle
- ✅ Audit trail (CloudTrail)
- ✅ Key rotation policy
- ✅ Compliance requirements

**Trade-offs:**
- ⚠️ Additional cost ($1/month + $0.03/10K requests)
- ⚠️ Complexity (key management)

---

## Future Enhancements

**Planned:**
- [ ] Global secondary indexes for advanced queries
- [ ] DynamoDB Streams for real-time processing
- [ ] Lambda@Edge for global distribution
- [ ] Cross-region replication for disaster recovery
- [ ] API Gateway caching for read-heavy workloads

**Under Consideration:**
- [ ] GraphQL API (AppSync)
- [ ] WebSocket support for real-time logs
- [ ] S3 archival for long-term storage
- [ ] Athena integration for analytics
- [ ] QuickSight dashboards for visualization

---

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)

---

**Document Owner:** Infrastructure Team  
**Review Cycle:** Quarterly  
**Next Review:** 2026-05-02
