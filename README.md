SIMPLE LOG SERVICE

A secure, serverless logging service built on AWS infrastructure using Lambda, DynamoDB, and API Gateway with IAM authentication.

TABLE OF CONTENTS

Overview
Architecture
Features
Prerequisites
Quick Start
Project Structure
Deployment
Testing
API Documentation
Security
Monitoring
Cost Estimation
Troubleshooting
Documentation
Contributing

OVERVIEW

Simple Log Service is a production-ready, Infrastructure as Code (IaC) solution for centralized log management. Built entirely with Terraform, it provides secure log ingestion and retrieval capabilities with enterprise-grade security features.

KEY CAPABILITIES

  ✅ Serverless architecture (AWS Lambda + DynamoDB)
  ✅ IAM-authenticated API Gateway endpoints
  ✅ KMS encryption at rest and in transit
  ✅ Point-in-time recovery and deletion protection
  ✅ CloudWatch monitoring and alerting
  ✅ Comprehensive testing suite
  ✅ GitHub Actions CI/CD pipeline

ARCHITECTURE

HIGH-LEVEL ARCHITECTURE

Client Applications
        |
        | HTTPS + AWS SigV4
        |
        v
API Gateway (REST API)
• IAM Authorization
• POST /logs (Ingest)
• GET /logs/recent (Read)
        |
        |
        v
Lambda Functions
• Ingest Lambda (Write)
• Read Recent Lambda (Read)
        |
        |
        v
DynamoDB Table
• Partition Key: service_name
• Sort Key: timestamp
• KMS Encryption
• Point-in-Time Recovery
        |
        |
        v
CloudWatch Monitoring
• Metrics
• Alarms
• Logs

COMPONENTS

API Gateway:
• REST API with IAM authorization
• Two endpoints: POST /logs (ingest), GET /logs/recent (read)
• CloudWatch logging enabled

Lambda Functions:
• Ingest Lambda: Validates and stores log entries
• Read Recent Lambda: Retrieves logs with filtering

DynamoDB Table:
• Table: simple-log-service-logs-prod
• Partition Key: service_name (String)
• Sort Key: timestamp (String)
• KMS encryption with customer-managed key
• Point-in-time recovery enabled
• Deletion protection enabled

IAM Roles:
• Ingest Role: Write-only access to DynamoDB
• Read Role: Read-only access to DynamoDB
• Full Access Role: Complete access for administration

FEATURES

SECURITY

  🔒 KMS customer-managed encryption keys
  🔒 IAM authentication with external IDs
  🔒 Encryption in transit (TLS 1.2+)
  🔒 Least privilege IAM policies
  🔒 CloudWatch log encryption

RELIABILITY

  ⚡ Point-in-time recovery (35 days)
  ⚡ Deletion protection
  ⚡ Automated backups
  ⚡ Multi-AZ deployment

OBSERVABILITY

  📊 CloudWatch metrics and alarms
  📊 Lambda execution logs
  📊 API Gateway access logs
  📊 DynamoDB performance metrics

COMPLIANCE

  ✓ AWS Config monitoring
  ✓ Encryption compliance checks
  ✓ SNS notifications for violations

PREREQUISITES

REQUIRED TOOLS

Terraform: v1.0+
  Install: https://www.terraform.io/downloads

AWS CLI: v2.0+
  Install: https://aws.amazon.com/cli/

Python: 3.12+ (for testing)
  Install: https://www.python.org/downloads/

PowerShell: 5.1+ (Windows)
  Pre-installed on Windows

Git: For version control
  Install: https://git-scm.com/downloads

AWS ACCOUNT SETUP

• AWS Account with appropriate permissions
• AWS CLI configured with credentials
• S3 bucket for Terraform state (optional)
• DynamoDB table for state locking (optional)

PYTHON DEPENDENCIES (TESTING)

pip install requests requests-aws4auth boto3 pytest

QUICK START

STEP 1: CLONE REPOSITORY

git clone https://github.com/pmguzumbi/simple-log-service.git
cd simple-log-service

STEP 2: CONFIGURE AWS CREDENTIALS

aws configure

STEP 3: DEPLOY INFRASTRUCTURE

cd terraform
terraform init
terraform plan
terraform apply

STEP 4: TEST DEPLOYMENT

cd ../scripts
.\complete-test-script.ps1 -TestCount 5 -Environment prod

PROJECT STRUCTURE

