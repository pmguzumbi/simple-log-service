# Force Lambda Deployment Script
# This script forces a complete redeployment of the Lambda function

param(
    [Parameter(Mandatory=$false)]
    [string]$TerraformPath = "C:\simple-log-service\terraform"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Force Lambda Deployment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Navigate to Terraform directory
Write-Host "[STEP 1] Navigating to Terraform directory..." -ForegroundColor Cyan
cd $TerraformPath

# Step 2: Taint the Lambda function to force recreation
Write-Host "[STEP 2] Tainting Lambda function..." -ForegroundColor Cyan
terraform taint aws_lambda_function.ingest_log

# Step 3: Apply changes
Write-Host "[STEP 3] Applying Terraform changes..." -ForegroundColor Cyan
terraform apply -auto-approve

# Step 4: Wait for deployment
Write-Host "[STEP 4] Waiting 20 seconds for deployment to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Step 5: Verify deployment
Write-Host "[STEP 5] Verifying Lambda function..." -ForegroundColor Cyan
$config = aws lambda get-function-configuration `
    --function-name simple-log-service-ingest-prod `
    --output json | ConvertFrom-Json

Write-Host "  Function Name: $($config.FunctionName)" -ForegroundColor Green
Write-Host "  Last Modified: $($config.LastModified)" -ForegroundColor Green
Write-Host "  Runtime: $($config.Runtime)" -ForegroundColor Green
Write-Host "  Handler: $($config.Handler)" -ForegroundColor Green

# Step 6: Check environment variables
Write-Host "`n[STEP 6] Environment Variables:" -ForegroundColor Cyan
$config.Environment.Variables.PSObject.Properties | ForEach-Object {
    Write-Host "  $($_.Name) = $($_.Value)" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Run: cd C:\simple-log-service\scripts" -ForegroundColor White
Write-Host "2. Run: .\test-lambda-direct.ps1" -ForegroundColor White
Write-Host "3. If direct test passes, run: .\api-gateway-test.ps1`n" -ForegroundColor White

