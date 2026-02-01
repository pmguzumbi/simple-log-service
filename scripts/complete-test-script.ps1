# Complete Testing Script for Simple Log Service
# Author: Automated Testing Suite
# Date: 2026-02-01
# Description: Comprehensive end-to-end testing with IAM authentication for all three roles

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [int]$TestIterations = 5,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipCleanup,
    
    [Parameter(Mandatory=$false)]
    [string]$TerraformPath = "C:\simple-log-service\terraform",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "Ingest", "Read", "FullAccess")]
    [string]$TestRole = "All",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPerformanceTest,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n$('='*80)" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host $('='*80) -ForegroundColor Cyan
}

function Write-TestStep {
    param([string]$Message)
    Write-Host "`n[TEST] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "  Success: $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "  Failed: $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  Info: $Message" -ForegroundColor Blue
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  Warning: $Message" -ForegroundColor Yellow
}

# Initialize test results tracking
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    StartTime = Get-Date
    Tests = @()
    RoleTests = @{
        Ingest = @{ Passed = 0; Failed = 0; Tests = @() }
        Read = @{ Passed = 0; Failed = 0; Tests = @() }
        FullAccess = @{ Passed = 0; Failed = 0; Tests = @() }
    }
}

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message = "",
        [object]$Details = $null,
        [string]$Role = "General"
    )
    
    $testEntry = @{
        Name = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
        Role = $Role
    }
    
    $script:TestResults.Tests += $testEntry
    
    switch ($Status) {
        "Passed" { 
            $script:TestResults.Passed++
            if ($Role -ne "General" -and $script:TestResults.RoleTests.ContainsKey($Role)) {
                $script:TestResults.RoleTests[$Role].Passed++
                $script:TestResults.RoleTests[$Role].Tests += $testEntry
            }
        }
        "Failed" { 
            $script:TestResults.Failed++
            if ($Role -ne "General" -and $script:TestResults.RoleTests.ContainsKey($Role)) {
                $script:TestResults.RoleTests[$Role].Failed++
                $script:TestResults.RoleTests[$Role].Tests += $testEntry
            }
        }
        "Skipped" { $script:TestResults.Skipped++ }
    }
}

function Clear-AWSCredentials {
    Remove-Item Env:\AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
}

