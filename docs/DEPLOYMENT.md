Simple Log Service - Deployment Guide

Version: 2.0  
Last Updated: 2026-02-02  
Status: Production

Table of Contents
Prerequisites
Initial Setup
Deployment Steps
Post-Deployment Configuration
Testing Deployment
Environment-Specific Deployments
Updating Deployment
Rollback Procedures
Monitoring Deployment
Troubleshooting
Cleanup
Security Checklist

Prerequisites

Required Software
• Terraform: >= 1.5.0 (Install)
• AWS CLI: >= 2.0 (Install)
• Python: 3.12 (Install)
• Git: Latest version (Install)
• PowerShell: 5.1+ (Windows) or PowerShell Core (cross-platform)
• VS Code: Recommended IDE (Install)

Verify Installations:

AWS Account Requirements
• Active AWS account (Account ID: 033667696152)
• IAM user with administrator access (or specific permissions below)
• AWS CLI configured with credentials
• Access to us-east-1 region (N. Virginia)

Required IAM Permissions

Minimum Required Permissions:

Initial Setup
Clone Repository

Configure AWS Credentials

Verify Credentials:

Expected Output:

Review Configuration

Edit terraform/variables.tf to customize:

Deployment Steps

Step 1: Initialize Terraform

Expected Output:

Troubleshooting:
• If init fails, delete .terraform/ and .terraform.lock.hcl, then retry
• Ensure internet connectivity for provider downloads

Step 2: Validate Configuration

Expected Output:

If Validation Fails:
• Check syntax errors in .tf files
• Verify variable types and values
• Review Terraform version compatibility

Step 3: Plan Deployment

Review the Plan:
• Expected Resources: ~25-30 resources
• 1 DynamoDB table
• 2 Lambda functions
• 1 API Gateway (REST API)
• 1 KMS customer-managed key
• 6 IAM roles (Lambda execution + access roles)
• 3 CloudWatch log groups
• 3 CloudWatch alarms
• 1 SNS topic
• 4 AWS Config rules
• Supporting resources (policies, permissions, etc.)

Key Resources to Verify:
• DynamoDB table: simple-log-service-logs-prod
• Lambda functions: simple-log-service-ingest-prod, simple-log-service-read-recent-prod
• API Gateway: simple-log-service-prod
• KMS key alias: alias/simple-log-service-prod

Step 4: Apply Deployment

Deployment Timeline:
• Total Duration: 5-10 minutes
• DynamoDB table: ~2 minutes
• Lambda functions: ~1 minute each
• API Gateway: ~2 minutes
• KMS key: ~1 minute
• IAM roles: ~1 minute
• CloudWatch resources: ~1 minute

Expected Output:

Step 5: Verify Deployment

Verify in AWS Console:
DynamoDB: https://console.aws.amazon.com/dynamodbv2/home?region=us-east-1#tables
Lambda: https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions
API Gateway: https://console.aws.amazon.com/apigateway/home?region=us-east-1#/apis
KMS: https://console.aws.amazon.com/kms/home?region=us-east-1#/kms/keys

Post-Deployment Configuration
Confirm SNS Subscription

If you provided an email address in variables.tf:
Check your email inbox (including spam folder)
Look for email from: AWS Notifications 
Subject: AWS Notification - Subscription Confirmation
Click the confirmation link
Verify subscription in AWS Console:

Expected Output:

Verify IAM Roles

Check Role Trust Policies:

Verify External IDs:
• Ingest: simple-log-service-ingest-prod
• Read: simple-log-service-read-prod
• Full Access: simple-log-service-full-prod

Verify KMS Key

Check Key Status:

Expected Output:

Verify DynamoDB Configuration

Check Table Details:

Expected Output:

Testing Deployment

Test Script 1: Complete Lambda Test

Purpose: Validates Lambda functions with IAM role assumption

Expected Output:

Test Script 2: API Gateway Test

Purpose: Validates API Gateway endpoints with AWS SigV4 authentication

Expected Output:

Test Script 3: Python API Test

Purpose: Python-based API testing with pytest

Expected Output:

Environment-Specific Deployments

Development Environment

Configuration:
• Lower capacity settings
• Deletion protection disabled
• Shorter log retention (3 days)
• Reduced alarm thresholds

Deploy:

Staging Environment

Configuration:
• Production-like settings
• Deletion protection enabled
• Standard log retention (7 days)
• Production alarm thresholds

Deploy:

Production Environment

Configuration:
• Maximum security settings
• Deletion protection enabled
• Extended log retention (7 days)
• Strict alarm thresholds
• Point-in-time recovery enabled

Deploy:

Updating Deployment

Update Lambda Functions

Scenario: Modified Lambda code in lambda/ingest/index.py or lambda/read_recent/index.py

Note: Terraform automatically creates new Lambda deployment packages when code changes are detected.

Update Infrastructure Configuration

