
# Performance Documentation

## Overview

This document details the performance characteristics, benchmarks, and optimization strategies for the Simple Log Service.

## Performance Targets

### Latency Targets

| Operation | p50 | p95 | p99 | p99.9 |
|-----------|-----|-----|-----|-------|
| Log Ingestion | 50ms | 150ms | 200ms | 500ms |
| Log Retrieval (by service) | 75ms | 200ms | 300ms | 600ms |
| Log Retrieval (by type) | 100ms | 250ms | 350ms | 700ms |
| Log Retrieval (scan) | 150ms | 400ms | 600ms | 1000ms |

### Throughput Targets

| Metric | Target | Maximum |
|--------|--------|---------|
| Ingestion Rate | 1,000 req/sec | 5,000 req/sec |
| Retrieval Rate | 500 req/sec | 2,000 req/sec |
| Concurrent Connections | 1,000 | 10,000 |
| Data Transfer | 10 MB/sec | 50 MB/sec |

## Component Performance

### 1. API Gateway

#### Latency Breakdown
```
Total Request Time: 50-200ms
├── API Gateway Overhead: 5-10ms
├── Lambda Cold Start: 0-500ms (first request)
├── Lambda Warm Execution: 20-100ms
└── DynamoDB Operation: 10-50ms
```

#### Throughput Limits
- **Steady State**: 10,000 requests/second
- **Burst**: 5,000 requests (300 seconds)
- **Regional Limit**: 10,000 requests/second (can be increased)

#### Optimization Strategies
1. **Enable Caching**: Reduce Lambda invocations
2. **Use HTTP API**: 70% lower latency than REST API
3. **Regional Endpoints**: Lower latency than edge-optimized
4. **Request Validation**: Reduce invalid Lambda invocations

### 2. Lambda Functions

#### Cold Start Performance

**Ingest Lambda**:
```
Cold Start: 300-500ms
Warm Start: 20-50ms
Memory: 256 MB
Package Size: 5 MB
```

**Read Lambda**:
```
Cold Start: 300-500ms
Warm Start: 30-75ms
Memory: 256 MB
Package Size: 5 MB
```

#### Execution Time Breakdown

**Ingest Operation**:
```
Total: 50ms (p50)
├── Input Validation: 5ms
├── UUID Generation: 2ms
├── DynamoDB PutItem: 30ms
├── CloudWatch Metric: 10ms
└── Response Formation: 3ms
```

**Read Operation**:
```
Total: 75ms (p50)
├── Parameter Parsing: 5ms
├── DynamoDB Query: 50ms
├── Result Processing: 15ms
└── Response Formation: 5ms
```

#### Optimization Strategies

**1. Reduce Cold Starts**
```hcl
# Provisioned Concurrency (production only)
resource "aws_lambda_provisioned_concurrency_config" "ingest" {
  function_name = aws_lambda_function.ingest_log.function_name
  provisioned_concurrent_executions = 5
}

Cost: $0.015 per GB-hour
Benefit: Eliminates cold starts for provisioned instances
```

**2. Optimize Memory**
```python
# Test different memory configurations
Memory Options: 128, 256, 512, 1024 MB
Optimal: 256 MB (balance of cost and performance)
```

**3. Minimize Package Size**
```bash
# Remove unnecessary dependencies
pip install --target ./package boto3 --upgrade
cd package
zip -r ../deployment.zip . -x "*.pyc" "__pycache__/*"
```

**4. Connection Reuse**
```python
# Initialize clients outside handler
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    # Reuse connection
    table.put_item(Item=item)
```

### 3. DynamoDB

#### Operation Latency

| Operation | Latency (p50) | Latency (p99) |
|-----------|---------------|---------------|
| GetItem | 5-10ms | 20-30ms |
| PutItem | 10-15ms | 30-50ms |
| Query (partition key) | 10-20ms | 40-60ms |
| Query (GSI) | 15-30ms | 50-80ms |
| Scan | 50-200ms | 200-500ms |

#### Throughput Capacity

**Provisioned Mode**:
```
1 RCU = 1 strongly consistent read/sec (4 KB)
1 RCU = 2 eventually consistent reads/sec (4 KB)
1 WCU = 1 write/sec (1 KB)

Base: 5 RCU/WCU
Auto-scaling: Up to 100 RCU/WCU
Burst Capacity: 300 seconds at 3000 RCU/WCU
```

**On-Demand Mode**:
```
Accommodates up to 2x previous peak
No capacity planning required
Higher cost per request
```

#### Query Performance

**Best Performance (Partition Key Query)**:
```python
# Query by service_name (partition key)
response = table.query(
    KeyConditionExpression=Key('service_name').eq('api-service') &
                          Key('timestamp').between(start, end)
)

Latency: 10-20ms (p50)
Efficiency: O(log n)
Cost: 1 RCU per 4 KB
```

**Good Performance (GSI Query)**:
```python
# Query by log_type (GSI partition key)
response = table.query(
    IndexName='TimestampIndex',
    KeyConditionExpression=Key('log_type').eq('application') &
                          Key('timestamp').gte(cutoff)
)

Latency: 15-30ms (p50)
Efficiency: O(log n)
Cost: 1 RCU per 4 KB (from GSI)
```

**Poor Performance (Scan)**:
```python
# Scan entire table
response = table.scan(
    FilterExpression=Key('timestamp').gte(cutoff)
)

Latency: 50-200ms (p50)
Efficiency: O(n)
Cost: 1 RCU per 4 KB (entire table)
```
