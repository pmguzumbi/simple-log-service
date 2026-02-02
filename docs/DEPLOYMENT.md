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

Install the following tools before deployment:

Terraform (>= 1.5.0)

AWS CLI (>= 2.0)

Python 3.12

Git

PowerShell (5.1+ or PowerShell Core)

AWS Account Requirements
• Active AWS account (Account ID: 033667696152)
• IAM user with administrator access
• AWS CLI configured with credentials
• Access to us-east-1 region (N. Virginia)

Required IAM Permissions

Create an IAM policy with these permissions:

Initial Setup

Step 1: Clone Repository

Step 2: Configure AWS Credentials

When prompted, enter:
• AWS Access Key ID: YOURACCESSKEY
• AWS Secret Access Key: YOURSECRETKEY
• Default region name: us-east-1
• Default output format: json

Verify credentials:

Expected output:

Step 3: Review Configuration

Edit terraform/variables.tf to customize settings:

Deployment Steps

Step 1: Initialize Terraform

Expected output:

If initialization fails:

Step 2: Validate Configuration

Expected output:

Step 3: Plan Deployment

Review the plan output. Expected resources: ~25-30 resources including:
• 1 DynamoDB table
• 2 Lambda functions
• 1 API Gateway (REST API)
• 1 KMS customer-managed key
• 6 IAM roles
• 3 CloudWatch log groups
• 3 CloudWatch alarms
• 1 SNS topic
• 4 AWS Config rules

Step 4: Apply Deployment

Deployment takes approximately 5-10 minutes.

Expected output:

Step 5: Verify Deployment

Get specific outputs:

Save outputs to file:

Post-Deployment Configuration

Confirm SNS Subscription

Check your email for AWS SNS subscription confirmation:
Look for email from: AWS Notifications
Subject: AWS Notification - Subscription Confirmation
Click the confirmation link

Verify subscription:

Verify IAM Roles

Check ingest role:

Check read role:

Check full access role:

Verify KMS Key

Get key ID:

Describe key:

Check key rotation:

Expected output:

Verify DynamoDB Configuration

Expected output:

Testing Deployment

Test 1: Complete Lambda Test

Expected output:

Test 2: API Gateway Test

Expected output:

Test 3: Python API Test

Expected output:

Environment-Specific Deployments

Development Environment

Staging Environment

Production Environment

Updating Deployment

Update Lambda Functions

After modifying Lambda code:

Update Infrastructure Configuration

Example - increase Lambda memory:

Update Variables

Rollback Procedures

Rollback to Previous Git Version

View commit history:

Checkout previous version:

Destroy current deployment:

Redeploy previous version:

Return to main branch:

Rollback Lambda Function Only

Revert Lambda code:

Redeploy Lambda:

Monitoring Deployment

View Lambda Logs

Ingest Lambda:

Read Lambda:

Filter by error:

View API Gateway Logs

Check DynamoDB Metrics

Consumed capacity:

Throttled requests:

Check CloudWatch Alarms

List all alarms:

Check specific alarm:

Troubleshooting

Issue 1: Terraform Init Fails

Clear Terraform cache:

If behind proxy:

Issue 2: Lambda Deployment Fails

Check Lambda package:

Verify Lambda code syntax:

Manually create package:

Verify package contents:

Issue 3: API Gateway Returns 403 Forbidden

Verify AWS credentials:

Check IAM role permissions:

Test role assumption:

Issue 4: DynamoDB Throttling

Check current capacity:

Switch to on-demand:

Increase provisioned capacity:

Issue 5: KMS Access Denied

Check KMS key policy:

Verify Lambda execution role:

Issue 6: CloudWatch Logs Not Appearing

Check log group exists:

Verify Lambda execution role:

Check Lambda configuration:

Issue 7: Pytest Cache Access Denied

Delete pytest cache:

Update lambda.tf to exclude test directories:

Reinitialize and apply:

Cleanup

Remove All Resources

Disable deletion protection:

Destroy all resources:

Type yes when prompted. Destruction takes 5-10 minutes.

Selective Cleanup

Remove Lambda function only:

Remove DynamoDB table only:

Cleanup Test Data

Scan for test logs:

Security Checklist

Pre-Deployment:
• [ ] AWS credentials configured (not root account)
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
• [ ] IAM roles follow least privilege
• [ ] External IDs configured
• [ ] AWS Config enabled
• [ ] CloudTrail enabled (recommended)
• [ ] SNS subscription confirmed
• [ ] CloudWatch alarms configured
• [ ] Budget alerts configured

Ongoing:
• [ ] Review IAM policies monthly
• [ ] Rotate external IDs quarterly
• [ ] Review CloudWatch alarms weekly
• [ ] Check AWS Config compliance weekly
• [ ] Review CloudTrail logs for anomalies
• [ ] Test disaster recovery quarterly
• [ ] Update documentation as needed

Cost Management

View Current Costs

Set Budget Alerts

Create budget:

budget.json:

notifications.json:

Next Steps

After successful deployment:
Run load tests:
Configure monitoring dashboard in CloudWatch
Enable automated backups for DynamoDB
Document APIs (Swagger/OpenAPI)
Set up CI/CD with GitHub Actions
Plan disaster recovery procedures
Optimize costs based on usage patterns

Support

For Issues:
Check Troubleshooting section above
Review CloudWatch logs for errors
Verify Terraform state: terraform show
Check AWS service quotas
Open GitHub issue: https://github.com/pmguzumbi/simple-log-service/issues

Additional Resources
• AWS Lambda Documentation
• DynamoDB Best Practices
• API Gateway Documentation
• Terraform AWS Provider

Document Owner: Infrastructure Team  
Review Cycle: Quarterly  
Next Review: 2026-05-02
