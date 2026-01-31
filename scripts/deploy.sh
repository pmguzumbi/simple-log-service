#!/bin/bash
# Deployment script for Simple Log Service
# Compatible with Git Bash on Windows

set -e

echo "=========================================="
echo "Simple Log Service - Deployment Script"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

if ! command -v python &> /dev/null; then
    echo "Error: Python is not installed"
    exit 1
fi

echo "✓ All prerequisites met"

# Check AWS credentials
echo ""
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✓ AWS Account: $ACCOUNT_ID"

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo ""
echo "Validating Terraform configuration..."
terraform validate

# Plan deployment
echo ""
echo "Planning deployment..."
terraform plan -out=tfplan

# Confirm deployment
echo ""
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Apply deployment
echo ""
echo "Deploying infrastructure..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

# Get outputs
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "API Gateway URL:"
terraform output -raw api_gateway_url
echo ""
echo ""
echo "DynamoDB Table:"
terraform output -raw dynamodb_table_name
echo ""
echo ""
echo "CloudWatch Dashboard:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#dashboards:name=$(terraform output -raw cloudwatch_dashboard_name)"
echo ""
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Run tests: cd ../scripts && python test_api.py"
echo "2. View logs: aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --follow"
echo "3. Monitor: Open CloudWatch dashboard (URL above)"
echo ""

