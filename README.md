# Simple Log Service

A serverless log ingestion and retrieval system built on AWS using Lambda, DynamoDB, API Gateway, and CloudWatch with comprehensive compliance monitoring via AWS Config.

## Architecture Overview

This system provides a scalable, secure log management solution with the following components:

- **API Gateway**: RESTful endpoints for log ingestion and retrieval
- **Lambda Functions**: Serverless compute for log processing
- **DynamoDB**: NoSQL database for log storage with GSI for efficient queries
- **CloudWatch**: Monitoring, logging, and alerting
- **KMS**: Customer-managed encryption keys for data at rest
- **AWS Config**: Compliance monitoring and configuration tracking
- **Multi-AZ Deployment**: High availability across eu-west-2a and eu-west-2b

## Features

- ✅ Secure log ingestion with AWS SigV4 authentication
- ✅ Recent log retrieval (last 24 hours)
- ✅ Encryption at rest (KMS) and in transit (TLS)
- ✅ Point-in-time recovery and deletion protection
- ✅ CloudWatch monitoring with custom metrics
- ✅ AWS Config compliance monitoring
- ✅ SNS notifications for compliance violations
- ✅ Auto-scaling and multi-AZ failover
- ✅ Infrastructure as Code (Terraform)
- ✅ CI/CD pipeline (GitHub Actions)
- ✅ Comprehensive testing suite
- ✅ Windows PowerShell compatible

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- Python 3.11
- AWS CLI configured
- Git
- VS Code (recommended)

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/simple-log-service.git
cd simple-log-service
```

### 2. Configure AWS Credentials
```bash
aws configure
```

### 3. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Test the Service
```bash
# Get API endpoint from Terraform output
export API_ENDPOINT=$(terraform output -raw api_gateway_url)

# Run tests (PowerShell compatible)
cd ../scripts
python test_api.py
```

## Project Structure

```
simple-log-service/
├── README.md
├── CHANGELOG.md
├── .gitignore
├── lambda/
│   ├── ingest_log/
│   │   ├── index.py
│   │   ├── requirements.txt
│   │   └── tests/
│   │       └── test_ingest.py
│   └── read_recent/
│       ├── index.py
│       ├── requirements.txt
│       └── tests/
│           └── test_read.py
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── dynamodb.tf
│   ├── lambda.tf
│   ├── api_gateway.tf
│   ├── monitoring.tf
│   ├── kms.tf
│   ├── iam.tf
│   └── config.tf
├── scripts/
│   ├── test_api.py
│   ├── load_test.py
│   └── deploy.sh
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATABASE_DESIGN.md
│   ├── DEPLOYMENT.md
│   ├── COST_ESTIMATION.md
│   ├── PERFORMANCE.md
│   ├── DISASTER_RECOVERY.md
│   └── COMPLIANCE.md
└── .github/
    └── workflows/
        └── terraform.yml
```

## Database Design

### DynamoDB Table: LogsTable

**Primary Key:**
- Partition Key: `service_name` (String)
- Sort Key: `timestamp` (Number)

**Global Secondary Index: TimestampIndex**
- Partition Key: `log_type` (String)
- Sort Key: `timestamp` (Number)

**Attributes:**
- `log_id` (String): Unique identifier
- `message` (String): Log message content
- `level` (String): Log level (INFO, WARN, ERROR)
- `metadata` (Map): Additional context

See [DATABASE_DESIGN.md](docs/DATABASE_DESIGN.md) for details.

## API Endpoints

### POST /logs
Ingest a new log entry

**Request Body:**
```json
{
  "service_name": "api-service",
  "log_type": "application",
  "level": "INFO",
  "message": "User login successful",
  "metadata": {
    "user_id": "12345",
    "ip": "[IP_ADDRESS]"
  }
}
```

### GET /logs/recent
Retrieve logs from the last 24 hours

**Query Parameters:**
- `service_name` (optional): Filter by service
- `log_type` (optional): Filter by type
- `limit` (optional): Max results (default: 100)

## Compliance Monitoring

AWS Config continuously monitors:
- DynamoDB encryption at rest
- DynamoDB point-in-time recovery
- Lambda function encryption
- CloudWatch log encryption
- S3 bucket encryption and versioning

SNS notifications are sent for any compliance violations.

See [COMPLIANCE.md](docs/COMPLIANCE.md) for details.

## Monitoring

CloudWatch dashboards and alarms are automatically created:

- Lambda error rates and duration
- DynamoDB throttling and capacity
- API Gateway 4xx/5xx errors
- Custom business metrics
- AWS Config compliance status

## Security

- All data encrypted at rest using KMS customer-managed keys
- All data encrypted in transit using TLS 1.2+
- API authentication via AWS SigV4
- IAM roles with least privilege
- Temporary credentials only
- CloudWatch logs encrypted
- AWS Config compliance monitoring

## Cost Estimation

Estimated monthly cost: **$20-60** for moderate usage (including AWS Config)

See [COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for breakdown.

## Performance

- Log ingestion: ~50ms p50, ~200ms p99
- Log retrieval: ~100ms p50, ~300ms p99
- Throughput: 1000+ requests/second

See [PERFORMANCE.md](docs/PERFORMANCE.md) for details.

## Disaster Recovery

- Multi-AZ deployment for high availability
- Point-in-time recovery enabled (35 days)
- Automated backups
- AWS Config configuration snapshots

See [DISASTER_RECOVERY.md](docs/DISASTER_RECOVERY.md) for runbooks.

## CI/CD Pipeline

GitHub Actions workflow automatically:
- Validates Terraform syntax
- Runs unit tests
- Plans infrastructure changes
- Deploys on merge to main

## Testing

### Local Testing (VS Code)
```bash
# Install dependencies
pip install -r lambda/ingest_log/requirements.txt
pip install pytest moto boto3

# Run unit tests
pytest lambda/ingest_log/tests/
pytest lambda/read_recent/tests/
```

### Integration Testing
```bash
# Deploy to AWS
cd terraform
terraform apply

# Run API tests
cd ../scripts
python test_api.py

# Run load tests
python load_test.py
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

MIT License

## Support

For issues and questions, please open a GitHub issue.
