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
    aws lambda invoke `
        --function-name $FUNCTION_NAME `
        --payload file://$tempFile `
        --region $REGION `
        $outputFile 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "  [PASS] Lambda invoked successfully"
        
        # Read and display response
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
    } else {
        Write-ColorOutput Red "  [FAIL] Lambda invocation failed"
    }
} catch {
    Write-ColorOutput Red "  [FAIL] Lambda invocation failed"
    Write-Host "  Error: $_" -ForegroundColor Red
} finally {
    # Clean up temporary files
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    Remove-Item $outputFile -ErrorAction SilentlyContinue
}

# Check CloudWatch Logs
Write-Host "`n[LOGS] Checking CloudWatch Logs (last 2 minutes)..." -ForegroundColor Cyan

$logGroup = "/aws/lambda/$FUNCTION_NAME"
$startTime = [DateTimeOffset]::UtcNow.AddMinutes(-2).ToUnixTimeMilliseconds()

try {
    $logStreams = aws logs describe-log-streams `
        --log-group-name $logGroup `
        --order-by LastEventTime `
        --descending `
        --max-items 1 `
        --region $REGION `
        --output json | ConvertFrom-Json
    
    if ($logStreams.logStreams -and $logStreams.logStreams.Count -gt 0) {
        $latestStream = $logStreams.logStreams[0].logStreamName
        
        $logEvents = aws logs get-log-events `
            --log-group-name $logGroup `
            --log-stream-name $latestStream `
            --start-time $startTime `
            --region $REGION `
            --output json | ConvertFrom-Json
        
        if ($logEvents.events -and $logEvents.events.Count -gt 0) {
            Write-Host "`nRecent log entries:" -ForegroundColor Yellow
            foreach ($event in $logEvents.events) {
                $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($event.timestamp).LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss")
                Write-Host "[$timestamp] $($event.message)" -ForegroundColor White
            }
        } else {
            Write-Host "No recent log entries found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No log streams found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not retrieve logs: $_" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
