# Direct Lambda Test Script
# Tests the Lambda function directly (bypassing API Gateway)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Direct Lambda Function Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create test payload
$testPayload = @{
    log_type = "application"
    service_name = "test-app"
    level = "INFO"
    message = "Direct Lambda test message"
    timestamp = (Get-Date).ToUniversalTime().ToString("[MAC_ADDRESS]")
}

$payloadJson = $testPayload | ConvertTo-Json -Compress

Write-Host "[PAYLOAD] Test payload:" -ForegroundColor Cyan
Write-Host $payloadJson -ForegroundColor Yellow

# Save to file without BOM
[System.IO.File]::WriteAllText("$PWD\test-payload.json", $payloadJson, [System.Text.UTF8Encoding]::new($false))

Write-Host "`n[TEST] Invoking Lambda function directly..." -ForegroundColor Cyan

# Invoke Lambda with proper payload handling
$invokeResult = aws lambda invoke `
    --function-name simple-log-service-ingest-prod `
    --payload file://test-payload.json `
    response.json 2>&1

Write-Host $invokeResult

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] Lambda invocation successful" -ForegroundColor Green
    
    # Read response
    $responseContent = Get-Content response.json -Raw
    Write-Host "`n[RAW RESPONSE]" -ForegroundColor Cyan
    Write-Host $responseContent -ForegroundColor Yellow
    
    try {
        $response = $responseContent | ConvertFrom-Json
        Write-Host "`n[PARSED RESPONSE]" -ForegroundColor Cyan
        Write-Host "  Status Code: $($response.statusCode)" -ForegroundColor $(if ($response.statusCode -lt 400) { "Green" } else { "Red" })
        
        $body = $response.body | ConvertFrom-Json
        if ($body.message) {
            Write-Host "  Message: $($body.message)" -ForegroundColor Green
        }
        if ($body.log_id) {
            Write-Host "  Log ID: $($body.log_id)" -ForegroundColor Green
        }
        if ($body.error) {
            Write-Host "  Error: $($body.error)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Could not parse response as JSON" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] Lambda invocation failed" -ForegroundColor Red
}

Write-Host "`n[LOGS] Checking CloudWatch Logs (last 2 minutes)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
aws logs tail /aws/lambda/simple-log-service-ingest-prod --since 2m --format short

# Cleanup
Remove-Item test-payload.json, response.json -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

## The Ke
