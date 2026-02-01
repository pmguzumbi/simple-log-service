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
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json -Compress

# Save to file without BOM
[System.IO.File]::WriteAllText("$PWD\test-payload.json", $testPayload, [System.Text.UTF8Encoding]::new($false))

Write-Host "[TEST] Invoking Lambda function directly..." -ForegroundColor Cyan

# Invoke Lambda
aws lambda invoke `
    --function-name simple-log-service-ingest-prod `
    --payload file://test-payload.json `
    --cli-binary-format raw-in-base64-out `
    response.json

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] Lambda invocation successful" -ForegroundColor Green
    
    # Read response
    $response = Get-Content response.json | ConvertFrom-Json
    Write-Host "`n[RESPONSE]" -ForegroundColor Cyan
    Write-Host "  Status Code: $($response.statusCode)" -ForegroundColor $(if ($response.statusCode -lt 400) { "Green" } else { "Red" })
    
    $body = $response.body | ConvertFrom-Json
    Write-Host "  Message: $($body.message)" -ForegroundColor Yellow
    if ($body.log_id) {
        Write-Host "  Log ID: $($body.log_id)" -ForegroundColor Yellow
    }
    if ($body.error) {
        Write-Host "  Error: $($body.error)" -ForegroundColor Red
    }
} else {
    Write-Host "  [FAIL] Lambda invocation failed" -ForegroundColor Red
}

Write-Host "`n[LOGS] Checking CloudWatch Logs..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
aws logs tail /aws/lambda/simple-log-service-ingest-prod --since 1m

# Cleanup
Remove-Item test-payload.json, response.json -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