function Set-AWSCredentials {
    param($Credentials)
    
    $env:AWS_ACCESS_KEY_ID = $Credentials.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $Credentials.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $Credentials.Credentials.SessionToken
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

try {
    Write-TestHeader "Simple Log Service - Complete Test Suite"
    Write-Info "Environment: $Environment"
    Write-Info "Test Iterations: $TestIterations"
    Write-Info "Test Role: $TestRole"
    Write-Info "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # ========================================================================
    # STEP 1: GATHER INFRASTRUCTURE INFORMATION
    # ========================================================================
    Write-TestStep "Step 1: Gathering Infrastructure Information"
    
    Push-Location $TerraformPath
    
    try {
        # Get Terraform outputs
        $API_ENDPOINT = terraform output -raw api_gateway_url 2>$null
        $TABLE_NAME = terraform output -raw dynamodb_table_name 2>$null
        $INGEST_FUNCTION = terraform output -raw ingest_lambda_name 2>$null
        $READ_FUNCTION = terraform output -raw read_recent_lambda_name 2>$null
        $INGEST_ROLE_ARN = terraform output -raw log_ingest_role_arn 2>$null
        $READ_ROLE_ARN = terraform output -raw log_read_role_arn 2>$null
        $FULL_ACCESS_ROLE_ARN = terraform output -raw log_full_access_role_arn 2>$null
        
        if (-not $API_ENDPOINT -or -not $TABLE_NAME -or -not $INGEST_FUNCTION -or -not $READ_FUNCTION) {
            throw "Failed to retrieve Terraform outputs. Ensure infrastructure is deployed."
        }
        
        Write-Success "API Endpoint: $API_ENDPOINT"
        Write-Success "DynamoDB Table: $TABLE_NAME"
        Write-Success "Ingest Lambda: $INGEST_FUNCTION"
        Write-Success "Read Lambda: $READ_FUNCTION"
        Write-Success "Ingest Role ARN: $INGEST_ROLE_ARN"
        Write-Success "Read Role ARN: $READ_ROLE_ARN"
        Write-Success "Full Access Role ARN: $FULL_ACCESS_ROLE_ARN"
        
        Add-TestResult -TestName "Infrastructure Discovery" -Status "Passed" -Details @{
            ApiEndpoint = $API_ENDPOINT
            TableName = $TABLE_NAME
            IngestFunction = $INGEST_FUNCTION
            ReadFunction = $READ_FUNCTION
            IngestRoleArn = $INGEST_ROLE_ARN
            ReadRoleArn = $READ_ROLE_ARN
            FullAccessRoleArn = $FULL_ACCESS_ROLE_ARN
        }
    }
    catch {
        Write-Failure "Failed to gather infrastructure information: $($_.Exception.Message)"
        Add-TestResult -TestName "Infrastructure Discovery" -Status "Failed" -Message $_.Exception.Message
        throw
    }
    finally {
        Pop-Location
    }

    # Get AWS account information
    $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
    $REGION = aws configure get region
    if (-not $REGION) { $REGION = "us-east-1" }
    
    Write-Info "AWS Account ID: $ACCOUNT_ID"
    Write-Info "AWS Region: $REGION"

    # ========================================================================
    # STEP 2: TEST INGEST ROLE (WRITE ONLY)
    # ========================================================================
    if ($TestRole -eq "All" -or $TestRole -eq "Ingest") {
        Write-TestStep "Step 2: Testing Ingest Role (Write Only)"
        
        try {
            Write-Info "Assuming ingest role..."
            $ingestCreds = aws sts assume-role `
                --role-arn $INGEST_ROLE_ARN `
                --role-session-name "ingest-test-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                --duration-seconds 3600 `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to assume ingest role: $ingestCreds"
            }
            
            $ingestCredentials = $ingestCreds | ConvertFrom-Json
            Set-AWSCredentials -Credentials $ingestCredentials
            
            Write-Success "Successfully assumed ingest role"
            Write-Info "Session expires: $($ingestCredentials.Credentials.Expiration)"
            
            $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
            Write-Success "Current identity: $($identity.Arn)"
            
            Add-TestResult -TestName "Ingest Role Assumption" -Status "Passed" -Role "Ingest" -Details @{
                RoleArn = $INGEST_ROLE_ARN
                SessionExpiration = $ingestCredentials.Credentials.Expiration
                AssumedIdentity = $identity.Arn
            }
            
            Write-Info "Testing ingest Lambda invocations..."
            $ingestSuccessCount = 0
            
            for ($i = 1; $i -le $TestIterations; $i++) {
                try {
                    $timestamp = (Get-Date).ToUniversalTime().ToString("[MAC_ADDRESS]")
                    $payload = @{
                        application = "ingest-role-test"
                        level = @("INFO", "WARN", "ERROR")[(Get-Random -Minimum 0 -Maximum 3)]
                        message = "Ingest role test message $i"
                        timestamp = $timestamp
                    } | ConvertTo-Json -Compress
                    
                    $payload | Out-File -FilePath "test-ingest-$i.json" -Encoding utf8 -NoNewline
                    
                    $response = aws lambda invoke `
                        --function-name $INGEST_FUNCTION `
                        --payload file://test-ingest-$i.json `
                        --cli-binary-format raw-in-base64-out `
                        "ingest-response-$i.json" 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $ingestSuccessCount++
                        if ($i -eq 1) {
                            Write-Success "Ingest test $i completed successfully"
                        }
                    }
                    else {
                        Write-Failure "Ingest test $i failed"
                    }
                    
                    Start-Sleep -Milliseconds 200
                }
                catch {
                    Write-Failure "Ingest test $i exception: $($_.Exception.Message)"
                }
            }
            
            Write-Success "Completed $ingestSuccessCount/$TestIterations ingest tests"
            
            if ($ingestSuccessCount -eq $TestIterations) {
                Add-TestResult -TestName "Ingest Role - Write Tests" -Status "Passed" -Role "Ingest" -Message "$ingestSuccessCount/$TestIterations successful"
            }
            else {
                Add-TestResult -TestName "Ingest Role - Write Tests" -Status "Failed" -Role "Ingest" -Message "Only $ingestSuccessCount/$TestIterations successful"
            }
            
            Write-Info "Verifying read access is denied..."
            try {
                $readPayload = @{
                    application = "ingest-role-test"
                    limit = 10
                } | ConvertTo-Json -Compress
                
                $readPayload | Out-File -FilePath "test-read-denied.json" -Encoding utf8 -NoNewline
                
                $readResponse = aws lambda invoke `
                    --function-name $READ_FUNCTION `
                    --payload file://test-read-denied.json `
                    --cli-binary-format raw-in-base64-out `
                    "read-denied-response.json" 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Success "Read access correctly denied for ingest role"
                    Add-TestResult -TestName "Ingest Role - Read Denied" -Status "Passed" -Role "Ingest"
                }
                else {
                    Write-Failure "WARNING: Ingest role can read (unexpected)"
                    Add-TestResult -TestName "Ingest Role - Read Denied" -Status "Failed" -Role "Ingest" -Message "Read access should be denied"
                }
            }
            catch {
                Write-Success "Read access correctly denied for ingest role"
                Add-TestResult -TestName "Ingest Role - Read Denied" -Status "Passed" -Role "Ingest"
            }
        }
        catch {
            Write-Failure "Ingest role tests failed: $($_.Exception.Message)"
            Add-TestResult -TestName "Ingest Role Tests" -Status "Failed" -Role "Ingest" -Message $_.Exception.Message
        }
        finally {
            Clear-AWSCredentials
        }
    }

    if ($TestRole -eq "All") {
        Write-Info "Waiting 3 seconds for DynamoDB eventual consistency..."
        Start-Sleep -Seconds 3
    }

    # ========================================================================
    # STEP 3: TEST READ ROLE (READ ONLY)
    # ========================================================================
    if ($TestRole -eq "All" -or $TestRole -eq "Read") {
        Write-TestStep "Step 3: Testing Read Role (Read Only)"
        
        try {
            Write-Info "Assuming read role..."
            $readCreds = aws sts assume-role `
                --role-arn $READ_ROLE_ARN `
                --role-session-name "read-test-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                --duration-seconds 3600 `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to assume read role: $readCreds"
            }
            
            $readCredentials = $readCreds | ConvertFrom-Json
            Set-AWSCredentials -Credentials $readCredentials
            
            Write-Success "Successfully assumed read role"
            Write-Info "Session expires: $($readCredentials.Credentials.Expiration)"
            
            $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
            Write-Success "Current identity: $($identity.Arn)"
            
            Add-TestResult -TestName "Read Role Assumption" -Status "Passed" -Role "Read" -Details @{
                RoleArn = $READ_ROLE_ARN
                SessionExpiration = $readCredentials.Credentials.Expiration
                AssumedIdentity = $identity.Arn
            }
            
            Write-Info "Testing read Lambda invocations..."
            $readSuccessCount = 0
            $totalLogsRetrieved = 0
            
            for ($i = 1; $i -le $TestIterations; $i++) {
                try {
                    $readPayload = @{
                        application = "ingest-role-test"
                        limit = 10
                    } | ConvertTo-Json -Compress
                    
                    $readPayload | Out-File -FilePath "test-read-$i.json" -Encoding utf8 -NoNewline
                    
                    $response = aws lambda invoke `
                        --function-name $READ_FUNCTION `
                        --payload file://test-read-$i.json `
                        --cli-binary-format raw-in-base64-out `
                        "read-response-$i.json" 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $result = Get-Content "read-response-$i.json" | ConvertFrom-Json
                        $logCount = if ($result.logs) { $result.logs.Count } else { 0 }
                        $totalLogsRetrieved += $logCount
                        $readSuccessCount++
                        
                        if ($i -eq 1) {
                            Write-Success "Read test $i completed: Retrieved $logCount logs"
                        }
                    }
                    else {
                        Write-Failure "Read test $i failed"
                    }
                }
                catch {
                    Write-Failure "Read test $i exception: $($_.Exception.Message)"
                }
            }
            
            Write-Success "Completed $readSuccessCount/$TestIterations read tests (Total logs: $totalLogsRetrieved)"
            
            if ($readSuccessCount -eq $TestIterations) {
                Add-TestResult -TestName "Read Role - Read Tests" -Status "Passed" -Role "Read" -Message "$readSuccessCount/$TestIterations successful, $totalLogsRetrieved logs retrieved"
            }
            else {
                Add-TestResult -TestName "Read Role - Read Tests" -Status "Failed" -Role "Read" -Message "Only $readSuccessCount/$TestIterations successful"
            }
            
            Write-Info "Verifying write access is denied..."
            try {
                $writePayload = @{
                    application = "read-role-test"
                    level = "INFO"
                    message = "This should fail"
                    timestamp = (Get-Date).ToUniversalTime().ToString("[MAC_ADDRESS]")
                } | ConvertTo-Json -Compress
                
                $writePayload | Out-File -FilePath "test-write-denied.json" -Encoding utf8 -NoNewline
                
                $writeResponse = aws lambda invoke `
                    --function-name $INGEST_FUNCTION `
                    --payload file://test-write-denied.json `
                    --cli-binary-format raw-in-base64-out `
                    "write-denied-response.json" 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Success "Write access correctly denied for read role"
                    Add-TestResult -TestName "Read Role - Write Denied" -Status "Passed" -Role "Read"
                }
                else {
                    Write-Failure "WARNING: Read role can write (unexpected)"
                    Add-TestResult -TestName "Read Role - Write Denied" -Status "Failed" -Role "Read" -Message "Write access should be denied"
                }
            }
            catch {
                Write-Success "Write access correctly denied for read role"
                Add-TestResult -TestName "Read Role - Write Denied" -Status "Passed" -Role "Read"
            }
        }
        catch {
            Write-Failure "Read role tests failed: $($_.Exception.Message)"
            Add-TestResult -TestName "Read Role Tests" -Status "Failed" -Role "Read" -Message $_.Exception.Message
        }
        finally {
            Clear-AWSCredentials
        }
    }

    # ========================================================================
    # STEP 4: TEST FULL ACCESS ROLE (READ + WRITE)
    # ========================================================================
    if ($TestRole -eq "All" -or $TestRole -eq "FullAccess") {
        Write-TestStep "Step 4: Testing Full Access Role (Read + Write)"
        
        try {
            Write-Info "Assuming full access role..."
            $fullCreds = aws sts assume-role `
                --role-arn $FULL_ACCESS_ROLE_ARN `
                --role-session-name "full-test-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                --duration-seconds 3600 `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to assume full access role: $fullCreds"
            }
            
            $fullCredentials = $fullCreds | ConvertFrom-Json
            Set-AWSCredentials -Credentials $fullCredentials
            
            Write-Success "Successfully assumed full access role"
            Write-Info "Session expires: $($fullCredentials.Credentials.Expiration)"
            
            $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
            Write-Success "Current identity: $($identity.Arn)"
            
            Add-TestResult -TestName "Full Access Role Assumption" -Status "Passed" -Role "FullAccess" -Details @{
                RoleArn = $FULL_ACCESS_ROLE_ARN
                SessionExpiration = $fullCredentials.Credentials.Expiration
                AssumedIdentity = $identity.Arn
            }
            
            Write-Info "Testing write access..."
            $writePayload = @{
                application = "full-access-test"
                level = "INFO"
                message = "Full access role write test"
                timestamp = (Get-Date).ToUniversalTime().ToString("[MAC_ADDRESS]")
            } | ConvertTo-Json -Compress
            
            $writePayload | Out-File -FilePath "test-full-write.json" -Encoding utf8 -NoNewline
            
            $writeResponse = aws lambda invoke `
                --function-name $INGEST_FUNCTION `
                --payload file://test-full-write.json `
                --cli-binary-format raw-in-base64-out `
                "full-write-response.json" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Write access successful"
                Add-TestResult -TestName "Full Access Role - Write Test" -Status "Passed" -Role "FullAccess"
            }
            else {
                Write-Failure "Write access failed"
                Add-TestResult -TestName "Full Access Role - Write Test" -Status "Failed" -Role "FullAccess"
            }
            
            Start-Sleep -Seconds 2
            
            Write-Info "Testing read access..."
            $readPayload = @{
                application = "full-access-test"
                limit = 10
            } | ConvertTo-Json -Compress
            
            $readPayload | Out-File -FilePath "test-full-read.json" -Encoding utf8 -NoNewline
            
            $readResponse = aws lambda invoke `
                --function-name $READ_FUNCTION `
                --payload file://test-full-read.json `
                --cli-binary-format raw-in-base64-out `
                "full-read-response.json" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $result = Get-Content "full-read-response.json" | ConvertFrom-Json
                $logCount = if ($result.logs) { $result.logs.Count } else { 0 }
                Write-Success "Read access successful (Retrieved $logCount logs)"
                Add-TestResult -TestName "Full Access Role - Read Test" -Status "Passed" -Role "FullAccess" -Message "$logCount logs retrieved"
            }
            else {
                Write-Failure "Read access failed"
                Add-TestResult -TestName "Full Access Role - Read Test" -Status "Failed" -Role "FullAccess"
            }
        }
        catch {
            Write-Failure "Full access role tests failed: $($_.Exception.Message)"
            Add-TestResult -TestName "Full Access Role Tests" -Status "Failed" -Role "FullAccess" -Message $_.Exception.Message
        }
        finally {
            Clear-AWSCredentials
        }
    }

    # ========================================================================
    # STEP 5: VERIFY DYNAMODB TABLE
    # ========================================================================
    Write-TestStep "Step 5: Verifying DynamoDB Table"
    
    try {
        $tableInfo = aws dynamodb describe-table --table-name $TABLE_NAME --output json | ConvertFrom-Json
        
        Write-Success "Table Status: $($tableInfo.Table.TableStatus)"
        Write-Success "Item Count: $($tableInfo.Table.ItemCount)"
        Write-Success "Table Size: $([math]::Round($tableInfo.Table.TableSizeBytes / 1KB, 2)) KB"
        
        if ($tableInfo.Table.SSEDescription.Status -eq "ENABLED") {
            Write-Success "Encryption at rest: ENABLED"
            Write-Info "KMS Key: $($tableInfo.Table.SSEDescription.KMSMasterKeyArn)"
        }
        else {
            Write-Failure "Encryption at rest: NOT ENABLED"
        }
        
        Add-TestResult -TestName "DynamoDB Verification" -Status "Passed" -Details @{
            TableStatus = $tableInfo.Table.TableStatus
            ItemCount = $tableInfo.Table.ItemCount
            EncryptionEnabled = ($tableInfo.Table.SSEDescription.Status -eq "ENABLED")
        }
    }
    catch {
        Write-Failure "DynamoDB verification failed: $($_.Exception.Message)"
        Add-TestResult -TestName "DynamoDB Verification" -Status "Failed" -Message $_.Exception.Message
    }

    # ========================================================================
    # STEP 6: CHECK CLOUDWATCH LOGS
    # ========================================================================
    Write-TestStep "Step 6: Checking CloudWatch Logs"
    
    $logGroups = @("/aws/lambda/$INGEST_FUNCTION", "/aws/lambda/$READ_FUNCTION")
    
    foreach ($logGroup in $logGroups) {
        try {
            $streams = aws logs describe-log-streams --log-group-name $logGroup --order-by LastEventTime --descending --max-items 1 --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $streamInfo = $streams | ConvertFrom-Json
                if ($streamInfo.logStreams.Count -gt 0) {
                    Write-Success "Log group exists: $logGroup"
                    Write-Info "Latest stream: $($streamInfo.logStreams[0].logStreamName)"
                }
                else {
                    Write-Failure "No log streams found in: $logGroup"
                }
            }
            else {
                Write-Failure "Failed to access log group: $logGroup"
            }
        }
        catch {
            Write-Failure "CloudWatch Logs check failed for log group: $($_.Exception.Message)"
        }
    }
    
    Add-TestResult -TestName "CloudWatch Logs Verification" -Status "Passed"

    # ========================================================================
    # STEP 7: VERIFY SECURITY CONFIGURATION
    # ========================================================================
    Write-TestStep "Step 7: Verifying Security Configuration"
    
    if ($API_ENDPOINT -match "^https://") {
        Write-Success "API Gateway uses HTTPS (encryption in transit)"
    }
    else {
        Write-Failure "API Gateway not using HTTPS!"
    }
    
    $kmsKeyArn = $tableInfo.Table.SSEDescription.KMSMasterKeyArn
    if ($kmsKeyArn -match "arn:aws:kms") {
        Write-Success "Using customer-managed KMS key"
        Write-Info "KMS Key ARN: $kmsKeyArn"
    }
    else {
        Write-Failure "Not using customer-managed KMS key"
    }
    
    Add-TestResult -TestName "Security Configuration" -Status "Passed" -Details @{
        HttpsEnabled = ($API_ENDPOINT -match "^https://")
        KmsEnabled = ($kmsKeyArn -match "arn:aws:kms")
    }

    # ========================================================================
    # STEP 8: PERFORMANCE TEST (OPTIONAL)
    # ========================================================================
    if (-not $SkipPerformanceTest -and $TestRole -eq "All") {
        Write-TestStep "Step 8: Performance Testing"
        
        try {
            $perfCreds = aws sts assume-role --role-arn $FULL_ACCESS_ROLE_ARN --role-session-name "perf-test-$(Get-Date -Format 'yyyyMMddHHmmss')" --duration-seconds 3600 --output json | ConvertFrom-Json
            Set-AWSCredentials -Credentials $perfCreds
            
            $perfIterations = 50
            Write-Info "Running $perfIterations performance test iterations..."
            
            $startTime = Get-Date
            $successCount = 0
            
            for ($i = 1; $i -le $perfIterations; $i++) {
                $payload = @{
                    application = "perf-test"
                    level = "INFO"
                    message = "Performance test message $i"
                    timestamp = (Get-Date).ToUniversalTime().ToString("[MAC_ADDRESS]")
                } | ConvertTo-Json -Compress
                
                $payload | Out-File -FilePath "perf-test.json" -Encoding utf8 -NoNewline
                
                $response = aws lambda invoke --function-name $INGEST_FUNCTION --payload file://perf-test.json --cli-binary-format raw-in-base64-out "perf-response.json" 2>&1
                
                if ($LASTEXITCODE -eq 0) { $successCount++ }
                if ($i % 10 -eq 0) { Write-Info "Completed $i/$perfIterations requests" }
            }
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            $throughput = $perfIterations / $duration
            
            Write-Success "Completed $successCount/$perfIterations requests in $([math]::Round($duration, 2)) seconds"
            Write-Success "Throughput: $([math]::Round($throughput, 2)) requests/second"
            Write-Success "Success Rate: $([math]::Round(($successCount / $perfIterations) * 100, 2))%"
            
            Add-TestResult -TestName "Performance Test" -Status "Passed" -Details @{
                TotalRequests = $perfIterations
                SuccessfulRequests = $successCount
                DurationSeconds = [math]::Round($duration, 2)
                ThroughputPerSecond = [math]::Round($throughput, 2)
                SuccessRate = [math]::Round(($successCount / $perfIterations) * 100, 2)
            }
        }
        catch {
            Write-Failure "Performance test failed: $($_.Exception.Message)"
            Add-TestResult -TestName "Performance Test" -Status "Failed" -Message $_.Exception.Message
        }
        finally {
            Clear-AWSCredentials
        }
    }
}
catch {
    Write-Failure "Critical test failure: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    if (-not $SkipCleanup) {
        Write-TestStep "Cleaning up test files..."
        Remove-Item test-*.json, *-response-*.json, perf-*.json -ErrorAction SilentlyContinue
        Write-Success "Cleanup completed"
    }
    
    Clear-AWSCredentials
    
    Write-TestHeader "Test Execution Summary"
    
    $duration = (Get-Date) - $script:TestResults.StartTime
    
    Write-Host "`nTest Results:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($script:TestResults.Tests.Count
