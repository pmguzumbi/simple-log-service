# Direct Lambda Function Test Script
# Tests the ingest Lambda function directly

# Color functions
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Direct Lambda Function Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$FUNCTION_NAME = "simple-log-service-ingest-prod"
$REGION = "eu-west-1"

# Create test payload
$payload = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    message = "Direct Lambda test message"
    service_name = "test-app"
    level = "INFO"
    log_type = "application"
} | ConvertTo-Json -Compress

Write-Host "[PAYLOAD] Test payload:" -ForegroundColor Yellow
Write-Host $payload -ForegroundColor White

# Create temporary file for payload
$tempFile = [System.IO.Path]::GetTempFileName()
$payload | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

Write-Host "`n[TEST] Invoking Lambda function directly..." -ForegroundColor Cyan

# Invoke Lambda function
$outputFile = [System.IO.Path]::GetTempFileName()

try {
    # Capture both stdout and stderr
    $result = aws lambda invoke `
        --function-name $FUNCTION_NAME `
        --payload file://$tempFile `
        --region $REGION `
        $outputFile 2>&1
    
    # Display the AWS CLI output
    Write-Host "`n[AWS CLI OUTPUT]" -ForegroundColor Yellow
    Write-Host $result -ForegroundColor White
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "`n  [PASS] Lambda invoked successfully"
        
        # Read and display response
        if (Test-Path $outputFile) {
            $response = Get-Content $outputFile -Raw
            Write-Host "`n[RESPONSE]" -ForegroundColor Yellow
            Write-Host $response -ForegroundColor White
            
            # Parse response if it's JSON
            try {
                $responseObj = $response | ConvertFrom-Json
                if ($responseObj.statusCode -eq 200) {
                    Write-ColorOutput Green "  [PASS] Lambda returned success status"
                } else {
                    Write-ColorOutput Red "  [FAIL] Lambda returned error status: $($responseObj.statusCode)"
                    if ($responseObj.body) {
                        Write-Host "  Error body: $($responseObj.body)" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "  Response is not JSON or could not be parsed" -ForegroundColor Yellow
            }
        }
    } else {
        Write-ColorOutput Red "`n  [FAIL] Lambda invocation failed with exit code: $LASTEXITCODE"
    }
} catch {
    Write-ColorOutput Red "  [FAIL] Lambda invocation failed"
    Write-Host "  Error: $_" -ForegroundColor Red
} finally {
    # Clean up temporary files
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    Remove-Item $outputFile -ErrorAction SilentlyContinue
}

# Check if Lambda function exists
Write-Host "`n[VERIFY] Checking if Lambda function exists..." -ForegroundColor Cyan
try {
    $functionInfo = aws lambda get-function `
        --function-name $FUNCTION_NAME `
        --region $REGION `
        --output json 2>&1 | ConvertFrom-Json
    
    Write-ColorOutput Green "  [PASS] Lambda function exists"
    Write-Host "  Runtime: $($functionInfo.Configuration.Runtime)" -ForegroundColor White
    Write-Host "  Handler: $($functionInfo.Configuration.Handler)" -ForegroundColor White
    Write-Host "  Last Modified: $($functionInfo.Configuration.LastModified)" -ForegroundColor White
} catch {
    Write-ColorOutput Red "  [FAIL] Lambda function not found or not accessible"
    Write-Host "  Error: $_" -ForegroundColor Red
}

# Check CloudWatch Logs
Write-Host "`n[LOGS] Checking CloudWatch Logs..." -ForegroundColor Cyan

$logGroup = "/aws/lambda/$FUNCTION_NAME"

# First, check if log group exists
try {
    $logGroupInfo = aws logs describe-log-groups `
        --log-group-name-prefix $logGroup `
        --region $REGION `
        --output json 2>&1 | ConvertFrom-Json
    
    if ($logGroupInfo.logGroups -and $logGroupInfo.logGroups.Count -gt 0) {
        Write-ColorOutput Green "  [PASS] Log group exists: $logGroup"
        
        # Get recent log streams
        $startTime = [DateTimeOffset]::UtcNow.AddMinutes(-5).ToUnixTimeMilliseconds()
        
        $logStreams = aws logs describe-log-streams `
            --log-group-name $logGroup `
            --order-by LastEventTime `
            --descending `
            --max-items 3 `
            --region $REGION `
            --output json 2>&1 | ConvertFrom-Json
        
        if ($logStreams.logStreams -and $logStreams.logStreams.Count -gt 0) {
            Write-Host "`n  Found $($logStreams.logStreams.Count) recent log stream(s)" -ForegroundColor Yellow
            
            foreach ($stream in $logStreams.logStreams) {
                Write-Host "`n  Stream: $($stream.logStreamName)" -ForegroundColor Cyan
                
                $logEvents = aws logs get-log-events `
                    --log-group-name $logGroup `
                    --log-stream-name $stream.logStreamName `
                    --start-time $startTime `
                    --limit 20 `
                    --region $REGION `
                    --output json 2>&1 | ConvertFrom-Json
                
                if ($logEvents.events -and $logEvents.events.Count -gt 0) {
                    foreach ($event in $logEvents.events) {
                        $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($event.timestamp).LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss")
                        Write-Host "    [$timestamp] $($event.message)" -ForegroundColor White
                    }
                } else {
                    Write-Host "    No events in this stream" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  No log streams found yet (Lambda may not have been invoked)" -ForegroundColor Yellow
        }
    } else {
        Write-ColorOutput Red "  [FAIL] Log group does not exist: $logGroup"
        Write-Host "  This means the Lambda function has never been invoked or logging is not configured" -ForegroundColor Yellow
    }
} catch {
    Write-ColorOutput Red "  [FAIL] Could not check log group"
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
