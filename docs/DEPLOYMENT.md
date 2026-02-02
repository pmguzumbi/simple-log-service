SIMPLE LOG SERVICE - DEPLOYMENT GUIDE

Version: 2.0
Last Updated: 2026-02-02
Status: Production

================================================================================
TABLE OF CONTENTS
================================================================================
Prerequisites
Initial Setup
Deployment Steps
Post-Deployment Configuration
Testing Deployment
Environment-Specific Deployments
Updating Deployment
Rollback Procedures
Monitoring Deployment
Troubleshooting
Cleanup
Security Checklist

================================================================================
PREREQUISITES
================================================================================

REQUIRED SOFTWARE

Terraform (>= 1.5.0)
  Download: https://www.terraform.io/downloads
  Verify installation:
    terraform --version

AWS CLI (>= 2.0)
  Download: https://aws.amazon.com/cli/
  Verify installation:
    aws --version

Python 3.12
  Download: https://www.python.org/downloads/
  Verify installation:
    python --version

Git
  Download: https://git-scm.com/downloads
  Verify installation:
    git --version

PowerShell (5.1+ or PowerShell Core)
  Check version:
    $PSVersionTable.PSVersion

VS Code (Recommended IDE)
  Download: https://code.visualstudio.com/

AWS ACCOUNT REQUIREMENTS

Account Details:
• Active AWS account (Account ID: <Account ID>)
• IAM role with administrator access
• AWS CLI configured with credentials
• Access to us-east-1 region (N. Virginia)

REQUIRED IAM PERMISSIONS

Create an IAM policy with the following permissions:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:UpdateTable",
        "dynamodb:TagResource",
        "dynamodb:UpdateContinuousBackups",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "apigateway:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:EnableKeyRotation",
        "kms:PutKeyPolicy",
        "kms:TagResource",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms",
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:Subscribe",
        "sns:SetTopicAttributes",
        "config:PutConfigRule",
        "config:DeleteConfigRule",
        "config:DescribeConfigRules",
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    }
  ]
}

================================================================================
INITIAL SETUP
================================================================================

STEP 1: CLONE REPOSITORY

git clone https://github.com/pmguzumbi/simple-log-service.git
cd simple-log-service

STEP 2: CONFIGURE AWS CREDENTIALS

aws configure

Enter the following when prompted:
• AWS Access Key ID: YOURACCESSKEY
• AWS Secret Access Key: YOURSECRETKEY
• Default region name: us-east-1
• Default output format: json

Verify credentials:

aws sts get-caller-identity

Expected output:

{
    "roleID": "ASIAXXXXXXXXXXXXXXXXX",
    "Account": "<Account ID>",
    "Arn": "arn:aws:iam::<Account ID>:role/your-rolename"
}

STEP 3: REVIEW CONFIGURATION

Edit terraform/variables.tf to customize settings:

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = "ops@example.com"
}

variable "enabledeletionprotection" {
  description = "Enable deletion protection for DynamoDB"
  type        = bool
  default     = true
}

================================================================================
DEPLOYMENT STEPS
================================================================================

STEP 1: INITIALIZE TERRAFORM

cd terraform
terraform init

Expected output:

Initializing the backend...
Initializing provider plugins...
• Finding hashicorp/aws versions matching "~> 5.0"...
• Installing hashicorp/aws v5.x.x...
• Installed hashicorp/aws v5.x.x

Terraform has been successfully initialized!

If initialization fails:

rm -rf .terraform
rm .terraform.lock.hcl
terraform init

STEP 2: VALIDATE CONFIGURATION

terraform validate

Expected output:

Success! The configuration is valid.

STEP 3: PLAN DEPLOYMENT

terraform plan -out=tfplan

Expected resources (approximately 25-30 resources):
• 1 DynamoDB table
• 2 Lambda functions
• 1 API Gateway (REST API)
• 1 KMS customer-managed key
• 6 IAM roles
• 3 CloudWatch log groups
• 3 CloudWatch alarms
• 1 SNS topic
• 4 AWS Config rules
• Supporting resources (policies, permissions, etc.)

