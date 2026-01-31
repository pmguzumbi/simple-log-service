
# PowerShell Deployment Script for Simple Log Service
# Compatible with Windows PowerShell

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Simple Log Service - Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Configuration
$ROLE_ARN = "arn:aws:iam::033667696152:role/SimpleLogServiceDeploymentRole"
$EXTERNAL_ID = "simple-log-service-deployment"
$SESSION_NAME = "simple-log-service-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"
$REGION = "eu-west-2"

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Terraform is not installed" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Error: AWS CLI is not installed" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Python is not installed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All prerequisites met" -ForegroundColor Green

# Check if AWS_PROFILE is set
if (-not $env:AWS_PROFILE) {
    Write-Host "`nAWS_PROFILE not set. Attempting to use role assumption..." -ForegroundColor Yellow
    
    # Assume role and export credentials
    Write-Host "Assuming role: $ROLE_ARN" -ForegroundColor Yellow
    
    $credentials = aws sts assume-role `
        --role-arn $ROLE_ARN `
        --role-session-name $SESSION_NAME `
        --external-id $EXTERNAL_ID `
        --duration-seconds 3600 `
        --query 'Credentials' `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to assume role" -ForegroundColor Red
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "1. Base AWS credentials are configured" -ForegroundColor Yellow
        Write-Host "2. Role exists: $ROLE_ARN" -ForegroundColor Yellow
        Write-Host "3. Trust policy allows assumption" -ForegroundColor Yellow
        exit 1
    }
    
    # Export temporary credentials
    $env:AWS_ACCESS_KEY_ID = $credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $credentials.SessionToken
    $env:AWS_REGION = $REGION
    
    Write-Host "✓ Role assumed successfully" -ForegroundColor Green
} else {
    Write-Host "Using AWS profile: $env:AWS_PROFILE" -ForegroundColor Green
}

# Verify AWS credentials
Write-Host "`nVerifying AWS credentials..." -ForegroundColor Yellow
$callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: AWS credentials not configured or invalid" -ForegroundColor Red
    exit 1
}

$accountId = $callerIdentity.Account
$userArn = $callerIdentity.Arn

Write-Host "✓ AWS Account: $accountId" -ForegroundColor Green
Write-Host "✓ Identity: $userArn" -ForegroundColor Green

# Verify correct account
if ($accountId -ne "033667696152") {
    Write-Host "Warning: Deploying to account $accountId (expected 033667696152)" -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Navigate to terraform directory
Set-Location "$PSScriptRoot\..\terraform"

# Initialize Terraform
Write-Host "`nInitializing Terraform..." -ForegroundColor Yellow
terraform init

# Validate configuration
Write-Host "`nValidating Terraform configuration..." -ForegroundColor Yellow
terraform validate

# Plan deployment
Write-Host "`nPlanning deployment..." -ForegroundColor Yellow
terraform plan -out=tfplan

# Confirm deployment
Write-Host ""
$confirm = Read-Host "Do you want to apply this plan? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    Remove-Item tfplan -ErrorAction SilentlyContinue
    exit 0
}

# Apply deployment
Write-Host "`nDeploying infrastructure..." -ForegroundColor Yellow
terraform apply tfplan

# Clean up plan file
Remove-Item tfplan -ErrorAction SilentlyContinue

# Get outputs
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "API Gateway URL:" -ForegroundColor Yellow
terraform output -raw api_gateway_url
Write-Host "`n"
Write-Host "DynamoDB Table:" -ForegroundColor Yellow
terraform output -raw dynamodb_table_name
Write-Host "`n"
Write-Host "CloudWatch Dashboard:" -ForegroundColor Yellow
$dashboardName = terraform output -raw cloudwatch_dashboard_name
Write-Host "https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$dashboardName"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run tests: cd ..\scripts; python test_api.py" -ForegroundColor White
Write-Host "2. View logs: aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --follow" -ForegroundColor White
Write-Host "3. Monitor: Open CloudWatch dashboard (URL above)" -ForegroundColor White
Write-Host ""
Write-Host "Note: Temporary credentials expire in 1 hour" -ForegroundColor Yellow
Write-Host ""

