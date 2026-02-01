# Simple Log Service - Basic Test Script with External ID Support
# Version: 1.4 - Maintains external ID for security
# Date: 2026-02-01

#Requires -Version 5.1

param(
    [Parameter(Mandatory=$false)]
    [string]$TerraformPath = "C:\simple-log-service\terraform",
    
    [Parameter(Mandatory=$false)]
    [int]$TestCount = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod"
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
        Write-Info "Current identity: $($identity.Arn)"
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
        Write-Pass "Ingest Role: $INGEST_ROLE"
        Write-Pass "Read Role: $READ_ROLE"
    }
    finally {
        Pop-Location
    }
    
    # Define external IDs for security
    $INGEST_EXTERNAL_ID = "simple-log-service-ingest-$Environment"
    $READ_EXTERNAL_ID = "simple-log-service-read-$Environment"
    $FULL_EXTERNAL_ID = "simple-log-service-full-$Environment"
    
    Write-Info "Using external IDs for secure role assumption:"
    Write-Info "  Ingest: $INGEST_EXTERNAL_ID"
    Write-Info "  Read: $READ_EXTERNAL_ID"
    Write-Info "  Full: $FULL_EXTERNAL_ID"
    
    # STEP 3: Test Ingest Role
    Write-Step "Testing Ingest Role (Write Access)"
    
    Write-Info "Assuming ingest role with external ID..."
    try {
        # Attempt to assume role with external ID
        $ingestCredsRaw = aws sts assume-role `
            --role-arn $INGEST_ROLE `
            --role-session-name "test-ingest-$(Get-Date -Format 'HHmmss')" `
            --external-id $INGEST_EXTERNAL_ID `
            --duration-seconds 900 `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to assume ingest role with external ID"
            Write-Info "Error output: $ingestCredsRaw"
            Write-Info ""
            Write-Info "Troubleshooting steps:"
            Write-Info "  1. Verify your current role has sts:AssumeRole permission"
            Write-Info "  2. Check the trust policy of the target role:"
            Write-Info "     aws iam get-role --role-name simple-log-service-log-ingest-role-$Environment"
            Write-Info "  3. Verify external ID matches: $INGEST_EXTERNAL_ID"
            Write-Info "  4. Ensure trust policy includes your account root or specific role"
            Write-Info ""
            Write-Info "Required trust policy format:"
            Write-Info '  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::033667696152:root"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "' + $INGEST_EXTERNAL_ID + '"
          }
        }
      }
    ]
  }'
            throw "Role assumption failed"
        }
        
        $ingestCreds = $ingestCredsRaw | ConvertFrom-Json
        
        $env:AWS_ACCESS_KEY_ID = $ingestCreds.Credentials.AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $ingestCreds.Credentials.SecretAccessKey
        $env:AWS_SESSION_TOKEN = $ingestCreds.Credentials.SessionToken
        
        Write-Pass "Role assumed successfully with external ID"
        
        $assumedIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Info "Assumed identity: $($assumedIdentity.Arn)"
        
        $successCount = 0
        for ($i = 1; $i -le $TestCount; $i++) {
            $payload = @{
                service_name = "test-app"
                level = "INFO"
                message = "Test message $i from PowerShell test script"
                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            } | ConvertTo-Json -Compress
            
            $payload | Out-File "test-payload.json" -Encoding utf8 -NoNewline
            
            $invokeResult = aws lambda invoke `
                --function-name $INGEST_FUNCTION `
                --payload file://test-payload.json `
                --cli-binary-format raw-in-base64-out `
                "response.json" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $successCount++
                Write-Info "Test $i/$TestCount completed successfully"
            }
            else {
                Write-Fail "Test $i/$TestCount failed"
                Write-Info "Error: $invokeResult"
                if (Test-Path "response.json") {
                    $errorResponse = Get-Content "response.json" -Raw
                    Write-Info "Response: $errorResponse"
                }
            }
        }
        
        Write-Pass "Ingest tests: $successCount/$TestCount successful"
        
        if ($successCount -eq 0) {
            Write-Fail "All ingest tests failed - check Lambda function logs"
            Write-Info "View logs: aws logs tail /aws/lambda/$INGEST_FUNCTION --follow"
        }
    }
    catch {
        Write-Fail "Ingest role test failed: $($_.Exception.Message)"
        throw
    }
    finally {
        Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    }
    
    Write-Info "Waiting 3 seconds for DynamoDB eventual consistency..."
    Start-Sleep -Seconds 3
    
    # STEP 4: Test Read Role
    Write-Step "Testing Read Role (Read Access)"
    
    Write-Info "Assuming read role with external ID..."
    try {
        # Attempt to assume role with external ID
        $readCredsRaw = aws sts assume-role `
            --role-arn $READ_ROLE `
            --role-session-name "test-read-$(Get-Date -Format 'HHmmss')" `
            --external-id $READ_EXTERNAL_ID `
            --duration-seconds 900 `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to assume read role with external ID"
            Write-Info "Error output: $readCredsRaw"
            Write-Info ""
            Write-Info "Troubleshooting steps:"
            Write-Info "  1. Verify your current role has sts:AssumeRole permission"
            Write-Info "  2. Check the trust policy of the target role:"
            Write-Info "     aws iam get-role --role-name simple-log-service-log-read-role-$Environment"
            Write-Info "  3. Verify external ID matches: $READ_EXTERNAL_ID"
            throw "Role assumption failed"
        }
        
        $readCreds = $readCredsRaw | ConvertFrom-Json
        
        $env:AWS_ACCESS_KEY_ID = $readCreds.Credentials.AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $readCreds.Credentials.SecretAccessKey
        $env:AWS_SESSION_TOKEN = $readCreds.Credentials.SessionToken
        
        Write-Pass "Role assumed successfully with external ID"
        
        $assumedIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Info "Assumed identity: $($assumedIdentity.Arn)"
        
        $readPayload = @{
            service_name = "test-app"
            limit = 10
        } | ConvertTo-Json -Compress
        
        $readPayload | Out-File "read-payload.json" -Encoding utf8 -NoNewline
        
        $readResult = aws lambda invoke `
            --function-name $READ_FUNCTION `
            --payload file://read-payload.json `
            --cli-binary-format raw-in-base64-out `
            "read-response.json" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path "read-response.json") {
                $result = Get-Content "read-response.json" | ConvertFrom-Json
                $logCount = if ($result.logs) { $result.logs.Count } else { 0 }
                Write-Pass "Read test successful (Retrieved $logCount logs)"
                
                if ($logCount -gt 0) {
                    Write-Info "Sample log entry:"
                    $sampleLog = $result.logs[0]
                    Write-Info "  Service: $($sampleLog.service_name)"
                    Write-Info "  Level: $($sampleLog.level)"
                    Write-Info "  Message: $($sampleLog.message)"
                    Write-Info "  Timestamp: $($sampleLog.timestamp)"
                }
                elseif ($successCount -gt 0) {
                    Write-Info "No logs retrieved - data may not be consistent yet"
                }
            }
            else {
                Write-Fail "Response file not created"
            }
        }
        else {
            Write-Fail "Read test failed"
            Write-Info "Error: $readResult"
            if (Test-Path "read-response.json") {
                $errorResponse = Get-Content "read-response.json" -Raw
                Write-Info "Response: $errorResponse"
            }
        }
    }
    catch {
        Write-Fail "Read role test failed: $($_.Exception.Message)"
        throw
    }
    finally {
        Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    }
    
    # STEP 5: Verify DynamoDB
    Write-Step "Verifying DynamoDB Table"
    
    try {
        $tableInfo = aws dynamodb describe-table --table-name $TABLE_NAME --output json | ConvertFrom-Json
        
        Write-Pass "Table Status: $($tableInfo.Table.TableStatus)"
        Write-Pass "Item Count: $($tableInfo.Table.ItemCount)"
        
        $tableSizeKB = [math]::Round($tableInfo.Table.TableSizeBytes / 1KB, 2)
        Write-Pass "Table Size: $tableSizeKB KB"
        
        if ($tableInfo.Table.SSEDescription.Status -eq "ENABLED") {
            Write-Pass "Encryption: ENABLED"
            if ($tableInfo.Table.SSEDescription.KMSMasterKeyArn) {
                Write-Info "KMS Key: $($tableInfo.Table.SSEDescription.KMSMasterKeyArn)"
            }
        }
        else {
            Write-Fail "Encryption: NOT ENABLED"
        }
        
        # Check if point-in-time recovery is enabled
        try {
            $pitrStatus = aws dynamodb describe-continuous-backups --table-name $TABLE_NAME --output json | ConvertFrom-Json
            if ($pitrStatus.ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus -eq "ENABLED") {
                Write-Pass "Point-in-Time Recovery: ENABLED"
            }
            else {
                Write-Info "Point-in-Time Recovery: DISABLED"
            }
        }
        catch {
            Write-Info "Could not check Point-in-Time Recovery status"
        }
    }
    catch {
        Write-Fail "DynamoDB verification failed: $($_.Exception.Message)"
    }
    
    # STEP 6: Check CloudWatch Logs
    Write-Step "Checking CloudWatch Logs"
    
    $logGroups = @("/aws/lambda/$INGEST_FUNCTION", "/aws/lambda/$READ_FUNCTION")
    
    foreach ($logGroup in $logGroups) {
        try {
            $streamsRaw = aws logs describe-log-streams `
                --log-group-name $logGroup `
                --order-by LastEventTime `
                --descending `
                --max-items 1 `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $streamInfo = $streamsRaw | ConvertFrom-Json
                if ($streamInfo.logStreams.Count -gt 0) {
                    Write-Pass "Log group exists: $logGroup"
                    $lastEventTime = [DateTimeOffset]::FromUnixTimeMilliseconds($streamInfo.logStreams[0].lastEventTimestamp).DateTime
                    Write-Info "Last event: $($lastEventTime.ToString('yyyy-MM-dd HH:mm:ss'))"
                }
                else {
                    Write-Info "Log group exists but no streams: $logGroup"
                }
            }
            else {
                Write-Info "Log group not accessible: $logGroup"
            }
        }
        catch {
            Write-Info "Could not check log group: $logGroup"
        }
    }
    
    # Cleanup
    Remove-Item test-payload.json, read-payload.json, response.json, read-response.json -ErrorAction SilentlyContinue
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "ALL TESTS COMPLETED" -ForegroundColor Green
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
