Simple Log Service - Complete Testing Instructions
Version: 1.0
Date: 2026-02-02

Table of Contents
Prerequisites
Test Script 1: Complete-Test-Script (Basic Lambda Test)
Test Script 2: API-Gateway-Test (API Endpoint Test)
Running Instructions
Expected Outputs
Troubleshooting Guide
Test Comparison Matrix

Prerequisites

System Requirements
• Operating System: Windows with PowerShell 5.1 or higher
• Python: Version 3.x (required for API Gateway test only)
• AWS CLI: Configured with valid credentials
• Terraform: Infrastructure deployed and state file exists
• Network: Internet connectivity for AWS API calls

Verification Commands

Python Dependencies (API Gateway Test Only)

Test Script 1: Complete-Test-Script (Basic Lambda Test)

Purpose
Tests Lambda functions directly with IAM role assumption to validate backend functionality.

Script Location
C:\simple-log-service\complete-test-script.ps1

What It Tests
✅ Direct Lambda invocation (without assumed role)
✅ Ingest role assumption with external ID
✅ Lambda write operations (POST logs)
✅ Read role assumption with external ID
✅ Lambda read operations (GET recent logs)
✅ DynamoDB table verification (status, encryption, PITR)
✅ CloudWatch logs existence check

Running the Script

Basic Execution:

With Custom Parameters:

Parameters
• TerraformPath: Path to Terraform directory (default: C:\simple-log-service\terraform)
• TestCount: Number of test logs to send (default: 3)
• Environment: Environment name for external IDs (default: prod)

Test Flow

Expected Output
• Cyan: Test step headers
• Green: Passed tests with checkmarks
• Red: Failed tests with error details
• Yellow: Informational messages

Success Message:

Failure Message:

Test Script 2: API-Gateway-Test (API Endpoint Test)

Purpose
Tests API Gateway endpoints with AWS SigV4 authentication to validate end-to-end API functionality.

Script Location
C:\simple-log-service\api-gateway-test.ps1

What It Tests
✅ Python dependencies (requests, requests-aws4auth)
✅ API Gateway POST /logs endpoint (ingest with SigV4)
✅ API Gateway GET /logs/recent endpoint (read with SigV4)
✅ IAM authentication via role assumption
✅ DynamoDB data verification via table scan

Running the Script

First-Time Setup:

Basic Execution:

With Custom Parameters:

Parameters
• TerraformPath: Path to Terraform directory (default: C:\simple-log-service\terraform)
• TestCount: Number of test API requests (default: 3)
• Environment: Environment name for external IDs (default: prod)

Test Flow

Expected Output
• Cyan: Test step headers
• Green: Passed tests with checkmarks
• Red: Failed tests with error details
• Yellow: Informational messages

Success Message:

Failure Message:

Running Instructions

Sequential Execution (Recommended)
Run both tests in sequence to validate complete system:

Parallel Execution (Advanced)
Run both tests simultaneously for faster results:

Automated Test Runner
Create a master script to run both tests with consolidated reporting:

Expected Outputs

Complete-Test-Script Output Example

API-Gateway-Test Output Example

Troubleshooting Guide

Common Issues and Solutions

Issue 1: "Terraform state file not found"
Symptom:

Solution:

Issue 2: "Failed to assume role"
Symptom:

Solutions:
Verify external IDs match in IAM trust policies
Check your AWS credentials have sts:AssumeRole permission
Verify role ARNs are correct in Terraform outputs

Verification Commands:

Issue 3: "Python not found" (API Gateway Test)
Symptom:

Solution:
Install Python from https://www.python.org/downloads/
Add Python to system PATH
Restart PowerShell

Verification:

Issue 4: "403 Forbidden" Errors
Symptom:

Solutions:
Check IAM role permissions for execute-api:Invoke
Verify API Gateway authorization is set to AWS_IAM
Check API Gateway resource policy

Verification Commands:

Issue 5: "No logs retrieved"
Symptom:

Solutions:
Increase wait time for DynamoDB consistency (change from 3 to 5 seconds)
Check CloudWatch logs for Lambda errors
Verify DynamoDB table has items

Verification Commands:

Issue 6: "Invalid JSON" or "UTF-8 Encoding" Errors
Symptom:

Solution:
Scripts already use UTF-8 without BOM encoding. If issue persists:

Issue 7: "Terraform output is not valid JSON"
Symptom:

Solutions:

Test Comparison Matrix

| Feature | Complete-Test-Script | API-Gateway-Test |
|---------|---------------------|------------------|
| Primary Focus | Lambda function validation | API Gateway endpoint validation |
| Authentication Method | IAM role assumption | AWS SigV4 + IAM role assumption |
| Dependencies | AWS CLI only | Python + requests + requests-aws4auth |
| Test Target | Backend Lambda functions | End-to-end API calls |
| Execution Speed | Faster (~15-20 seconds) | Slightly slower (~20-30 seconds) |
| Use Case | Backend validation | Client integration testing |
| CloudWatch Logs | Checks log group existence | Not checked |
| DynamoDB Verification | Full (status, encryption, PITR) | Basic (scan items) |
| External ID Support | ✅ Yes | ✅ Yes |
| Color-Coded Output | ✅ Yes | ✅ Yes |
| Error Handling | ✅ Comprehensive | ✅ Comprehensive |
| Cleanup | ✅ Automatic | ✅ Automatic |

When to Use Each Script

Use Complete-Test-Script when:
• Validating Lambda function logic
• Testing IAM role permissions
• Verifying DynamoDB configuration
• Checking CloudWatch log setup
• Debugging backend issues

Use API-Gateway-Test when:
• Testing API Gateway configuration
• Validating end-to-end API flow
• Testing AWS SigV4 authentication
• Simulating client API calls
• Verifying API Gateway IAM authorization

Use Both Scripts when:
• Performing comprehensive system validation
• Preparing for production deployment
• Troubleshooting integration issues
• Validating infrastructure changes
• Running regression tests

Additional Resources

Script Locations
• Complete-Test-Script: C:\simple-log-service\complete-test-script.ps1
• API-Gateway-Test: C:\simple-log-service\api-gateway-test.ps1
• Terraform Configuration: C:\simple-log-service\terraform\

AWS Resources
• DynamoDB Table: simple-log-service-logs-prod
• Ingest Lambda: simple-log-service-ingest-prod
• Read Lambda: simple-log-service-read-recent-prod
• Ingest Role: simple-log-service-ingest-prod
• Read Role: simple-log-service-read-prod

External IDs
• Ingest: simple-log-service-ingest-prod
• Read: simple-log-service-read-prod

CloudWatch Log Groups
• /aws/lambda/simple-log-service-ingest-prod
• /aws/lambda/simple-log-service-read-recent-prod
• /aws/apigateway/simple-log-service-prod

Version History
• v1.0 (2026-02-02): Initial comprehensive testing documentation

Support
For issues or questions:
Review troubleshooting guide above
Check CloudWatch logs for detailed error messages
Verify AWS credentials and permissions
Ensure Terraform infrastructure is properly deployed
