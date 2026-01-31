
# Compliance Documentation

## Overview

This document outlines the compliance monitoring, security controls, and regulatory adherence for the Simple Log Service. The system uses AWS Config for continuous compliance monitoring with automated remediation and SNS notifications.

## Compliance Framework

### Regulatory Requirements

**Applicable Standards**:
- AWS Well-Architected Framework
- GDPR (General Data Protection Regulation)
- SOC 2 Type II
- ISO 27001
- NIST Cybersecurity Framework

**Compliance Scope**:
- Data encryption (at rest and in transit)
- Access control and authentication
- Audit logging and monitoring
- Data retention and deletion
- Incident response
- Business continuity

## AWS Config Rules

### Enabled Rules

The following AWS Config rules continuously monitor compliance:

#### 1. DynamoDB Encryption at Rest

**Rule**: `dynamodb-table-encrypted-kms`

**Description**: Ensures DynamoDB tables are encrypted using KMS customer-managed keys

**Compliance Check**:
```bash
aws configservice describe-compliance-by-config-rule \
  --config-rule-names dynamodb-table-encrypted-kms
```

**Remediation** (if non-compliant):
```bash
# Cannot enable encryption on existing table
# Must create new table with encryption
cd terraform
terraform apply -var="enable_kms_encryption=true"
```

**Notification**: SNS alert sent immediately

#### 2. DynamoDB Point-in-Time Recovery

**Rule**: `dynamodb-pitr-enabled`

**Description**: Ensures point-in-time recovery is enabled for data protection

**Compliance Check**:
```bash
aws dynamodb describe-continuous-backups \
  --table-name simple-log-service-dev-logs
```

**Remediation** (if non-compliant):
```bash
aws dynamodb update-continuous-backups \
  --table-name simple-log-service-dev-logs \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

**Notification**: SNS alert sent immediately

#### 3. Lambda Function Encryption

**Rule**: `lambda-function-settings-check`

**Description**: Ensures Lambda environment variables are encrypted with KMS

**Compliance Check**:
```bash
aws lambda get-function-configuration \
  --function-name simple-log-service-dev-ingest-log \
  --query 'KMSKeyArn'
```

**Remediation** (if non-compliant):
```bash
aws lambda update-function-configuration \
  --function-name simple-log-service-dev-ingest-log \
  --kms-key-arn arn:aws:kms:eu-west-2:033667696152:key/<key-id>
```

**Notification**: SNS alert sent immediately

#### 4. CloudWatch Log Encryption

**Rule**: `cloudwatch-log-group-encrypted`

**Description**: Ensures CloudWatch log groups are encrypted with KMS

**Compliance Check**:
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/simple-log-service \
  --query 'logGroups[*].[logGroupName,kmsKeyId]'
```

**Remediation** (if non-compliant):
```bash
# Must recreate log group with encryption
aws logs delete-log-group \
  --log-group-name /aws/lambda/simple-log-service-dev-ingest-log

aws logs create-log-group \
  --log-group-name /aws/lambda/simple-log-service-dev-ingest-log \
  --kms-key-id arn:aws:kms:eu-west-2:033667696152:key/<key-id>
```

**Notification**: SNS alert sent immediately

#### 5. S3 Bucket Encryption

**Rule**: `s3-bucket-server-side-encryption-enabled`

**Description**: Ensures S3 buckets (Config bucket) are encrypted

**Compliance Check**:
```bash
aws s3api get-bucket-encryption \
  --bucket simple-log-service-config-033667696152
```

**Remediation** (if non-compliant):
```bash
aws s3api put-bucket-encryption \
  --bucket simple-log-service-config-033667696152 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "arn:aws:kms:eu-west-2:033667696152:key/<key-id>"
      }
    }]
  }'
```

**Notification**: SNS alert sent immediately

#### 6. S3 Bucket Versioning

**Rule**: `s3-bucket-versioning-enabled`

**Description**: Ensures S3 buckets have versioning enabled for data protection

**Compliance Check**:
```bash
aws s3api get-bucket-versioning \
  --bucket simple-log-service-config-033667696152
```

**Remediation** (if non-compliant):
```bash
aws s3api put-bucket-versioning \
  --bucket simple-log-service-config-033667696152 \
  --versioning-configuration Status=Enabled
```

**Notification**: SNS alert sent immediately

#### 7. IAM Password Policy

**Rule**: `iam-password-policy`

**Description**: Ensures strong password policy is enforced

**Compliance Check**:
```bash
aws iam get-account-password-policy
```

**Remediation** (if non-compliant):
```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --max-password-age 90 \
  --password-reuse-prevention 24
```

**Notification**: SNS alert sent immediately

#### 8. Root Account MFA

**Rule**: `root-account-mfa-enabled`

**Description**: Ensures root account has MFA enabled

**Compliance Check**:
```bash
aws iam get-account-summary \
  --query 'SummaryMap.AccountMFAEnabled'
```

**Remediation** (if non-compliant):
- Manual: Enable MFA in AWS Console for root account

**Notification**: SNS alert sent immediately

## Security Controls

### Encryption

**Data at Rest**:
- ✅ DynamoDB: KMS customer-managed key
- ✅ Lambda environment variables: KMS encryption
- ✅ CloudWatch Logs: KMS encryption
- ✅ S3 (Config bucket): KMS encryption
- ✅ SNS topics: KMS encryption

**Data in Transit**:
- ✅ API Gateway: TLS 1.2+ only
- ✅ DynamoDB: TLS 1.2+ (AWS SDK)
- ✅ Lambda: TLS 1.2+ (AWS SDK)
- ✅ CloudWatch: TLS 1.2+ (AWS SDK)

**Key Management**:
```
KMS Key: Customer-managed
Key Rotation: Enabled (annual)
Key Policy: Least privilege
Key Deletion: 30-day window
```

### Access Control

**Authentication**:
- ✅ API Gateway: AWS SigV4 (IAM authentication)
- ✅ Lambda: IAM execution role
- ✅ DynamoDB: IAM policies
- ✅ No long-term credentials

**Authorization**:
- ✅ IAM roles: Least privilege principle
- ✅ Resource policies: Explicit deny for unauthorized access
- ✅ KMS key policies: Service-specific permissions
- ✅ S3 bucket policies: Block public access

**Temporary Credentials**:
```
Session Duration: 1 hour (default)
Credential Rotation: Automatic
MFA Requirement: Optional (recommended for production)
External ID: Required for role assumption
```

### Audit Logging

**CloudTrail**:
```
Status: Enabled (account-wide)
Log File Validation: Enabled
S3 Bucket: Encrypted
Retention: 90 days
Events Logged: All API calls
```

**CloudWatch Logs**:
```
Lambda Logs: All invocations
API Gateway Logs: All requests
Retention: 7 days (dev), 30 days (prod)
Encryption: KMS
```

**AWS Config**:
```
Configuration History: All changes
Snapshot Frequency: Every 24 hours
Retention: 7 years
Delivery: S