simple-log-service/
├── .github/
│   └── workflows/
│       └── terraform.yml          # GitHub Actions CI/CD pipeline
├── docs/
│   ├── ARCHITECTURE.md            # Detailed system architecture
│   ├── DATABASE_DESIGN.md         # DynamoDB schema and design
│   ├── DEPLOYMENT.md              # Step-by-step deployment guide
│   ├── COMPLIANCE.md              # Security and compliance standards
│   ├── COST_ESTIMATION.md         # Cost analysis and optimization
│   └── TESTING_INSTRUCTIONS.md    # Complete testing guide
├── lambda/
│   ├── ingest/
│   │   ├── index.py               # Ingest Lambda function
│   │   └── tests/
│   │       └── test_ingest.py     # Unit tests for ingest
│   └── read_recent/
│       ├── index.py               # Read Lambda function
│       └── tests/
│           └── test_read.py       # Unit tests for read
├── scripts/
│   ├── complete-test-script.ps1   # Lambda function tests
│   ├── api-gateway-test.ps1       # API Gateway tests
│   ├── test_api.py                # Python API tests
│   └── load_test.py               # Load testing script
├── terraform/
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── dynamodb.tf                # DynamoDB table configuration
│   ├── lambda.tf                  # Lambda functions configuration
│   ├── api_gateway.tf             # API Gateway configuration
│   ├── iam.tf                     # IAM roles and policies
│   ├── iamapiroles.tf           # API-specific IAM roles
│   ├── kms.tf                     # KMS encryption keys
│   ├── cloudwatch.tf              # CloudWatch monitoring
│   └── config.tf                  # AWS Config rules
├── .gitignore                     # Git ignore rules
├── LICENSE                        # MIT License
└── README.md                      # This file

DEPLOYMENT

STANDARD DEPLOYMENT

Step 1: Initialize Terraform

cd terraform
terraform init

Step 2: Review Plan

terraform plan -out=tfplan

Step 3: Apply Configuration

terraform apply tfplan

Step 4: Retrieve Outputs

terraform output

ENVIRONMENT-SPECIFIC DEPLOYMENT

Production:

terraform apply -var="environment=prod" -var="enabledeletionprotection=true"

Development:

terraform apply -var="environment=dev" -var="enabledeletionprotection=false"

TERRAFORM BACKEND CONFIGURATION

For team collaboration, configure S3 backend in terraform/main.tf:

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "simple-log-service/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

TESTING

TEST SCRIPTS OVERVIEW

Script: complete-test-script.ps1
  Purpose: Lambda function validation
  Target: Backend

Script: api-gateway-test.ps1
  Purpose: API Gateway endpoint testing
  Target: API

Script: test_api.py
  Purpose: Python-based API tests
  Target: API

Script: load_test.py
  Purpose: Performance and load testing
  Target: System

RUNNING TESTS

Complete Lambda Test:

cd scripts
.\complete-test-script.ps1 -TestCount 5 -Environment prod

API Gateway Test:

.\api-gateway-test.ps1 -TestCount 3 -Environment prod

Python API Test:

python -m pytest test_api.py -v -s

Load Test:

python load_test.py --requests 1000 --concurrency 10

TEST PREREQUISITES

Environment Variables:

AWS_REGION=us-east-1
AWSACCOUNTID=<Account ID>

External IDs:
• Ingest: simple-log-service-ingest-prod
• Read: simple-log-service-read-prod

API DOCUMENTATION

BASE URL

https://v22n8t8394.execute-api.us-east-1.amazonaws.com/prod

AUTHENTICATION

All endpoints require AWS SigV4 authentication with IAM credentials.

ENDPOINTS

POST /logs (Ingest)

Description: Ingest a new log entry

Request Body:

{
  "service_name": "api-gateway",
  "timestamp": "2026-02-02T10:30:45.123Z",
  "log_type": "application",
  "level": "INFO",
  "message": "Request processed successfully",
  "metadata": {
    "user_id": "12345",
    "request_id": "abc-def-ghi"
  }
}

Response (201 Created):

{
  "message": "Log entry created successfully",
  "log_id": "550e8400-e29b-41d4-a716-446655440000"
}

Required IAM Role: simple-log-service-ingest-prod

GET /logs/recent (Read)

Description: Retrieve recent log entries

Query Parameters:
• service_name (optional): Filter by service
• limit (optional): Max results (default: 100)

Example Request:

GET /logs/recent?service_name=api-gateway&limit=50

Response (200 OK):

{
  "logs": [
    {
      "service_name": "api-gateway",
      "timestamp": "2026-02-02T10:30:45.123Z",
      "log_id": "550e8400-e29b-41d4-a716-446655440000",
      "log_type": "application",
      "level": "INFO",
      "message": "Request processed successfully",
      "metadata": {
        "user_id": "12345",
        "request_id": "abc-def-ghi"
      }
    }
  ],
  "count": 1
}

Required IAM Role: simple-log-service-read-prod

SECURITY

ENCRYPTION

