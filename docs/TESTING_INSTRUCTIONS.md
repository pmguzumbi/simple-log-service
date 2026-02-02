SIMPLE LOG SERVICE - COMPLETE TESTING INSTRUCTIONS

Version: 1.0
Date: 2026-02-02

TABLE OF CONTENTS

Prerequisites
Test Script 1: Complete-Test-Script (Basic Lambda Test)
Test Script 2: API-Gateway-Test (API Endpoint Test)
Running Instructions
Expected Outputs
Troubleshooting Guide
Test Comparison Matrix

PREREQUISITES

SYSTEM REQUIREMENTS

Operating System:
  Windows with PowerShell 5.1 or higher

Python:
  Version 3.x (required for API Gateway test only)

AWS CLI:
  Configured with valid credentials

Terraform:
  Infrastructure deployed and state file exists

Network:
  Internet connectivity for AWS API calls

VERIFICATION COMMANDS

Check PowerShell version:

$PSVersionTable.PSVersion

Check AWS CLI:

aws --version
aws sts get-caller-identity

Check Terraform state:

cd C:\simple-log-service\terraform
terraform show

Check Python (API Gateway test only):

python --version

PYTHON DEPENDENCIES (API GATEWAY TEST ONLY)

Install required packages:

pip install requests requests-aws4auth

Verify installation:

pip list | findstr requests

TEST SCRIPT 1: COMPLETE-TEST-SCRIPT (BASIC LAMBDA TEST)

PURPOSE

Tests Lambda functions directly with IAM role assumption to validate backend functionality.

SCRIPT LOCATION

C:\simple-log-service\scripts\complete-test-script.ps1

WHAT IT TESTS

  ✅ Direct Lambda invocation (without assumed role)
  ✅ Ingest role assumption with external ID
  ✅ Lambda write operations (POST logs)
  ✅ Read role assumption with external ID
  ✅ Lambda read operations (GET recent logs)
  ✅ DynamoDB table verification (status, encryption, PITR)
  ✅ CloudWatch logs existence check

RUNNING THE SCRIPT

Basic Execution:

cd C:\simple-log-service\scripts
.\complete-test-script.ps1

With Custom Parameters:

.\complete-test-script.ps1 -TerraformPath "C:\simple-log-service\terraform" -TestCount 5 -Environment prod

PARAMETERS

TerraformPath:
  Path to Terraform directory
  Default: C:\simple-log-service\terraform

TestCount:
  Number of test logs to send
  Default: 3

Environment:
  Environment name for external IDs
  Default: prod

TEST FLOW

Step 1: Prerequisites Check
• Verify Terraform directory exists
• Check Terraform state file
• Validate AWS credentials

Step 2: Get Infrastructure Information
• Extract Lambda function names from Terraform outputs
• Extract IAM role ARNs from Terraform outputs
• Extract DynamoDB table name from Terraform outputs

Step 3: Test Direct Lambda Invocation
• Invoke Ingest Lambda without assumed role
• Verify successful execution

Step 4: Test Ingest Role (Write Access)
• Assume ingest role with external ID
• Send test logs to Ingest Lambda
• Verify successful writes

Step 5: Test Read Role (Read Access)
• Assume read role with external ID
• Invoke Read Lambda to retrieve logs
• Verify successful reads

Step 6: Verify DynamoDB Table
• Check table status (ACTIVE)
• Verify encryption enabled
• Verify point-in-time recovery enabled
• Count items in table

Step 7: Verify CloudWatch Logs
• Check Ingest Lambda log group exists
• Check Read Lambda log group exists

EXPECTED OUTPUT

Color Coding:
• Cyan: Test step headers
• Green: Passed tests with checkmarks
• Red: Failed tests with error details
• Yellow: Informational messages

Success Message:

ALL TESTS PASSED

End Time: 2026-02-02 13:30:45

Failure Message:

SOME TESTS FAILED