STEP 4: APPLY DEPLOYMENT

terraform apply tfplan

Deployment timeline: 5-10 minutes

Expected output:

Apply complete! Resources: 28 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "https://v22n8t8394.execute-api.us-east-1.amazonaws.com/prod"
dynamodbtablename = "simple-log-service-logs-prod"
ingestlambdafunction_name = "simple-log-service-ingest-prod"
readrecentlambdafunctionname = "simple-log-service-read-recent-prod"
logingestrole_arn = "arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod"
logreadrole_arn = "arn:aws:iam::<Account ID>:role/simple-log-service-read-prod"

STEP 5: VERIFY DEPLOYMENT

Get all outputs:

terraform output

Get specific output:

terraform output api_endpoint
terraform output dynamodbtablename

Save outputs to file:

terraform output -json > outputs.json

================================================================================
POST-DEPLOYMENT CONFIGURATION
================================================================================
CONFIRM SNS SUBSCRIPTION

Check your email for AWS SNS subscription confirmation:
• Sender: AWS Notifications
• Subject: AWS Notification - Subscription Confirmation
• Action: Click the confirmation link

Verify subscription:

aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw snstopicarn)
VERIFY IAM ROLES

Check ingest role:

aws iam get-role --role-name simple-log-service-ingest-prod

Check read role:

aws iam get-role --role-name simple-log-service-read-prod

Check full access role:

aws iam get-role --role-name simple-log-service-full-access-prod

External IDs:
• Ingest: simple-log-service-ingest-prod
• Read: simple-log-service-read-prod
• Full Access: simple-log-service-full-prod
VERIFY KMS KEY

Get key ID:

KMSKEYID=$(terraform output -raw kmskeyid)

Describe key:

aws kms describe-key --key-id $KMSKEYID

Check key rotation:

aws kms get-key-rotation-status --key-id $KMSKEYID

Expected output:

{
    "KeyRotationEnabled": true
}
VERIFY DYNAMODB CONFIGURATION

aws dynamodb describe-table --table-name simple-log-service-logs-prod --query 'Table.{Status:TableStatus,ItemCount:ItemCount,Encryption:SSEDescription.Status,PITR:PointInTimeRecoveryDescription.PointInTimeRecoveryStatus}'

Expected output:

{
    "Status": "ACTIVE",
    "ItemCount": 0,
    "Encryption": "ENABLED",
    "PITR": "ENABLED"
}

================================================================================
TESTING DEPLOYMENT
================================================================================

TEST 1: COMPLETE LAMBDA TEST

Purpose: Validates Lambda functions with IAM role assumption

cd C:\simple-log-service\scripts
.\complete-test-script.ps1 -TestCount 5 -Environment prod

Expected output:

========================================
Simple Log Service - Basic Test
========================================
Start Time: 2026-02-02 13:30:15

[STEP] Checking Prerequisites
  [PASS] Terraform directory exists
  [PASS] Terraform state file exists
  [PASS] AWS credentials valid

[STEP] Testing Ingest Role (Write Access)
  [PASS] Role assumed successfully
  [PASS] Ingest tests: 5/5 successful

[STEP] Testing Read Role (Read Access)
  [PASS] Read test successful (Retrieved 5 logs)

========================================
ALL TESTS PASSED
========================================

TEST 2: API GATEWAY TEST

Purpose: Validates API Gateway endpoints with AWS SigV4 authentication

cd C:\simple-log-service\scripts
.\api-gateway-test.ps1 -TestCount 3 -Environment prod

Expected output:

========================================
Simple Log Service - API Gateway Test
========================================

[STEP] Testing POST /logs (Ingest Endpoint)
  [PASS] POST request 1/3 successful
  [PASS] POST request 2/3 successful
  [PASS] POST request 3/3 successful

[STEP] Testing GET /logs/recent (Read Endpoint)
  [PASS] GET /logs/recent successful
  [PASS] Retrieved 3 logs

========================================
ALL API GATEWAY TESTS PASSED
========================================

TEST 3: PYTHON API TEST