At Rest:
• DynamoDB encrypted with KMS customer-managed key
• CloudWatch logs encrypted
• Lambda environment variables encrypted

In Transit:
• TLS 1.2+ for all API calls
• AWS SigV4 request signing

IAM ROLES

Ingest Role:
• dynamodb:PutItem on logs table
• External ID: simple-log-service-ingest-prod

Read Role:
• dynamodb:Scan, dynamodb:Query on logs table
• External ID: simple-log-service-read-prod

Full Access Role:
• Complete DynamoDB access
• Administrative operations

BEST PRACTICES

  ✅ Use temporary credentials via role assumption
  ✅ Rotate external IDs regularly
  ✅ Enable CloudTrail for audit logging
  ✅ Review IAM policies quarterly
  ✅ Enable MFA for administrative access

MONITORING

CLOUDWATCH ALARMS

Lambda Errors:
• Threshold: > 5 errors in 5 minutes
• Action: SNS notification

DynamoDB Throttling:
• Threshold: > 10 throttled requests
• Action: SNS notification

API Gateway 5xx Errors:
• Threshold: > 10 errors in 5 minutes
• Action: SNS notification

METRICS DASHBOARD

Access CloudWatch dashboard: simple-log-service-prod-dashboard

Key Metrics:
• Lambda invocations and duration
• DynamoDB read/write capacity
• API Gateway request count and latency
• Error rates and throttling

COST ESTIMATION

MONTHLY COST BREAKDOWN (ESTIMATED)

Service: Lambda
  Usage: 1M invocations
  Cost: $0.20

Service: DynamoDB
  Usage: 1GB storage, 1M reads/writes
  Cost: $1.50

Service: API Gateway
  Usage: 1M requests
  Cost: $3.50

Service: KMS
  Usage: 1 key, 10K requests
  Cost: $1.10

Service: CloudWatch
  Usage: Logs + metrics
  Cost: $2.00

Total: ~$8.30/month

Note: Costs vary based on actual usage. See docs/COST_ESTIMATION.md for detailed analysis.

TROUBLESHOOTING

COMMON ISSUES

Issue: "Terraform state file not found"

Solution:

cd terraform
terraform init
terraform apply

Issue: "Failed to assume role"

Solutions:
• Verify external IDs match IAM trust policies
• Check sts:AssumeRole permission
• Confirm role ARNs are correct

Issue: "403 Forbidden" API errors

Solutions:
• Verify IAM role has execute-api:Invoke permission
• Check API Gateway authorization is AWS_IAM
• Confirm AWS SigV4 signing is correct

Issue: "No logs retrieved"

Solutions:
• Wait for DynamoDB eventual consistency (3-5 seconds)
• Check CloudWatch logs for Lambda errors
• Verify DynamoDB table has items

DEBUG COMMANDS

Check Lambda logs:

aws logs tail /aws/lambda/simple-log-service-ingest-prod --follow

Check DynamoDB items:

aws dynamodb scan --table-name simple-log-service-logs-prod --limit 10

Test role assumption:

aws sts assume-role --role-arn "arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod" --role-session-name "test-session" --external-id "simple-log-service-ingest-prod"

DOCUMENTATION

Comprehensive documentation available in docs/:
• ARCHITECTURE.md - Detailed system architecture
• DATABASE_DESIGN.md - DynamoDB schema and design decisions
• DEPLOYMENT.md - Step-by-step deployment guide
• COMPLIANCE.md - Security and compliance standards
• COST_ESTIMATION.md - Cost analysis and optimization
• TESTING_INSTRUCTIONS.md - Complete testing guide

CONTRIBUTING

DEVELOPMENT WORKFLOW

Fork the repository
Create a feature branch (git checkout -b feature/amazing-feature)
Make changes and test locally
Commit changes (git commit -m 'Add amazing feature')
Push to branch (git push origin feature/amazing-feature)
Open a Pull Request

CODE STANDARDS

• Follow Terraform best practices
• Include inline comments for complex logic
• Update documentation for new features
• Add tests for new functionality
• Use descriptive commit messages

REPOSITORY INFORMATION

Repository: https://github.com/pmguzumbi/simple-log-service
AWS Account: <Account ID>
Primary Region: us-east-1
Environment: Production (prod)

LICENSE

This project is licensed under the MIT License - see LICENSE file for details.

SUPPORT

For issues, questions, or contributions:
Check Troubleshooting section
Review documentation in docs/
Open an issue on GitHub
Contact repository maintainers


VERSION HISTORY

v1.0.0 (2026-02-02) - Initial production release
• Complete Terraform infrastructure
• Lambda functions with IAM authentication
• Comprehensive testing suite
• Full documentation



Built with  using AWS, Terraform, and Infrastructure as Code principles
