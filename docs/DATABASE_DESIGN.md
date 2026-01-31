# Database Design Documentation

## Overview

The Simple Log Service uses Amazon DynamoDB as its primary data store, optimized for high-throughput log ingestion and efficient time-based queries.

## Table Schema

### Primary Table: LogsTable

```
Table Name: simple-log-service-{environment}-logs
Billing Mode: Provisioned (with auto-scaling)
Encryption: KMS customer-managed key
Point-in-Time Recovery: Enabled
Deletion Protection: Enabled
```

## Key Design

### Primary Key

**Partition Key (HASH)**: `service_name` (String)
- Distributes logs across partitions by service
- Enables efficient queries for specific services
- Supports multi-tenant architecture

**Sort Key (RANGE)**: `timestamp` (Number)
- Unix timestamp (seconds since epoch)
- Enables time-range queries
- Supports chronological ordering

### Composite Key Benefits
1. **Even Distribution**: Service names provide good partition distribution
2. **Query Efficiency**: Time-based queries within a service are fast
3. **Scalability**: Supports millions of logs per service

## Attributes

### Required Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| service_name | String | Service generating the log (PK) |
| timestamp | Number | Unix timestamp in seconds (SK) |
| log_id | String | Unique identifier (UUID) |
| log_type | String | Log category (application, system, audit) |
| level | String | Log level (INFO, WARN, ERROR, DEBUG) |
| message | String | Log message content |

### Optional Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| metadata | Map | Additional context (flexible schema) |
| ttl | Number | Expiration timestamp (for auto-deletion) |

## Global Secondary Index

### TimestampIndex

```
Index Name: TimestampIndex
Partition Key: log_type (String)
Sort Key: timestamp (Number)
Projection: ALL
```

**Purpose**: Enable efficient queries by log type across all services

**Use Cases**:
- Retrieve all application logs in last 24 hours
- Query system logs by time range
- Aggregate logs by type

**Query Pattern**:
```python
table.query(
    IndexName='TimestampIndex',
    KeyConditionExpression=Key('log_type').eq('application') & 
                          Key('timestamp').gte(cutoff_timestamp)
)
```

## Access Patterns

### Pattern 1: Query by Service and Time
**Use Case**: Get recent logs for a specific service

```python
table.query(
    KeyConditionExpression=Key('service_name').eq('api-service') & 
                          Key('timestamp').between(start, end)
)
```

**Performance**: O(log n) - Very efficient

### Pattern 2: Query by Log Type and Time
**Use Case**: Get all logs of a specific type

```python
table.query(
    IndexName='TimestampIndex',
    KeyConditionExpression=Key('log_type').eq('application') & 
                          Key('timestamp').gte(cutoff)
)
```

**Performance**: O(log n) - Efficient with GSI

### Pattern 3: Scan Recent Logs
**Use Case**: Get all recent logs (no filter)

```python
table.scan(
    FilterExpression=Key('timestamp').gte(cutoff),
    Limit=100
)
```

**Performance**: O(n) - Less efficient, use sparingly

## Capacity Planning

### Read Capacity Units (RCU)

**Base Capacity**: 5 RCU
**Auto-Scaling**: 5-100 RCU (70% utilization target)

**Calculation**:
- 1 RCU = 1 strongly consistent read/sec (4 KB)
- 1 RCU = 2 eventually consistent reads/sec (4 KB)

**Example**:
- 100 reads/sec of 1 KB items = 25 RCU (eventually consistent)

### Write Capacity Units (WCU)

**Base Capacity**: 5 WCU
**Auto-Scaling**: 5-100 WCU (70% utilization target)

**Calculation**:
- 1 WCU = 1 write/sec (1 KB)

**Example**:
- 50 writes/sec of 2 KB items = 100 WCU

## Data Retention

### Current Strategy
- **Retention**: Indefinite (manual deletion)
- **Backup**: Point-in-time recovery (35 days)

### Future Strategy (TTL)
```python
# Add TTL attribute during ingestion
ttl_timestamp = current_timestamp + (90 * 24 * 60 * 60)  # 90 days

log_entry = {
    'service_name': 'api-service',
    'timestamp': current_timestamp,
    'ttl': ttl_timestamp,  # Auto-delete after 90 days
    ...
}
```

