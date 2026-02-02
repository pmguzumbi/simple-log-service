Simple Log Service

A secure, serverless logging service built on AWS infrastructure using Lambda, DynamoDB, and API Gateway with IAM authentication.

📋 Table of Contents
• Overview
• Architecture
• Features
• Prerequisites
• Quick Start
• Project Structure
• Deployment
• Testing
• API Documentation
• Security
• Monitoring
• Cost Estimation
• Troubleshooting
• Documentation
• Contributing

Overview

Simple Log Service is a production-ready, Infrastructure as Code (IaC) solution for centralized log management. Built entirely with Terraform, it provides secure log ingestion and retrieval capabilities with enterprise-grade security features.

Key Capabilities:
• ✅ Serverless architecture (AWS Lambda + DynamoDB)
• ✅ IAM-authenticated API Gateway endpoints
• ✅ KMS encryption at rest and in transit
• ✅ Point-in-time recovery and deletion protection
• ✅ CloudWatch monitoring and alerting
• ✅ Comprehensive testing suite
• ✅ GitHub Actions CI/CD pipeline

Architecture

High-Level Architecture

Components

API Gateway
• REST API with IAM authorization
• Two endpoints: POST /logs (ingest), GET /logs/recent (read)
• CloudWatch logging enabled

Lambda Functions
• Ingest Lambda: Validates and stores log entries
• Read Recent Lambda: Retrieves logs with filtering

DynamoDB Table
• Table: simple-log-service-logs-prod
• Partition Key: service_name (String)
• Sort Key: timestamp (String)
• KMS encryption with customer-managed key
• Point-in-time recovery enabled
• Deletion protection enabled

IAM Roles
• Ingest Role: Write-only access to DynamoDB
• Read Role: Read-only access to DynamoDB
• Full Access Role: Complete access for administration

Features

Security
• 🔒 KMS customer-managed encryption keys
• 🔒 IAM authentication with external IDs
• 🔒 Encryption in transit (TLS 1.2+)
• 🔒 Least privilege IAM policies
• 🔒 CloudWatch log encryption

Reliability
• ⚡ Point-in-time recovery (35 days)
• ⚡ Deletion protection
• ⚡ Automated backups
• ⚡ Multi-AZ deployment

Observability
• 📊 CloudWatch metrics and alarms
• 📊 Lambda execution logs
• 📊 API Gateway access logs
• 📊 DynamoDB performance metrics

Compliance
• ✓ AWS Config monitoring
• ✓ Encryption compliance checks
• ✓ SNS notifications for violations

Prerequisites

Required Tools
• Terraform: v1.0+ (Install)
• AWS CLI: v2.0+ (Install)
• Python: 3.12+ (for testing)
• PowerShell: 5.1+ (Windows)
• Git: For version control

AWS Account Setup
• AWS Account with appropriate permissions
• AWS CLI configured with credentials
• S3 bucket for Terraform state (optional)
• DynamoDB table for state locking (optional)

Python Dependencies (Testing)

Quick Start
Clone Repository
Configure AWS Credentials
Deploy Infrastructure
Test Deployment

Project Structure

Deployment

Standard Deployment
Initialize Terraform
Review Plan
Apply Configuration
Retrieve Outputs

Environment-Specific Deployment

Production:

Development:

Terraform Backend Configuration

For team collaboration, configure S3 backend in terraform/main.tf:

Testing

Test Scripts Overview

| Script | Purpose | Target |
|--------|---------|--------|
| complete-test-script.ps1 | Lambda function validation | Backend |
| api-gateway-test.ps1 | API Gateway endpoint testing | API |
| test_api.py | Python-based API tests | API |
| load_test.py | Performance and load testing | System |

Running Tests

Complete Lambda Test:

API Gateway Test:

Python API Test:

Load Test:

Test Prerequisites

Environment Variables:

External IDs:
• Ingest: simple-log-service-ingest-prod
• Read: simple-log-service-read-prod

API Documentation

Base URL

Authentication
All endpoints require AWS SigV4 authentication with IAM credentials.

Endpoints

POST /logs (Ingest)

Description: Ingest a new log entry

Request Body:

Response (201 Created):

Required IAM Role: simple-log-service-ingest-prod