Purpose: Python-based API testing with pytest

cd C:\simple-log-service\scripts
python -m pytest test_api.py -v -s

Expected output:

============================= test session starts =============================
collected 2 items

testapi.py::testingest_log PASSED                                      [ 50%]
testapi.py::testread_recent PASSED                                     [100%]

============================== 2 passed in 3.45s ==============================

================================================================================
ENVIRONMENT-SPECIFIC DEPLOYMENTS
================================================================================

DEVELOPMENT ENVIRONMENT

Configuration:
• Lower capacity settings
• Deletion protection disabled
• Shorter log retention (3 days)

Deploy:

terraform apply -var="environment=dev" -var="enabledeletionprotection=false" -var="logretentiondays=3"

STAGING ENVIRONMENT

Configuration:
• Production-like settings
• Deletion protection enabled
• Standard log retention (7 days)

Deploy:

terraform apply -var="environment=staging" -var="enabledeletionprotection=true"

PRODUCTION ENVIRONMENT

Configuration:
• Maximum security settings
• Deletion protection enabled
• Extended log retention (7 days)
• Point-in-time recovery enabled

Deploy:

terraform apply -var="environment=prod" -var="enabledeletionprotection=true" -var="logretentiondays=7"

================================================================================
UPDATING DEPLOYMENT
================================================================================

UPDATE LAMBDA FUNCTIONS

After modifying Lambda code:

cd terraform
terraform plan
terraform apply

Note: Terraform automatically creates new Lambda deployment packages when code changes are detected.

UPDATE INFRASTRUCTURE CONFIGURATION

terraform plan
terraform apply

Example - increase Lambda memory:

terraform apply -var="lambdamemorysize=512"

UPDATE VARIABLES

terraform apply -var="alarm_email=newops@example.com"

================================================================================
ROLLBACK PROCEDURES
================================================================================

ROLLBACK TO PREVIOUS GIT VERSION

View commit history:

git log --oneline

Checkout previous version:

git checkout 

Destroy current deployment:

cd terraform
terraform destroy -auto-approve

Redeploy previous version:

terraform init
terraform apply -auto-approve

Return to main branch:

git checkout main

ROLLBACK LAMBDA FUNCTION ONLY

Revert Lambda code:

git checkout HEAD~1 lambda/ingest/index.py

Redeploy Lambda:

cd terraform
terraform apply -target=awslambdafunction.ingest_lambda

================================================================================
MONITORING DEPLOYMENT
================================================================================

VIEW LAMBDA LOGS

Ingest Lambda:

aws logs tail /aws/lambda/simple-log-service-ingest-prod --follow

Read Lambda:

aws logs tail /aws/lambda/simple-log-service-read-recent-prod --follow

Filter by error:

aws logs tail /aws/lambda/simple-log-service-ingest-prod --filter-pattern "ERROR" --follow

VIEW API GATEWAY LOGS

aws logs tail /aws/apigateway/simple-log-service-prod --follow

CHECK DYNAMODB METRICS

Consumed capacity:

aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ConsumedWriteCapacityUnits --dimensions Name=TableName,Value=simple-log-service-logs-prod --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum

Throttled requests:

aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name UserErrors --dimensions Name=TableName,Value=simple-log-service-logs-prod --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum

CHECK CLOUDWATCH ALARMS

List all alarms:

aws cloudwatch describe-alarms --alarm-name-prefix "simple-log-service"

Check specific alarm:

aws cloudwatch describe-alarms --alarm-names "simple-log-service-prod-lambda-errors"

================================================================================
TROUBLESHOOTING
================================================================================

ISSUE 1: TERRAFORM INIT FAILS

Symptoms:
  Error: Failed to install provider

Solutions:

Clear Terraform cache:

rm -rf .terraform
rm .terraform.lock.hcl
terraform init

If behind proxy:

export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
terraform init

ISSUE 2: LAMBDA DEPLOYMENT FAILS

Symptoms:
  Error: error creating Lambda Function: InvalidParameterValueException

Solutions:

Check Lambda package:

ls -lh terraform/lambda_packages/