Please review the errors above and check:
• AWS credentials are valid
• Terraform infrastructure is deployed
• IAM roles have correct permissions
• External IDs match role trust policies

TEST SCRIPT 2: API-GATEWAY-TEST (API ENDPOINT TEST)

PURPOSE

Tests API Gateway endpoints with AWS SigV4 authentication to validate end-to-end API functionality.

SCRIPT LOCATION

C:\simple-log-service\scripts\api-gateway-test.ps1

WHAT IT TESTS

  ✅ Python dependencies (requests, requests-aws4auth)
  ✅ API Gateway POST /logs endpoint (ingest with SigV4)
  ✅ API Gateway GET /logs/recent endpoint (read with SigV4)
  ✅ IAM authentication via role assumption
  ✅ DynamoDB data verification via table scan

RUNNING THE SCRIPT

First-Time Setup:

pip install requests requests-aws4auth

Basic Execution:

cd C:\simple-log-service\scripts
.\api-gateway-test.ps1

With Custom Parameters:

.\api-gateway-test.ps1 -TerraformPath "C:\simple-log-service\terraform" -TestCount 3 -Environment prod

PARAMETERS

TerraformPath:
  Path to Terraform directory
  Default: C:\simple-log-service\terraform

TestCount:
  Number of test API requests
  Default: 3

Environment:
  Environment name for external IDs
  Default: prod

TEST FLOW

Step 1: Prerequisites Check
• Verify Python installation
• Check Python dependencies (requests, requests-aws4auth)
• Validate AWS credentials
• Check Terraform state file

Step 2: Get Infrastructure Information
• Extract API Gateway endpoint from Terraform outputs
• Extract IAM role ARNs from Terraform outputs
• Extract DynamoDB table name from Terraform outputs

Step 3: Test POST /logs (Ingest Endpoint)
• Assume ingest role with external ID
• Create test log payload
• Sign request with AWS SigV4
• Send POST request to API Gateway
• Verify HTTP 201 response

Step 4: Test GET /logs/recent (Read Endpoint)
• Assume read role with external ID
• Sign request with AWS SigV4
• Send GET request to API Gateway
• Verify HTTP 200 response
• Verify logs retrieved

Step 5: Verify DynamoDB Data
• Scan DynamoDB table
• Count items
• Verify test logs exist

EXPECTED OUTPUT

Color Coding:
• Cyan: Test step headers
• Green: Passed tests with checkmarks
• Red: Failed tests with error details
• Yellow: Informational messages

Success Message:

ALL API GATEWAY TESTS PASSED

End Time: 2026-02-02 13:35:30

Failure Message:

SOME API GATEWAY TESTS FAILED

Please review the errors above and check:
• Python dependencies are installed
• API Gateway endpoint is correct
• IAM roles have execute-api:Invoke permission
• AWS SigV4 signing is working correctly

RUNNING INSTRUCTIONS

SEQUENTIAL EXECUTION (RECOMMENDED)

Run both tests in sequence to validate complete system:

cd C:\simple-log-service\scripts

.\complete-test-script.ps1 -TestCount 5 -Environment prod

.\api-gateway-test.ps1 -TestCount 3 -Environment prod

PARALLEL EXECUTION (ADVANCED)

Run both tests simultaneously for faster results:

Open two PowerShell windows

Window 1:

cd C:\simple-log-service\scripts
.\complete-test-script.ps1 -TestCount 5 -Environment prod

Window 2:

cd C:\simple-log-service\scripts
.\api-gateway-test.ps1 -TestCount 3 -Environment prod

AUTOMATED TEST RUNNER

Create a master script to run both tests with consolidated reporting:

Create file: C:\simple-log-service\scripts\run-all-tests.ps1

Content:

param(
    [int]$TestCount = 3,
    [string]$Environment = "prod"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running All Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$startTime = Get-Date
Write-Host "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow

Write-Host "n[TEST 1] Running Complete-Test-Script..." -ForegroundColor Cyan
.\complete-test-script.ps1 -TestCount $TestCount -Environment $Environment
$test1Result = $LASTEXITCODE

Write-Host "n[TEST 2] Running API-Gateway-Test..." -ForegroundColor Cyan
.\api-gateway-test.ps1 -TestCount $TestCount -Environment $Environment
$test2Result = $LASTEXITCODE

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete-Test-Script: $(if ($test1Result -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($test1Result -eq 0) { 'Green' } else { 'Red' })
Write-Host "API-Gateway-Test: $(if ($test2Result -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($test2Result -eq 0) { 'Green' } else { 'Red' })
Write-Host "Total Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Yellow
Write-Host "End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow

if ($test1Result -eq 0 -and $test2Result -eq 0) {
    Write-Host "n✓ ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}

Run the master script:

cd C:\simple-log-service\scripts
.\run-all-tests.ps1 -TestCount 5 -Environment prod

EXPECTED OUTPUTS

COMPLETE-TEST-SCRIPT OUTPUT EXAMPLE

Simple Log Service - Basic Test

Start Time: 2026-02-02 13:30:15

[STEP] Checking Prerequisites
  [PASS] Terraform directory exists
  [PASS] Terraform state file exists
  [PASS] AWS credentials valid (Account: <Account ID>)

[STEP] Getting Infrastructure Information
  [PASS] API Endpoint: https://v22n8t8394.execute-api.us-east-1.amazonaws.com/prod
  [PASS] DynamoDB Table: simple-log-service-logs-prod
  [PASS] Ingest Lambda: simple-log-service-ingest-prod
  [PASS] Read Lambda: simple-log-service-read-recent-prod
  [PASS] Ingest Role ARN: arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod
  [PASS] Read Role ARN: arn:aws:iam::<Account ID>:role/simple-log-service-read-prod

[STEP] Testing Direct Lambda Invocation (Without Assumed Role)
  [PASS] Direct Lambda invocation successful

[STEP] Testing Ingest Role (Write Access)
  [PASS] Role assumed successfully with external ID: simple-log-service-ingest-prod
  [PASS] Test log 1/5 sent successfully
  [PASS] Test log 2/5 sent successfully
  [PASS] Test log 3/5 sent successfully
  [PASS] Test log 4/5 sent successfully
  [PASS] Test log 5/5 sent successfully
  [PASS] Ingest tests: 5/5 successful

[STEP] Testing Read Role (Read Access)
  [PASS] Role assumed successfully with external ID: simple-log-service-read-prod
  [PASS] Read test successful (Retrieved 5 logs)

[STEP] Verifying DynamoDB Table
  [PASS] Table Status: ACTIVE
  [PASS] Item Count: 5
  [PASS] Encryption: ENABLED
  [PASS] Point-in-Time Recovery: ENABLED

[STEP] Verifying CloudWatch Logs
  [PASS] Ingest Lambda log group exists: /aws/lambda/simple-log-service-ingest-prod
  [PASS] Read Lambda log group exists: /aws/lambda/simple-log-service-read-recent-prod

ALL TESTS PASSED

End Time: 2026-02-02 13:30:45

API-GATEWAY-TEST OUTPUT EXAMPLE

Simple Log Service - API Gateway Test

Start Time: 2026-02-02 13:35:00

[STEP] Checking Prerequisites
  [PASS] Python installed: Python 3.12.10
  [PASS] requests library installed
  [PASS] requests-aws4auth library installed
  [PASS] AWS credentials valid (Account: <Account ID>)
  [PASS] Terraform state file exists

[STEP] Getting Infrastructure Information
  [PASS] API Endpoint: https://v22n8t8394.execute-api.us-east-1.amazonaws.com/prod
  [PASS] DynamoDB Table: simple-log-service-logs-prod
  [PASS] Ingest Role ARN: arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod
  [PASS] Read Role ARN: arn:aws:iam::<Account ID>:role/simple-log-service-read-prod

[STEP] Testing POST /logs (Ingest Endpoint)
  [PASS] Role assumed successfully with external ID: simple-log-service-ingest-prod
  [PASS] POST request 1/3 successful (HTTP 201)
  [PASS] POST request 2/3 successful (HTTP 201)
  [PASS] POST request 3/3 successful (HTTP 201)
  [PASS] POST /logs tests: 3/3 successful

[STEP] Testing GET /logs/recent (Read Endpoint)
  [PASS] Role assumed successfully with external ID: simple-log-service-read-prod
  [PASS] GET /logs/recent successful (HTTP 200)
  [PASS] Retrieved 3 logs

[STEP] Verifying DynamoDB Data
  [PASS] DynamoDB table scan successful
  [PASS] Item count: 3
  [PASS] Test logs verified in DynamoDB

ALL API GATEWAY TESTS PASSED

End Time: 2026-02-02 13:35:30

TROUBLESHOOTING GUIDE

COMMON ISSUES AND SOLUTIONS

ISSUE 1: "TERRAFORM STATE FILE NOT FOUND"

Symptom:

[FAIL] Terraform state file not found

Solution:

Ensure Terraform infrastructure is deployed:

cd C:\simple-log-service\terraform
terraform init
terraform apply

Verify state file exists:

dir terraform.tfstate

ISSUE 2: "FAILED TO ASSUME ROLE"

Symptom:

[FAIL] Failed to assume role: AccessDenied

Solutions:
Verify external IDs match in IAM trust policies
Check your AWS credentials have sts:AssumeRole permission
Verify role ARNs are correct in Terraform outputs

Verification Commands:

Check role trust policy:

aws iam get-role --role-name simple-log-service-ingest-prod --query 'Role.AssumeRolePolicyDocument'

Test role assumption:

aws sts assume-role --role-arn "arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod" --role-session-name "test-session" --external-id "simple-log-service-ingest-prod"

Check your IAM permissions:

aws iam get-role-policy --role-name YOURROLENAME --policy-name YOURPOLICY_NAME

ISSUE 3: "PYTHON NOT FOUND" (API GATEWAY TEST)

Symptom:

[FAIL] Python not found

Solution:
Install Python from https://www.python.org/downloads/
Add Python to system PATH
Restart PowerShell

Verification:

python --version
pip --version

ISSUE 4: "403 FORBIDDEN" ERRORS

Symptom:

[FAIL] POST /logs failed: HTTP 403 Forbidden

Solutions:
Check IAM role permissions for execute-api:Invoke
Verify API Gateway authorization is set to AWS_IAM
Check API Gateway resource policy

Verification Commands:

Check IAM role policy:

aws iam get-role-policy --role-name simple-log-service-ingest-prod --policy-name IngestPolicy

Check API Gateway configuration:

aws apigateway get-method --rest-api-id YOURAPIID --resource-id YOURRESOURCEID --http-method POST

Test API Gateway endpoint:

aws apigateway test-invoke-method --rest-api-id YOURAPIID --resource-id YOURRESOURCEID --http-method POST --body "{\"test\":\"data\"}"

ISSUE 5: "NO LOGS RETRIEVED"

Symptom:

[FAIL] Read test failed: No logs retrieved

Solutions:
Increase wait time for DynamoDB consistency (change from 3 to 5 seconds)
Check CloudWatch logs for Lambda errors
Verify DynamoDB table has items

Verification Commands:

Check DynamoDB items:

aws dynamodb scan --table-name simple-log-service-logs-prod --limit 10

Check Lambda logs:

aws logs tail /aws/lambda/simple-log-service-ingest-prod --follow

Check Lambda errors:

aws logs filter-log-events --log-group-name /aws/lambda/simple-log-service-ingest-prod --filter-pattern "ERROR"

ISSUE 6: "INVALID JSON" OR "UTF-8 ENCODING" ERRORS

Symptom:

[FAIL] Invalid JSON response
[FAIL] UTF-8 encoding error

Solution:

Scripts already use UTF-8 without BOM encoding. If issue persists:
Re-save script files with UTF-8 encoding (no BOM)
Check for special characters in test data
Verify JSON payload is properly formatted

Verification:

Test JSON payload:

$testPayload = @{
    service_name = "test-service"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    level = "INFO"
    message = "Test message"
} | ConvertTo-Json

Write-Host $testPayload

ISSUE 7: "TERRAFORM OUTPUT IS NOT VALID JSON"

Symptom:

[FAIL] Failed to parse Terraform outputs

Solutions:
Verify Terraform state is up to date:

cd C:\simple-log-service\terraform
terraform refresh
Check Terraform outputs manually:

terraform output -json
Verify all required outputs exist:

terraform output api_endpoint
terraform output dynamodbtablename
terraform output ingestlambdafunction_name
terraform output readrecentlambdafunctionname
terraform output logingestrole_arn
terraform output logreadrole_arn

TEST COMPARISON MATRIX

FEATURE COMPARISON

Feature: Primary Focus
  Complete-Test-Script: Lambda function validation
  API-Gateway-Test: API Gateway endpoint validation

Feature: Authentication Method
  Complete-Test-Script: IAM role assumption
  API-Gateway-Test: AWS SigV4 + IAM role assumption

Feature: Dependencies
  Complete-Test-Script: AWS CLI only
  API-Gateway-Test: Python + requests + requests-aws4auth

Feature: Test Target
  Complete-Test-Script: Backend Lambda functions
  API-Gateway-Test: End-to-end API calls

Feature: Execution Speed
  Complete-Test-Script: Faster (~15-20 seconds)
  API-Gateway-Test: Slightly slower (~20-30 seconds)

Feature: Use Case
  Complete-Test-Script: Backend validation
  API-Gateway-Test: Client integration testing

Feature: CloudWatch Logs
  Complete-Test-Script: Checks log group existence
  API-Gateway-Test: Not checked

Feature: DynamoDB Verification
  Complete-Test-Script: Full (status, encryption, PITR)
  API-Gateway-Test: Basic (scan items)

Feature: External ID Support
  Complete-Test-Script: ✅ Yes
  API-Gateway-Test: ✅ Yes

Feature: Color-Coded Output
  Complete-Test-Script: ✅ Yes
  API-Gateway-Test: ✅ Yes

Feature: Error Handling
  Complete-Test-Script: ✅ Comprehensive
  API-Gateway-Test: ✅ Comprehensive

Feature: Cleanup
  Complete-Test-Script: ✅ Automatic
  API-Gateway-Test: ✅ Automatic

WHEN TO USE EACH SCRIPT

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

ADDITIONAL RESOURCES

SCRIPT LOCATIONS

Complete-Test-Script:
  C:\simple-log-service\scripts\complete-test-script.ps1

API-Gateway-Test:
  C:\simple-log-service\scripts\api-gateway-test.ps1

Terraform Configuration:
  C:\simple-log-service\terraform\

AWS RESOURCES

DynamoDB Table:
  simple-log-service-logs-prod

Ingest Lambda:
  simple-log-service-ingest-prod

Read Lambda:
  simple-log-service-read-recent-prod

Ingest Role:
  simple-log-service-ingest-prod

Read Role:
  simple-log-service-read-prod

EXTERNAL IDS

Ingest:
  simple-log-service-ingest-prod

Read:
  simple-log-service-read-prod

CLOUDWATCH LOG GROUPS

Ingest Lambda:
  /aws/lambda/simple-log-service-ingest-prod

Read Lambda:
  /aws/lambda/simple-log-service-read-recent-prod

API Gateway:
  /aws/apigateway/simple-log-service-prod

VERSION HISTORY

v1.0 (2026-02-02):
  Initial comprehensive testing documentation

SUPPORT

For issues or questions:
Review troubleshooting guide above
Check CloudWatch logs for detailed error messages
Verify AWS credentials and permissions
Ensure Terraform infrastructure is properly deployed