GET /logs/recent (Read)

Description: Retrieve recent log entries

Query Parameters:
• service_name (optional): Filter by service
• limit (optional): Max results (default: 100)

Response (200 OK):

Required IAM Role: simple-log-service-read-prod

Security

Encryption

At Rest:
• DynamoDB encrypted with KMS customer-managed key
• CloudWatch logs encrypted
• Lambda environment variables encrypted

In Transit:
• TLS 1.2+ for all API calls
• AWS SigV4 request signing

IAM Roles

Ingest Role:
• dynamodb:PutItem on logs table
• External ID: simple-log-service-ingest-prod

Read Role:
• dynamodb:Scan, dynamodb:Query on logs table
• External ID: simple-log-service-read-prod

Full Access Role:
• Complete DynamoDB access
• Administrative operations

Best Practices

✅ Use temporary credentials via role assumption
✅ Rotate external IDs regularly
✅ Enable CloudTrail for audit logging
✅ Review IAM policies quarterly
✅ Enable MFA for administrative access

Monitoring

CloudWatch Alarms

Lambda Errors:
• Threshold: > 5 errors in 5 minutes
• Action: SNS notification

DynamoDB Throttling:
• Threshold: > 10 throttled requests
• Action: SNS notification

API Gateway 5xx Errors:
• Threshold: > 10 errors in 5 minutes
• Action: SNS notification

Metrics Dashboard

Access CloudWatch dashboard: simple-log-service-prod-dashboard

Key Metrics:
• Lambda invocations and duration
• DynamoDB read/write capacity
• API Gateway request count and latency
• Error rates and throttling

Cost Estimation

Monthly Cost Breakdown (Estimated)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1M invocations | $0.20 |
| DynamoDB | 1GB storage, 1M reads/writes | $1.50 |
| API Gateway | 1M requests | $3.50 |
| KMS | 1 key, 10K requests | $1.10 |
| CloudWatch | Logs + metrics | $2.00 |
| Total | | ~$8.30/month |

Note: Costs vary based on actual usage. See docs/COST_ESTIMATION.md for detailed analysis.

Troubleshooting

Common Issues

Issue: "Terraform state file not found"

Issue: "Failed to assume role"
• Verify external IDs match IAM trust policies
• Check sts:AssumeRole permission
• Confirm role ARNs are correct

Issue: "403 Forbidden" API errors
• Verify IAM role has execute-api:Invoke permission
• Check API Gateway authorization is AWS_IAM
• Confirm AWS SigV4 signing is correct

Issue: "No logs retrieved"
• Wait for DynamoDB eventual consistency (3-5 seconds)
• Check CloudWatch logs for Lambda errors
• Verify DynamoDB table has items

Debug Commands

Documentation

Comprehensive documentation available in docs/:
• ARCHITECTURE.md - Detailed system architecture
• DATABASEDESIGN.md - DynamoDB schema and design decisions
• DEPLOYMENT.md - Step-by-step deployment guide
• COMPLIANCE.md - Security and compliance standards
• COSTESTIMATION.md - Cost analysis and optimization
• Testing instructions.md - Complete testing guide

Contributing

Development Workflow
Fork the repository
Create a feature branch (git checkout -b feature/amazing-feature)
Make changes and test locally
Commit changes (git commit -m 'Add amazing feature')
Push to branch (git push origin feature/amazing-feature)
Open a Pull Request

Code Standards
• Follow Terraform best practices
• Include inline comments for complex logic
• Update documentation for new features
• Add tests for new functionality
• Use descriptive commit messages

Repository Information
• Repository: https://github.com/pmguzumbi/simple-log-service
• AWS Account: <Account ID>
• Primary Region: us-east-1
• Environment: Production (prod)

License

This project is licensed under the MIT License - see LICENSE file for details.

Support

For issues, questions, or contributions:
Check Troubleshooting section
Review documentation in docs/
Open an issue on GitHub
Contact repository maintainers

Version History
• v1.0.0 (2026-02-02) - Initial production release
• Complete Terraform infrastructure
• Lambda functions with IAM authentication
• Comprehensive testing suite
• Full documentation

Built with ❤️ using AWS, Terraform, and Infrastructure as Code principles