Verify Lambda code syntax:

cd lambda/ingest
python -m py_compile index.py

Manually create package:

cd lambda/ingest
zip -r ../../terraform/lambdapackages/ingest.zip . -x "tests/" "pycache/" ".pytestcache/*"

Verify package contents:

unzip -l ../../terraform/lambda_packages/ingest.zip

ISSUE 3: API GATEWAY RETURNS 403 FORBIDDEN

Symptoms:
  {
    "message": "Forbidden"
  }

Solutions:
Verify AWS credentials:

aws sts get-caller-identity
Check IAM role permissions:

aws iam get-role-policy --role-name simple-log-service-ingest-prod --policy-name IngestPolicy
Verify external ID:
   Ensure external ID matches: simple-log-service-ingest-prod
Test role assumption:

aws sts assume-role --role-arn "arn:aws:iam::<Account ID>:role/simple-log-service-ingest-prod" --role-session-name "test-session" --external-id "simple-log-service-ingest-prod"

ISSUE 4: DYNAMODB THROTTLING

Symptoms:
  ProvisionedThroughputExceededException

Solutions:
Check current capacity:

aws dynamodb describe-table --table-name simple-log-service-logs-prod --query 'Table.BillingModeSummary'
Switch to on-demand:

terraform apply -var="dynamodbbillingmode=PAYPERREQUEST"
Increase provisioned capacity:

terraform apply -var="dynamodbwritecapacity=10" -var="dynamodbreadcapacity=10"

ISSUE 5: KMS ACCESS DENIED

Symptoms:
  AccessDeniedException: User is not authorized to perform: kms:Decrypt

Solutions:
Check KMS key policy:

aws kms get-key-policy --key-id $(terraform output -raw kmskeyid) --policy-name default
Verify Lambda execution role:

aws iam get-role-policy --role-name simple-log-service-lambda-execution-prod --policy-name KMSPolicy
Update KMS key policy:
• Edit terraform/kms.tf
• Add Lambda execution role to key policy
• Apply changes: terraform apply

ISSUE 6: CLOUDWATCH LOGS NOT APPEARING

Symptoms:
  Lambda executes successfully but no logs in CloudWatch

Solutions:
Check log group exists:

aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/simple-log-service"
Verify Lambda execution role:

aws iam get-role-policy --role-name simple-log-service-lambda-execution-prod --policy-name CloudWatchLogsPolicy
Check Lambda configuration:

aws lambda get-function-configuration --function-name simple-log-service-ingest-prod

ISSUE 7: PYTEST CACHE ACCESS DENIED

Symptoms:
  Error: Archive creation error
  error archiving directory: error encountered during file walk: open
  ..\lambda\ingest\tests\.pytest_cache: Access is denied.

Solutions:
Delete pytest cache:

Remove-Item -Recurse -Force lambda\ingest\tests\.pytest_cache
Remove-Item -Recurse -Force lambda\readrecent\tests\.pytestcache
Update lambda.tf to exclude test directories:

data "archivefile" "ingestlambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  outputpath = "${path.module}/lambdapackages/ingest.zip"

  excludes = [
    "tests",
    "tests/",
    "pycache",
    "/pycache",
    "*.pyc",
    ".pytest_cache",
    "/.pytestcache"
  ]
}
Reinitialize and apply:

terraform init
terraform apply

================================================================================
CLEANUP
================================================================================

REMOVE ALL RESOURCES

Warning: This will permanently delete all data and resources.
Disable deletion protection:

terraform apply -var="enabledeletionprotection=false"
Destroy all resources:

terraform destroy

Type yes when prompted. Destruction takes 5-10 minutes.

Resources deleted:
• DynamoDB table (all log data)
• Lambda functions
• API Gateway
• KMS key (scheduled for deletion in 30 days)
• IAM roles and policies
• CloudWatch log groups (all logs)
• CloudWatch alarms
• SNS topic
• AWS Config rules

SELECTIVE CLEANUP

Remove Lambda function only:

terraform destroy -target=awslambdafunction.ingest_lambda

Remove DynamoDB table only:

