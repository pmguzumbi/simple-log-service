# Simple Log Service - Basic Test Script
# Version: 1.1 - Fixed Terraform output names
# Date: 2026-02-01

#Requires -Version 5.1

param(
    [Parameter(Mandatory=$false)]
    [string]$TerraformPath = "C:\simple-log-service\terraform",
    
    [Parameter(Mandatory=$false)]
    [int]$TestCount = 3
)

$ErrorActionPreference = "Stop"

# Color-coded output functions
function Write-Step { param([string]$Msg) Write-Host "`n[STEP] $Msg" -ForegroundColor Cyan }
function Write-Pass { param([string]$Msg) Write-Host "  [PASS] $Msg" -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor Yellow }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Simple Log Service - Basic Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

try {
    # STEP 1: Check Prerequisites
    Write-Step "Checking Prerequisites"
    
    if (-not (Test-Path $TerraformPath)) {
        Write-Fail "Terraform directory not found: $TerraformPath"
        exit 1
    }
    Write-Pass "Terraform directory exists"
    
    if (-not (Test-Path "$TerraformPath\terraform.tfstate")) {
        Write-Fail "Terraform state file not found - infrastructure may not be deployed"
        Write-Info "Run: cd $TerraformPath; terraform apply"
        exit 1
    }
    Write-Pass "Terraform state file exists"
    
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Pass "AWS credentials valid (Account: $($identity.Account))"
    }
    catch {
        Write-Fail "AWS credentials not configured"
        Write-Info "Run: aws configure"
        exit 1
    }
    
    # STEP 2: Get Infrastructure Info
    Write-Step "Getting Infrastructure Information"
    
    Push-Location $TerraformPath
    
    try {
        Write-Info "Retrieving Terraform outputs..."
        $tfOutput = terraform output -json | ConvertFrom-Json
        
        # Use the ACTUAL output names from your Terraform configuration
        $API_ENDPOINT = $tfOutput.api_endpoint.value
        $TABLE_NAME = $tfOutput.dynamodb_table_name.value
        $INGEST_FUNCTION = $tfOutput.ingest_lambda_function_name.value
        $READ_FUNCTION = $tfOutput.read_recent_lambda_function_name.value
        $INGEST_ROLE = $tfOutput.log_ingest_role_arn.value
        $READ_ROLE = $tfOutput.log_read_role_arn.value
        $FULL_ROLE = $tfOutput.log_full_access_role_arn.value
        
        if (-not $API_ENDPOINT -or -not $TABLE_NAME -or -not $INGEST_FUNCTION) {
            Write-Fail "Missing required Terraform outputs"
            Write-Info "Available outputs:"
            terraform output
            exit 1
        }
        
        Write-Pass "API Endpoint: $API_ENDPOINT"
        Write-Pass "DynamoDB Table: $TABLE_NAME"
        Write-Pass "Ingest Lambda: $INGEST_FUNCTION"
        Write-Pass "Read Lambda: $READ_FUNCTION"
    }
    finally {
        Pop-Location
    }
    
    # STEP 3: Test Ingest Role
    Write-Step "Testing Ingest Role (Write Access)"
    
    Write-Info "Assuming ingest role..."
    $ingestCreds = aws sts assume-role `
        --role-arn $INGEST_ROLE `
        --role-session-name "test-$(Get-Date -Format 'HHmmss')" `
        --duration-seconds 900 `
        --output json | ConvertFrom-Json
    
    $env:AWS_ACCESS_KEY_ID = $ingestCreds.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $ingestCreds.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $ingestCreds.Credentials.SessionToken
    
    Write-Pass "Role assumed successfully"
    
    $successCount = 0
    for ($i = 1; $i -le $TestCount; $i++) {
        $payload = @{
            service_name = "test-app"
            level = "INFO"
            message = "Test message $i"
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } | ConvertTo-Json -Compress
        
        $payload | Out-File "test-payload.json" -Encoding utf8 -NoNewline
        
        aws lambda invoke `
            --function-name $INGEST_FUNCTION `
            --payload file://test-payload.json `
            --cli-binary-format raw-in-base64-out `
            "response.json" 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Info "Test $i/$TestCount completed"
        }
        else {
            Write-Fail "Test $i/$TestCount failed"
        }
    }
    
    Write-Pass "Ingest tests: $successCount/$TestCount successful"
    
    # Clear credentials
    Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    
    # Wait for DynamoDB consistency
    Start-Sleep -Seconds 2
    
    # STEP 4: Test Read Role
    Write-Step "Testing Read Role (Read Access)"
    
    Write-Info "Assuming read role..."
    $readCreds = aws sts assume-role `
        --role-arn $READ_ROLE `
        --role-session-name "test-$(Get-Date -Format 'HHmmss')" `
        --duration-seconds 900 `
        --output json | ConvertFrom-Json
    
    $env:AWS_ACCESS_KEY_ID = $readCreds.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $readCreds.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $readCreds.Credentials.SessionToken
    
    Write-Pass "Role assumed successfully"
    
    $readPayload = @{
        service_name = "test-app"
        limit = 10
    } | ConvertTo-Json -Compress
    
    $readPayload | Out-File "read-payload.json" -Encoding utf8 -NoNewline
    
    aws lambda invoke `
        --function-name $READ_FUNCTION `
        --payload file://read-payload.json `
        --cli-binary-format raw-in-base64-out `
        "read-response.json" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        $result = Get-Content "read-response.json" | ConvertFrom-Json
        $logCount = if ($result.logs) { $result.logs.Count } else { 0 }
        Write-Pass "Read test successful (Retrieved $logCount logs)"
    }
    else {
        Write-Fail "Read test failed"
        $errorContent = Get-Content "read-response.json" -Raw
        Write-Info "Error response: $errorContent"
    }
    
    # Clear credentials
    Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    
    # STEP 5: Verify DynamoDB
    Write-Step "Verifying DynamoDB Table"
    
    $tableInfo = aws dynamodb describe-table --table-name $TABLE_NAME --output json | ConvertFrom-Json
    
    Write-Pass "Table Status: $($tableInfo.Table.TableStatus)"
    Write-Pass "Item Count: $($tableInfo.Table.ItemCount)"
    Write-Pass "Encryption: $($tableInfo.Table.SSEDescription.Status)"
    
    # Cleanup
    Remove-Item test-payload.json, read-payload.json, response.json, read-response.json -ErrorAction SilentlyContinue
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host ""
    
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "TEST FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nStack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    
    # Cleanup
    Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    Remove-Item test-payload.json, read-payload.json, response.json, read-response.json -ErrorAction SilentlyContinue
    
    exit 1
}
