# Manual Lambda Update Script
# This script updates the Lambda function code directly

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Manual Lambda Function Update" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    # Step 1: Navigate to Lambda source directory
    Write-Host "[STEP 1] Navigating to Lambda source directory..." -ForegroundColor Cyan
    Set-Location "C:\simple-log-service\lambda\ingest"
    
    # Step 2: Verify index.py exists
    Write-Host "[STEP 2] Verifying index.py exists..." -ForegroundColor Cyan
    if (-not (Test-Path "index.py")) {
        Write-Host "  [FAIL] index.py not found!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [PASS] index.py found" -ForegroundColor Green
    
    # Step 3: Show first few lines to verify it's the updated version
    Write-Host "[STEP 3] Checking index.py content..." -ForegroundColor Cyan
    $firstLines = Get-Content "index.py" -Head 12
    if ($firstLines -match "TABLE_NAME = os.environ.get\('TABLE_NAME'\) or os.environ.get\('DYNAMODB_TABLE_NAME'\)") {
        Write-Host "  [PASS] Updated code detected" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Code may not be updated - check manually" -ForegroundColor Yellow
    }
    
    # Step 4: Create deployment package
    Write-Host "[STEP 4] Creating deployment package..." -ForegroundColor Cyan
    
    # Remove old deployment.zip if exists
    if (Test-Path "deployment.zip") {
        Remove-Item "deployment.zip" -Force
    }
    
    # Create new zip file
    Compress-Archive -Path "index.py" -DestinationPath "deployment.zip" -Force
    
    if (Test-Path "deployment.zip") {
        $zipSize = (Get-Item "deployment.zip").Length
        Write-Host "  [PASS] Deployment package created ($zipSize bytes)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Failed to create deployment package" -ForegroundColor Red
        exit 1
    }
    
    # Step 5: Update Lambda function
    Write-Host "[STEP 5] Updating Lambda function..." -ForegroundColor Cyan
    
    # Read the zip file as bytes
    $zipBytes = [System.IO.File]::ReadAllBytes("$PWD\deployment.zip")
    
    # Convert to base64
    $zipBase64 = [System.Convert]::ToBase64String($zipBytes)
    
    # Create temporary file with base64 content
    $tempFile = "$env:TEMP\lambda-deployment-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    [System.IO.File]::WriteAllBytes($tempFile, $zipBytes)
    
    # Update Lambda using the temporary file
    $updateCommand = "aws lambda update-function-code --function-name simple-log-service-ingest-prod --zip-file fileb://$tempFile"
    
    Write-Host "  [INFO] Executing: $updateCommand" -ForegroundColor Yellow
    
    $result = Invoke-Expression $updateCommand 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Lambda function updated successfully" -ForegroundColor Green
        
        # Parse and display result
        try {
            $resultJson = $result | ConvertFrom-Json
            Write-Host "  [INFO] Function ARN: $($resultJson.FunctionArn)" -ForegroundColor Yellow
            Write-Host "  [INFO] Last Modified: $($resultJson.LastModified)" -ForegroundColor Yellow
            Write-Host "  [INFO] Code Size: $($resultJson.CodeSize) bytes" -ForegroundColor Yellow
        } catch {
            Write-Host "  [INFO] Update result: $result" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [FAIL] Lambda update failed" -ForegroundColor Red
        Write-Host "  [ERROR] $result" -ForegroundColor Red
        
        # Cleanup temp file
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
        exit 1
    }
    
    # Cleanup temp file
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
    
    # Step 6: Wait for update to propagate
    Write-Host "[STEP 6] Waiting for update to propagate..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
    Write-Host "  [PASS] Wait complete" -ForegroundColor Green
    
    # Step 7: Verify the update
    Write-Host "[STEP 7] Verifying Lambda configuration..." -ForegroundColor Cyan
    
    $verifyCommand = "aws lambda get-function-configuration --function-name simple-log-service-ingest-prod --output json"
    $config = Invoke-Expression $verifyCommand | ConvertFrom-Json
    
    Write-Host "  [INFO] Function Name: $($config.FunctionName)" -ForegroundColor Yellow
    Write-Host "  [INFO] Last Modified: $($config.LastModified)" -ForegroundColor Yellow
    Write-Host "  [INFO] Runtime: $($config.Runtime)" -ForegroundColor Yellow
    Write-Host "  [INFO] Handler: $($config.Handler)" -ForegroundColor Yellow
    Write-Host "  [INFO] Environment Variables:" -ForegroundColor Yellow
    
    $config.Environment.Variables.PSObject.Properties | ForEach-Object {
        Write-Host "    - $($_.Name) = $($_.Value)" -ForegroundColor Yellow
    }
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Lambda Update Complete!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run: cd C:\simple-log-service\scripts" -ForegroundColor White
    Write-Host "2. Run: .\test-lambda-direct.ps1`n" -ForegroundColor White
    
} catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "Update Failed with Exception" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nStack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    exit 1
}
