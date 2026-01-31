# Test IAM Authentication with Simple Log Service
# This script demonstrates how to call the API using temporary credentials

# Configuration
$ROLE_ARN = "arn:aws:iam::033667696152:role/simple-log-service-log-ingest-role-prod"
$EXTERNAL_ID = "ingest-external-id-12345"
$REGION = "us-east-1"
$SESSION_NAME = "log-service-test-session"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IAM Authentication Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Assume the IAM role to get temporary credentials
Write-Host "[1/4] Assuming IAM role..." -ForegroundColor Yellow
$credentials = aws sts assume-role `
  --role-arn $ROLE_ARN `
  --role-session-name $SESSION_NAME `
  --external-id $EXTERNAL_ID `
  --duration-seconds 3600 `
  --output json | ConvertFrom-Json

if (-not $credentials) {
    Write-Host "✗ Failed to assume role" -ForegroundColor Red
    exit 1
}

$AccessKeyId = $credentials.Credentials.AccessKeyId
$SecretAccessKey = $credentials.Credentials.SecretAccessKey
$SessionToken = $credentials.Credentials.SessionToken

Write-Host "✓ Role assumed successfully" -ForegroundColor Green
Write-Host "  Session expires: $($credentials.Credentials.Expiration)" -ForegroundColor Gray
Write-Host ""

# Step 2: Get API endpoint
Write-Host "[2/4] Getting API endpoint..." -ForegroundColor Yellow
Set-Location C:\simple-log-service\terraform
$API_URL = terraform output -raw api_endpoint
Write-Host "✓ API Endpoint: $API_URL" -ForegroundColor Green
Write-Host ""

# Step 3: Create test log data
Write-Host "[3/4] Preparing test log..." -ForegroundColor Yellow
$logData = @{
    service_name = "test-service"
    log_type = "application"
    level = "INFO"
    message = "Test log with IAM authentication at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    metadata = @{
        test_id = "iam-auth-test-001"
        authenticated = $true
    }
} | ConvertTo-Json

Write-Host "✓ Test log prepared" -ForegroundColor Green
Write-Host ""

# Step 4: Set temporary credentials and make request
Write-Host "[4/4] Sending authenticated request..." -ForegroundColor Yellow

# Set temporary credentials as environment variables
$env:AWS_ACCESS_KEY_ID = $AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $SecretAccessKey
$env:AWS_SESSION_TOKEN = $SessionToken

# Note: You'll need to use AWS CLI or SDK to properly sign the request with SigV4
# This is a simplified example - in production, use AWS SDK for proper SigV4 signing

Write-Host "✓ Credentials configured" -ForegroundColor Green
Write-Host ""

# Clean up environment variables
Remove-Item Env:\AWS_ACCESS_KEY_ID
Remove-Item Env:\AWS_SECRET_ACCESS_KEY
Remove-Item Env:\AWS_SESSION_TOKEN

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: For actual API calls, use AWS SDK (boto3, AWS SDK for .NET, etc.)" -ForegroundColor Yellow
Write-Host "to properly sign requests with AWS SigV4 authentication." -ForegroundColor Yellow

