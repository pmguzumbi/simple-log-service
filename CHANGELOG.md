# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-31

### Added
- Initial release of Simple Log Service
- Lambda functions for log ingestion and retrieval
- DynamoDB table with GSI for efficient queries
- API Gateway with AWS SigV4 authentication
- KMS encryption for data at rest
- CloudWatch monitoring and alarms
- AWS Config for compliance monitoring
- SNS notifications for compliance violations
- Multi-AZ deployment for high availability
- Terraform IaC for complete infrastructure
- GitHub Actions CI/CD pipeline
- Comprehensive documentation
- Unit tests with moto mocking
- Load testing scripts
- Windows PowerShell compatible test scripts
- VS Code compatible local testing

### Security
- Encryption at rest using KMS customer-managed keys
- Encryption in transit using TLS 1.2+
- IAM roles with least privilege principle
- Temporary credentials only
- Point-in-time recovery enabled
- Deletion protection enabled
- CloudWatch logs encrypted
- AWS Config compliance rules
- SNS alerting for security violations

### Fixed
- Lambda unit tests now use moto for DynamoDB mocking
- Removed real DynamoDB connections from tests
- Fixed timestamp handling in read_recent Lambda
- Improved error handling and logging
- Fixed Terraform deployment issues
- Added inline comments for code clarity
- Separated all configuration files for modularity

### Documentation
- Complete README with quick start guide
- Architecture documentation
- Database design documentation
- Deployment guide
- Cost estimation
- Performance benchmarks
- Disaster recovery procedures
- Compliance monitoring guide
- All files provided as separate artifacts