terraform destroy -target=awsdynamodbtable.logs

CLEANUP TEST DATA

Scan for test logs:

aws dynamodb scan --table-name simple-log-service-logs-prod --filter-expression "servicename = :svc" --expression-attribute-values '{":svc":{"S":"test-service"}}' --projection-expression "servicename, timestamp"

================================================================================
SECURITY CHECKLIST
================================================================================

PRE-DEPLOYMENT

  [ ] AWS credentials configured (not root account)
  [ ] IAM role has minimum required permissions
  [ ] MFA enabled for AWS account
  [ ] Git repository is private (if sensitive data)

POST-DEPLOYMENT

  [ ] KMS key created and enabled
  [ ] KMS key rotation enabled
  [ ] Deletion protection enabled (production)
  [ ] Point-in-time recovery enabled
  [ ] CloudWatch logs encrypted
  [ ] SNS topic encrypted
  [ ] API Gateway using AWS_IAM authorization
  [ ] IAM roles follow least privilege
  [ ] External IDs configured
  [ ] AWS Config enabled
  [ ] CloudTrail enabled (recommended)
  [ ] SNS subscription confirmed
  [ ] CloudWatch alarms configured
  [ ] Budget alerts configured

ONGOING

  [ ] Review IAM policies monthly
  [ ] Rotate external IDs quarterly
  [ ] Review CloudWatch alarms weekly
  [ ] Check AWS Config compliance weekly
  [ ] Review CloudTrail logs for anomalies
  [ ] Test disaster recovery quarterly
  [ ] Update documentation as needed

================================================================================
COST MANAGEMENT
================================================================================

VIEW CURRENT COSTS

aws ce get-cost-and-usage --time-period Start=2026-02-01,End=2026-02-28 --granularity MONTHLY --metrics BlendedCost --group-by Type=TAG,Key=Project

SET BUDGET ALERTS

Create budget:

aws budgets create-budget --account-id <Account ID> --budget file://budget.json --notifications-with-subscribers file://notifications.json

budget.json:

{
  "BudgetName": "simple-log-service-monthly",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "50.00",
    "Unit": "USD"
  }
}

notifications.json:

{
  "Notification": {
    "NotificationType": "ACTUAL",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": 80.0,
    "ThresholdType": "PERCENTAGE"
  },
  "Subscribers": [
    {
      "SubscriptionType": "EMAIL",
      "Address": "ops@example.com"
    }
  ]
}

================================================================================
NEXT STEPS
================================================================================

After successful deployment:
Run load tests:

cd scripts
python load_test.py
Configure monitoring dashboard
• Access CloudWatch dashboard
• Customize metrics and widgets
• Set up additional alarms
Enable automated backups
• Configure DynamoDB on-demand backups
• Set up S3 archival for old logs
Document APIs
• Create API documentation (Swagger/OpenAPI)
• Share with development teams
Set up CI/CD
• Configure GitHub Actions workflow
• Automate testing and deployment
Plan disaster recovery
• Test point-in-time recovery
• Document recovery procedures
• Conduct DR drills
Optimize costs
• Review usage patterns
• Consider provisioned capacity for steady workloads
• Implement S3 archival for old logs

================================================================================
SUPPORT
================================================================================

For Issues:
Check Troubleshooting section above
Review CloudWatch logs for errors
Verify Terraform state: terraform show
Check AWS service quotas
Open GitHub issue: https://github.com/pmguzumbi/simple-log-service/issues

================================================================================
ADDITIONAL RESOURCES
================================================================================

AWS Lambda Documentation:
  https://docs.aws.amazon.com/lambda/

DynamoDB Best Practices:
  https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html

API Gateway Documentation:
  https://docs.aws.amazon.com/apigateway/

Terraform AWS Provider:
  https://registry.terraform.io/providers/hashicorp/aws/latest/docs

================================================================================
DOCUMENT INFORMATION
================================================================================

Document Owner: Infrastructure Team
Review Cycle: Quarterly
Next Review: 2026-05-02

================================================================================
END OF DOCUMENT
================================================================================
