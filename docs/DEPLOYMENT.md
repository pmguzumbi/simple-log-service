# Deployment Guide

## Prerequisites

### Required Software
- **Terraform**: >= 1.5.0
- **AWS CLI**: >= 2.0
- **Python**: 3.11
- **Git**: Latest version
- **VS Code**: Recommended IDE

### AWS Account Requirements
- Active AWS account
- IAM user with administrator access (or specific permissions)
- AWS CLI configured with credentials
- Access to eu-west-2 region

### Required IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:*",
        "lambda:*",
        "apigateway:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "cloudwatch:*",
        "sns:*",
        "s3:*",
        "config:*",
        "xray:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Initial Setup

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/simple-log-service.git
cd simple-log-service
```

### 2. Configure AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### 3. Review Configuration
Edit `terraform/variables.tf` to customize:
- `aws_region` (default: eu-west-2)
- `environment` (dev, staging, prod)
- `alarm_email` (for notifications)
- Capacity settings

## Deployment Steps

### Option 1: Automated Deployment (Recommended)

#### Windows PowerShell
```powershell
# Navigate to scripts directory
cd scripts

# Make script executable (Git Bash)
chmod +x deploy.sh

# Run deployment
bash deploy.sh
```

#### Linux/Mac
```bash
cd scripts
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Manual Deployment

#### Step 1: Initialize Terraform
```bash
cd terraform
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

#### Step 2: Validate Configuration
```bash
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

#### Step 3: Plan Deployment
```bash
terraform plan -out=tfplan
```

Review the plan carefully. Expected resources:
- 1 DynamoDB table
- 2 Lambda functions
- 1 API Gateway
- 1 KMS key
- Multiple IAM roles and policies
- CloudWatch log groups and alarms
- SNS topic
- AWS Config resources (if enabled)

#### Step 4: Apply Deployment
```bash
terraform apply tfplan
```

Deployment takes approximately 5-10 minutes.

#### Step 5: Verify Deployment
```bash
# Get API endpoint
terraform output api_gateway_url

# Get DynamoDB table name
terraform output dynamodb_table_name

# List all outputs
terraform output
```

## Post-Deployment Configuration

### 1. Confirm SNS Subscription
If you provided an email address:
1. Check your email inbox
2. Click the confirmation link from AWS SNS
3. Verify subscription in AWS Console

### 2. Test API Endpoints

#### Windows PowerShell
```powershell
cd ..\scripts
python test_api.py
```

#### Linux/Mac
```bash
cd ../scripts
python test_api.py
```

Expected output:
```
=== Testing Log Ingestion ===
Status Code: 201
✓ Log ingestion successful

=== Testing Log Retrieval ===
Status Code: 200
Logs retrieved: 1
✓ Test passed
```

### 3. Verify CloudWatch Dashboard
```bash
# Get dashboard URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#dashboards:name=$(terraform output -raw cloudwatch_dashboard_name)"
```

### 4. Check AWS Config (if enabled)
```bash
# View Config recorder status
aws configservice describe-configuration-recorder-status --region eu-west-2
```

## Environment-Specific Deployments

### Development Environment
```bash
terraform workspace new dev
terraform workspace select dev
terraform apply -var="environment=dev"
```

### Staging Environment
```bash
terraform workspace new staging
terraform workspace select staging
terraform apply -var="environment=staging"
```

### Production Environment
```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var="environment=prod" -var="enable_deletion_protection=true"
```

## Updating Deployment

### Update Lambda Functions
```bash
# Modify Lambda code in lambda/ directory
cd terraform
terraform apply
```

Terraform will detect changes and redeploy Lambda functions.

### Update Infrastructure
```bash
# Modify Terraform files
terraform plan
terraform apply
```

### Update Configuration
```bash
# Modify variables
terraform apply -var="lambda_memory_size=512"
```

## Rollback Procedures

### Rollback to Previous State
```bash
# List state versions
terraform state list

# Rollback (if using S3 backend with versioning)
aws s3api list-object-versions --bucket your-state-bucket --prefix simple-log-service/

# Restore specific version
aws s3api get-object --bucket your-state-bucket --key simple-log-service/terraform.tfstate --version-id VERSION_ID terraform.tfstate
```

### Emergency Rollback
```bash
# Destroy current deployment
terraform destroy

# Checkout previous version
git checkout <previous-commit>

# Redeploy
terraform apply
```

## Monitoring Deployment

### View Lambda Logs
```bash
# Ingest Lambda
aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --follow

# Read Lambda
aws logs tail /aws/lambda/simple-log-service-dev-read-recent --follow
```

### View API Gateway Logs
```bash
aws logs tail /aws/apigateway/simple-log-service-dev --follow
```

### Check DynamoDB Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=simple-log-service-dev-logs \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Troubleshooting

### Issue: Terraform Init Fails
**Solution**:
```bash
# Clear Terraform cache
rm -rf .terraform
rm .terraform.lock.hcl

# Reinitialize
terraform init
```

### Issue: Lambda Deployment Fails
**Solution**:
```bash
# Check Lambda package
cd lambda/ingest_log
zip -r ../../terraform/ingest_log.zip . -x "tests/*" "__pycache__/*"

# Verify package
unzip -l ../../terraform/ingest_log.zip
```

### Issue: API Gateway Returns 403
**Solution**:
- Verify AWS credentials are configured
- Check IAM permissions
- Ensure request is signed with SigV4

### Issue: DynamoDB Throttling
**Solution**:
```bash
# Increase capacity
terraform apply -var="dynamodb_write_capacity=10"
```

### Issue: KMS Access Denied
**Solution**:
- Check KMS key policy
- Verify IAM role has kms:Decrypt permission
- Ensure service is in key policy

## Cleanup

### Remove All Resources
```bash
# Disable deletion protection first
terraform apply -var="enable_deletion_protection=false"

# Destroy all resources
terraform destroy
```

**Warning**: This will permanently delete:
- All log data in DynamoDB
- Lambda functions
- API Gateway
- CloudWatch logs
- AWS Config data

### Selective Cleanup
```bash
# Remove specific resource
terraform destroy -target=aws_lambda_function.ingest_log
```

## Cost Management

### View Current Costs
```bash
# Get cost estimate
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://cost-filter.json
```

### Set Budget Alerts
```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Security Checklist

- [ ] AWS credentials configured with temporary credentials
- [ ] KMS key created and enabled
- [ ] Deletion protection enabled (production)
- [ ] Point-in-time recovery enabled
- [ ] CloudWatch logs encrypted
- [ ] SNS topic encrypted
- [ ] API Gateway using AWS SigV4 authentication
- [ ] IAM roles follow least privilege
- [ ] AWS Config enabled
- [ ] CloudTrail enabled
- [ ] SNS subscription confirmed

## Next Steps

1. **Run Load Tests**: `python scripts/load_test.py`
2. **Configure Monitoring**: Set up CloudWatch dashboards
3. **Enable Backups**: Configure automated backups
4. **Document APIs**: Create API documentation
5. **Set Up CI/CD**: Configure GitHub Actions
6. **Plan DR**: Test disaster recovery procedures

## Support

For issues:
1. Check CloudWatch logs
2. Review Terraform state
3. Verify AWS service quotas
4. Open GitHub issue

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