Scenario: Modified Terraform files (e.g., increased DynamoDB capacity)

Example: Increase Lambda Memory

Update Variables

Scenario: Changed configuration in variables.tf

Rollback Procedures

Rollback to Previous Terraform State

Scenario: Recent deployment caused issues

Emergency Rollback (Git-Based)

Scenario: Critical issue requires immediate rollback

Rollback Lambda Function Only

Scenario: Lambda code issue, infrastructure is fine

Monitoring Deployment

View Lambda Logs

Ingest Lambda:

Read Lambda:

Filter by Error:

View API Gateway Logs

Check DynamoDB Metrics

Consumed Capacity:

Throttled Requests:

Check CloudWatch Alarms

Troubleshooting

Issue 1: Terraform Init Fails

Symptoms:

Solutions:

Issue 2: Lambda Deployment Fails

Symptoms:

Solutions:

Issue 3: API Gateway Returns 403 Forbidden

Symptoms:

Solutions:
Verify AWS Credentials:
Check IAM Role Permissions:
Verify External ID:
• Ensure external ID matches: simple-log-service-ingest-prod
Test Role Assumption:
Check API Gateway Authorization:

Issue 4: DynamoDB Throttling

Symptoms:

Solutions:
Check Current Capacity:
Switch to On-Demand (if using provisioned):
Increase Provisioned Capacity:

Issue 5: KMS Access Denied

Symptoms:

Solutions:
Check KMS Key Policy:
Verify Lambda Execution Role:
Update KMS Key Policy (if needed):
• Edit terraform/kms.tf
• Add Lambda execution role to key policy
• Apply changes: terraform apply

Issue 6: CloudWatch Logs Not Appearing

Symptoms:
• Lambda executes successfully but no logs in CloudWatch

Solutions:
Check Log Group Exists:
Verify Lambda Execution Role:
Check Lambda Configuration:

Issue 7: Pytest Cache Access Denied

Symptoms:

Solutions:
Delete Pytest Cache:
Update lambda.tf to Exclude Test Directories:
Reinitialize and Apply:

Cleanup

Remove All Resources

Warning: This will permanently delete all data and resources.

Confirmation Required:
• Type yes when prompted
• Destruction takes 5-10 minutes

Resources Deleted:
• DynamoDB table (all log data)
• Lambda functions
• API Gateway
• KMS key (scheduled for deletion in 30 days)
• IAM roles and policies
• CloudWatch log groups (all logs)
• CloudWatch alarms
• SNS topic
• AWS Config rules

Selective Cleanup

Remove Specific Resource:

Cleanup Test Data

Delete Test Logs from DynamoDB:

Security Checklist

Pre-Deployment:
• [ ] AWS credentials configured with temporary credentials (not root)
• [ ] IAM user has minimum required permissions
• [ ] MFA enabled for AWS account
• [ ] Git repository is private (if sensitive data)

Post-Deployment:
• [ ] KMS key created and enabled
• [ ] KMS key rotation enabled
• [ ] Deletion protection enabled (production)
• [ ] Point-in-time recovery enabled
• [ ] CloudWatch logs encrypted
• [ ] SNS topic encrypted
• [ ] API Gateway using AWS_IAM authorization
• [ ] IAM roles follow least privilege principle
• [ ] External IDs configured for role assumption
• [ ] AWS Config enabled and rules active
• [ ] CloudTrail enabled (recommended)
• [ ] SNS subscription confirmed
• [ ] CloudWatch alarms configured
• [ ] Budget alerts configured

Ongoing:
• [ ] Review IAM policies monthly
• [ ] Rotate external IDs quarterly
• [ ] Review CloudWatch alarms weekly
• [ ] Check AWS Config compliance dashboard weekly
• [ ] Review CloudTrail logs for anomalies
• [ ] Test disaster recovery procedures quarterly
• [ ] Update documentation as needed

Cost Management

View Current Costs

Set Budget Alerts

Create Budget:

budget.json:

notifications.json:

Next Steps

After Successful Deployment:
Run Load Tests
Configure Monitoring Dashboard
• Access CloudWatch dashboard
• Customize metrics and widgets
• Set up additional alarms
Enable Automated Backups
• Configure DynamoDB on-demand backups
• Set up S3 archival for old logs
Document APIs
• Create API documentation (Swagger/OpenAPI)
• Share with development teams
Set Up CI/CD
• Configure GitHub Actions workflow
• Automate testing and deployment
Plan Disaster Recovery
• Test point-in-time recovery
• Document recovery procedures
• Conduct DR drills
Optimize Costs
• Review usage patterns
• Consider provisioned capacity for steady workloads
• Implement S3 archival for old logs

Support

For Issues:
Check Troubleshooting section
Review CloudWatch logs for errors
Verify Terraform state: terraform show
Check AWS service quotas
Open GitHub issue: https://github.com/pmguzumbi/
