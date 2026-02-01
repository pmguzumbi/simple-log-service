# Simple Log Service - API Gateway Test Script
# Version: 1.0 - Tests API Gateway with IAM authentication
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

$ErrorActionPreference = "Continue"

# Color-coded output functions
function Write-Step { param([string]$Msg) Write-Host "`n[STEP] $Msg" -ForegroundColor Cyan }
function Write-Pass { param([string]$Msg) Write-Host "  [PASS] $Msg" -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor Yellow }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Simple Log Service - API Gateway Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

$testFailed = $false

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
        $identity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
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
        $tfOutput = terraform output -json 2>&1 | ConvertFrom-Json
        
        $API_ENDPOINT = $tfOutput.api_endpoint.value
        $TABLE_NAME = $tfOutput.dynamodb_table_name.value
        $INGEST_ROLE = $tfOutput.log_ingest_role_arn.value
        $READ_ROLE = $tfOutput.log_read_role_arn.value
        
        if (-not $API_ENDPOINT) {
            Write-Fail "Missing API endpoint in Terraform outputs"
            exit 1
        }
        
        Write-Pass "API Endpoint: $API_ENDPOINT"
        Write-Pass "DynamoDB Table: $TABLE_NAME"
        Write-Pass "Ingest Role: $INGEST_ROLE"
        Write-Pass "Read Role: $READ_ROLE"
    }
    finally {
        Pop-Location
    }
    
    # Define external IDs for security
    $INGEST_EXTERNAL_ID = "simple-log-service-ingest-$Environment"
    $READ_EXTERNAL_ID = "simple-log-service-read-$Environment"
    
    Write-Info "Using external IDs for secure role assumption:"
    Write-Info "  Ingest: $INGEST_EXTERNAL_ID"
    Write-Info "  Read: $READ_EXTERNAL_ID"
    
    # STEP 3: Test POST /logs (Ingest) with IAM Authentication
    Write-Step "Testing POST /logs (Ingest Endpoint)"
    
    Write-Info "Assuming ingest role with external ID..."
    
    $ingestCredsRaw = aws sts assume-role `
        --role-arn $INGEST_ROLE `
        --role-session-name "api-test-ingest-$(Get-Date -Format 'HHmmss')" `
        --external-id $INGEST_EXTERNAL_ID `
        --duration-seconds 900 `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to assume ingest role"
        Write-Info "Error: $ingestCredsRaw"
        $testFailed = $true
    }
    else {
        $ingestCreds = $ingestCredsRaw | ConvertFrom-Json
        
        $env:AWS_ACCESS_KEY_ID = $ingestCreds.Credentials.AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $ingestCreds.Credentials.SecretAccessKey
        $env:AWS_SESSION_TOKEN = $ingestCreds.Credentials.SessionToken
        
        Write-Pass "Role assumed successfully"
        
        $assumedIdentity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
        Write-Info "Assumed identity: $($assumedIdentity.Arn)"
        
        # Test POST requests to API Gateway
        $successCount = 0
        for ($i = 1; $i -le $TestCount; $i++) {
            $logPayload = @{
                service_name = "test-app"
                level = "INFO"
                message = "API Gateway test message $i"
                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            } | ConvertTo-Json -Compress
            
            # Save payload without BOM
            [System.IO.File]::WriteAllText("$PWD\api-ingest-payload-$i.json", $logPayload, [System.Text.UTF8Encoding]::new($false))
            
            Write-Info "Sending POST request $i/$TestCount to API Gateway..."
            
            # Use AWS CLI to make signed API Gateway request
            $apiOutput = aws apigatewayv2 invoke `
                --api-id "v22n8t8394" `
                --stage-name "prod" `
                --request-body "file://api-ingest-payload-$i.json" `
                --http-method POST `
                --resource-path "/logs" `
                "api-response-$i.json" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $successCount++
                Write-Pass "POST request $i/$TestCount successful"
                
                if (Test-Path "api-response-$i.json") {
                    $response = Get-Content "api-response-$i.json" -Raw
                    Write-Info "Response: $response"
                }
            }
            else {
                Write-Fail "POST request $i/$TestCount failed"
                Write-Info "Error: $apiOutput"
                
                # Try alternative method using curl with AWS SigV4
                Write-Info "Attempting with curl and AWS SigV4 signing..."
                
                $curlOutput = aws --region us-east-1 `
                    curl `
                    --request POST `
                    --data "@api-ingest-payload-$i.json" `
                    "$API_ENDPOINT" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $successCount++
                    Write-Pass "POST request $i/$TestCount successful (via curl)"
                    Write-Info "Response: $curlOutput"
                }
                else {
                    Write-Fail "POST request $i/$TestCount failed (via curl)"
                    Write-Info "Curl error: $curlOutput"
                    $testFailed = $true
                }
            }
        }
        
        Write-Pass "POST /logs tests: $successCount/$TestCount successful"
        
        # Clear credentials
        Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    }
    
    if (-not $testFailed) {
        Write-Info "Waiting 3 seconds for DynamoDB eventual consistency..."
        Start-Sleep -Seconds 3
        
        # STEP 4: Test GET /logs/recent (Read) with IAM Authentication
        Write-Step "Testing GET /logs/recent (Read Endpoint)"
        
        Write-Info "Assuming read role with external ID..."
        
        $readCredsRaw = aws sts assume-role `
            --role-arn $READ_ROLE `
            --role-session-name "api-test-read-$(Get-Date -Format 'HHmmss')" `
            --external-id $READ_EXTERNAL_ID `
            --duration-seconds 900 `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to assume read role"
            Write-Info "Error: $readCredsRaw"
            $testFailed = $true
        }
        else {
            $readCreds = $readCredsRaw | ConvertFrom-Json
            
            $env:AWS_ACCESS_KEY_ID = $readCreds.Credentials.AccessKeyId
            $env:AWS_SECRET_ACCESS_KEY = $readCreds.Credentials.SecretAccessKey
            $env:AWS_SESSION_TOKEN = $readCreds.Credentials.SessionToken
            
            Write-Pass "Role assumed successfully"
            
            $assumedIdentity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
            Write-Info "Assumed identity: $($assumedIdentity.Arn)"
            
            Write-Info "Sending GET request to API Gateway..."
            
            # Construct GET URL with query parameters
            $getUrl = "$API_ENDPOINT/recent?service_name=test-app&limit=10"
            
            # Use AWS CLI curl with SigV4 signing
            $getOutput = aws --region us-east-1 `
                curl `
                --request GET `
                "$getUrl" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Pass "GET /logs/recent successful"
                
                try {
                    $result = $getOutput | ConvertFrom-Json
                    $logCount = if ($result.logs) { $result.logs.Count } else { 0 }
                    Write-Pass "Retrieved $logCount logs"
                    
                    if ($logCount -gt 0) {
                        Write-Info "Sample log entries:"
                        for ($i = 0; $i -lt [Math]::Min(3, $logCount); $i++) {
                            $log = $result.logs[$i]
                            Write-Info "  [$($i+1)] Service: $($log.service_name), Level: $($log.level), Message: $($log.message)"
                        }
                    }
                    else {
                        Write-Info "No logs found - data may not be consistent yet"
                    }
                }
                catch {
                    Write-Info "Response: $getOutput"
                }
            }
            else {
                Write-Fail "GET /logs/recent failed"
                Write-Info "Error: $getOutput"
                $testFailed = $true
            }
            
            # Clear credentials
            Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
        }
        
        # STEP 5: Verify DynamoDB Data
        Write-Step "Verifying DynamoDB Data"
        
        $tableInfo = aws dynamodb describe-table --table-name $TABLE_NAME --output json 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Table Status: $($tableInfo.Table.TableStatus)"
            Write-Pass "Item Count: $($tableInfo.Table.ItemCount)"
            
            $tableSizeKB = [math]::Round($tableInfo.Table.TableSizeBytes / 1KB, 2)
            Write-Pass "Table Size: $tableSizeKB KB"
            
            # Sample a few items from the table
            Write-Info "Sampling recent items from DynamoDB..."
            
            $scanOutput = aws dynamodb scan `
                --table-name $TABLE_NAME `
                --limit 3 `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $scanResult = $scanOutput | ConvertFrom-Json
                Write-Pass "Found $($scanResult.Count) items in table"
                
                if ($scanResult.Items.Count -gt 0) {
                    Write-Info "Sample items:"
                    foreach ($item in $scanResult.Items) {
                        Write-Info "  - Service: $($item.service_name.S), Level: $($item.level.S), Timestamp: $($item.timestamp.S)"
                    }
                }
            }
        }
    }
    
    # Cleanup
    Remove-Item api-*.json -ErrorAction SilentlyContinue
    
    if ($testFailed) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "API GATEWAY TESTS FAILED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
        Write-Host ""
        
        Write-Info "Troubleshooting tips:"
        Write-Info "1. Verify API Gateway resource policy allows IAM authentication"
        Write-Info "2. Check API Gateway method authorization is set to AWS_IAM"
        Write-Info "3. Ensure Lambda integration is configured correctly"
        Write-Info "4. Review CloudWatch logs for API Gateway and Lambda"
        Write-Info "5. Verify IAM roles have execute-api:Invoke permission"
        
        exit 1
    }
    else {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "ALL API GATEWAY TESTS PASSED" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
        Write-Host ""
        exit 0
    }
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "TEST FAILED WITH EXCEPTION" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nStack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    
    # Cleanup
    Remove-Item Env:\AWS_ACCESS_KEY_ID, Env:\AWS_SECRET_ACCESS_KEY, Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    Remove-Item api-*.json -ErrorAction SilentlyContinue
    
    exit 1
}