## Partition Strategy

### Hot Partition Avoidance

**Problem**: Single service generating high volume could create hot partition

**Solutions**:
1. **Composite Keys**: Service name + timestamp distributes writes
2. **Write Sharding**: Add random suffix to service name if needed
3. **Burst Capacity**: DynamoDB provides burst capacity for spikes

### Example Sharding (if needed)
```python
# For very high-volume services
shard_id = hash(log_id) % 10
service_name_sharded = f"{service_name}#{shard_id}"
```

## Query Optimization

### Best Practices

1. **Use Query over Scan**: Always prefer Query when possible
2. **Limit Results**: Use Limit parameter to control costs
3. **Project Attributes**: Use ProjectionExpression for specific fields
4. **Consistent Reads**: Use eventually consistent for better performance
5. **Batch Operations**: Use BatchGetItem for multiple items

### Anti-Patterns to Avoid

1. **Full Table Scans**: Expensive and slow
2. **Large Items**: Keep items < 4 KB when possible
3. **Hot Keys**: Avoid concentrating writes on single partition
4. **Unbounded Queries**: Always use time ranges

## Backup and Recovery

### Point-in-Time Recovery (PITR)
- **Enabled**: Yes
- **Retention**: 35 days
- **Granularity**: Per-second
- **Recovery Time**: Minutes to hours

### On-Demand Backups
- **Frequency**: Manual or scheduled
- **Retention**: Until deleted
- **Use Case**: Pre-deployment snapshots

## Security

### Encryption at Rest
- **Method**: KMS customer-managed key
- **Key Rotation**: Enabled (annual)
- **Access**: IAM-controlled

### Encryption in Transit
- **Protocol**: TLS 1.2+
- **Endpoints**: VPC endpoints available

### Access Control
- **IAM Policies**: Least privilege
- **Resource Policies**: Table-level permissions
- **Condition Keys**: Fine-grained access

## Monitoring

### Key Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| ConsumedReadCapacity | > 70% | Scale up |
| ConsumedWriteCapacity | > 70% | Scale up |
| UserErrors | > 10/5min | Investigate |
| SystemErrors | > 0 | Alert |
| ThrottledRequests | > 0 | Scale up |

### CloudWatch Alarms
- Throttling events
- Capacity utilization
- Error rates
- Latency (p99)

## Cost Optimization

### Strategies

1. **Auto-Scaling**: Adjust capacity based on demand
2. **GSI Projection**: Use KEYS_ONLY or INCLUDE when possible
3. **Item Size**: Compress large items
4. **TTL**: Auto-delete old logs
5. **Reserved Capacity**: For predictable workloads

### Cost Breakdown (Monthly)

**Base Configuration** (5 RCU/WCU):
- Table: $2.50 (5 WCU) + $2.50 (5 RCU) = $5.00
- GSI: $2.50 (5 WCU) + $2.50 (5 RCU) = $5.00
- Storage: $0.25/GB
- Backups: $0.20/GB

**Total**: ~$10-15/month (low volume)

## Performance Benchmarks

### Latency Targets

| Operation | p50 | p99 | p99.9 |
|-----------|-----|-----|-------|
| PutItem | 10ms | 50ms | 100ms |
| Query (service) | 15ms | 75ms | 150ms |
| Query (GSI) | 20ms | 100ms | 200ms |
| Scan | 50ms | 200ms | 500ms |

### Throughput Targets

- **Writes**: 1000+ items/sec (with auto-scaling)
- **Reads**: 2000+ items/sec (eventually consistent)
- **Burst**: 3000 RCU/WCU for 300 seconds

## Schema Evolution

### Adding Attributes
- **Method**: Add to new items only
- **Backward Compatibility**: Handle missing attributes in code
- **Migration**: Optional background job

### Changing Keys
- **Method**: Create new table, migrate data
- **Downtime**: Zero (dual-write pattern)
- **Rollback**: Keep old table until verified

## Compliance

### AWS Config Rules
- `dynamodb-table-encrypted-kms`
- `dynamodb-pitr-enabled`
- `dynamodb-autoscaling-enabled`

### Audit Trail
- CloudTrail logs all API calls
- DynamoDB Streams for change tracking (optional)
