
# Simple Log Service - API Gateway Test Script
# Version: 2.2 - Tests API Gateway with IAM authentication
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
    
    # Check Python installation
    try {
        $pythonVersion = python --version 2>&1
        Write-Pass "Python installed: $pythonVersion"
    }
    catch {
        Write-Fail "Python not found - required for AWS SigV4 signing"
        Write-Info "Install Python from: https://www.python.org/downloads/"
        exit 1
    }
    
    # Check if requests and requests-aws4auth are installed
    Write-Info "Checking Python dependencies..."
    $pipList = pip list 2>&1 | Out-String
    
    if ($pipList -notmatch "requests") {
        Write-Info "Installing requests library..."
        pip install requests 2>&1 | Out-Null
    }
    
    if ($pipList -notmatch "requests-aws4auth") {
        Write-Info "Installing requests-aws4auth library..."
        pip install requests-aws4auth 2>&1 | Out-Null
    }
    
    Write-Pass "Python dependencies ready"
    
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
        
        # Capture raw output to see what's happening
        $tfOutputRaw = terraform output -json 2>&1
        
        # Check if it's valid JSON
        try {
            $tfOutput = $tfOutputRaw | ConvertFrom-Json
        }
        catch {
            Write-Fail "Terraform output is not valid JSON"
            Write-Info "Raw Terraform output:"
            Write-Info $tfOutputRaw
            Write-Info ""
            Write-Info "This usually means:"
            Write-Info "  1. Terraform state is corrupted or incomplete"
            Write-Info "  2. Terraform needs to be re-initialized: terraform init"
            Write-Info "  3. Infrastructure needs to be re-applied: terraform apply"
            exit 1
        }
        
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
    
    # Create Python helper script for AWS SigV4 signed requests
    $pythonScript = @'
import sys
import json
import requests
from requests_aws4auth import AWS4Auth
import os

def make_request(method, url, data_file=None):
    # Get credentials from environment
    access_key = os.environ.get('AWS_ACCESS_KEY_ID')
    secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
    session_token = os.environ.get('AWS_SESSION_TOKEN')
    region = 'us-east-1'
    
    if not access_key or not secret_key:
        print(json.dumps({"error": "AWS credentials not found in environment"}))
        sys.exit(1)
    
    # Create AWS4Auth instance
    auth = AWS4Auth(access_key, secret_key, region, 'execute-api', session_token=session_token)
    
    headers = {'Content-Type': 'application/json'}
    
    try:
        if method == 'POST':
            if data_file:
                with open(data_file, 'r') as f:
                    data = json.load(f)
                response = requests.post(url, auth=auth, json=data, headers=headers)
            else:
                response = requests.post(url, auth=auth, headers=headers)
        elif method == 'GET':
            response = requests.get(url, auth=auth, headers=headers)
        else:
            print(json.dumps({"error": f"Unsupported method: {method}"}))
            sys.exit(1)
        
        result = {
            "status_code": response.status_code,
            "headers": dict(response.headers),
            "body": response.text
        }
        
        print(json.dumps(result))
        
        if response.status_code >= 400:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: python script.py <method> <url> [data_file]"}))
        sys.exit(1)
    
    method = sys.argv[1]
    url = sys.argv[2]
    data_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    make_request(method, url, data_file)
'@
    
    [System.IO.File]::WriteAllText("$PWD\aws_sigv4_request.py", $pythonScript, [System.Text.UTF8Encoding]::new($false))
    Write-Pass "Created Python helper script for AWS SigV4 signing"
    
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
            # Updated payload to include log_type field
            $logPayload = @{
                log_type = "application"
                service_name = "test-app"
                level = "INFO"
                message = "API Gateway test message $i"
                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
            
            $payloadJson = $logPayload | ConvertTo-Json -Compress
            
            # Save payload to file without BOM
            [System.IO.File]::WriteAllText("$PWD\api-payload-$i.json", $payloadJson, [System.Text.UTF8Encoding]::new($false))
            
            Write-Info "Sending POST request $i/$TestCount to API Gateway..."
            
            # Use Python script to make signed request, passing filename
            $pythonOutput = python aws_sigv4_request.py POST $API_ENDPOINT "api-payload-$i.json" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $successCount++
                Write-Pass "POST request $i/$TestCount successful"
                
                try {
                    $response = $pythonOutput | ConvertFrom-Json
                    Write-Info "Status Code: $($response.status_code)"
                    Write-Info "Response: $($response.body)"
                }
                catch {
                    Write-Info "Response: $pythonOutput"
                }
            }
            else {
                Write-Fail "POST request $i/$TestCount failed"
                
                try {
                    $errorResponse = $pythonOutput | ConvertFrom-Json
                    Write-Info "Error: $($errorResponse.error)"
                    if ($errorResponse.status_code) {
                        Write-Info "Status Code: $($errorResponse.status_code)"
                        Write-Info "Response Body: $($errorResponse.body)"
                    }
                }
                catch {
                    Write-Info "Error output: $pythonOutput"
                }
                $testFailed = $true
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
            
            # Use Python script to make signed GET request (no data file needed)
            $pythonOutput = python aws_sigv4_request.py GET $getUrl 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Pass "GET /logs/recent successful"
                
                try {
                    $response = $pythonOutput | ConvertFrom-Json
                    Write-Info "Status Code: $($response.status_code)"
                    
                    $result = $response.body | ConvertFrom-Json
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
                    Write-Info "Response: $pythonOutput"
                }
            }
            else {
                Write-Fail "GET /logs/recent failed"
                
                try {
                    $errorResponse = $pythonOutput | ConvertFrom-Json
                    Write-Info "Error: $($errorResponse.error)"
                    if ($errorResponse.status_code)
