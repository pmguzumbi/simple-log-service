# Simple Log Service

A serverless logging service built on AWS using Lambda and DynamoDB for ingesting and retrieving log entries.

## Overview

This service provides two main functions:
1. **Ingest**: Accept log entries with severity levels (info, warning, error) and store them in DynamoDB
2. **Read Recent**: Retrieve the 100 most recent log entries sorted by timestamp

## Architecture

### Components
- **AWS Lambda**: Serverless compute for log ingestion and retrieval
- **Amazon DynamoDB**: NoSQL database for log storage with GSI for efficient querying
- **AWS KMS**: Customer-managed keys for encryption at rest
- **CloudWatch**: Logging and monitoring with encrypted log groups
- **AWS Config**: Compliance monitoring and configuration tracking

### Security Features
- Encryption at rest using KMS customer-managed keys
- Encryption in transit (TLS 1.2+)
- Point-in-time recovery enabled
- Deletion protection enabled
- IAM least-privilege access
- CloudWatch Logs encryption
- X-Ray tracing enabled

## Database Design

### DynamoDB Table: `log-entries`

**Primary Key:**
- Partition Key: `id` (String) - UUID for each log entry
- Sort Key: `datetime` (String) - ISO 8601
