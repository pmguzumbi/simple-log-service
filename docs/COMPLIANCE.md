# Simple Log Service - Compliance & Security Standards

**Version:** 2.0  
**Last Updated:** 2026-02-02  
**Status:** Production

---

## Table of Contents

1. [Overview](#overview)
2. [Security Standards](#security-standards)
3. [Compliance Frameworks](#compliance-frameworks)
4. [AWS Config Rules](#aws-config-rules)
5. [Encryption Standards](#encryption-standards)
6. [Access Control](#access-control)
7. [Audit & Logging](#audit--logging)
8. [Incident Response](#incident-response)
9. [Compliance Checklist](#compliance-checklist)

---

## Overview

Simple Log Service implements enterprise-grade security controls and compliance measures aligned with industry standards and AWS best practices.

**Security Objectives:**
- **Confidentiality**: Protect data from unauthorized access
- **Integrity**: Ensure data accuracy and prevent tampering
- **Availability**: Maintain service uptime and reliability
- **Accountability**: Track all actions and changes

---

## Security Standards

### AWS Well-Architected Framework

**Security Pillar Implementation:**

✅ **Identity & Access Management**
- IAM roles with least privilege
- External IDs for role assumption
- No long-term credentials
- MFA recommended for administrative access

✅ **Detective Controls**
- CloudWatch monitoring and alarms
- AWS Config compliance checks
- CloudTrail audit logging
- SNS notifications for violations

✅ **Infrastructure Protection**
- API Gateway with IAM authorization
- VPC endpoints (optional)
- Security groups and NACLs (if VPC-enabled)

✅ **Data Protection**
- Encryption at rest (KMS)
- Encryption in transit (TLS 1.2+)
- Key rotation (annual)
- Point-in-time recovery

✅ **Incident Response**
- CloudWatch alarms
- SNS notifications
- Automated remediation (AWS Config)
- Runbook documentation

---

## Compliance Frameworks

### SOC 2 Type II

**Control Objectives:**

**CC6.1 - Logical Access**
- ✅ IAM roles with external IDs
- ✅ Temporary credentials (15-minute sessions)
- ✅ CloudTrail logging of all API calls

**CC6.6 - Encryption**
- ✅ KMS customer-managed keys
- ✅ TLS 1.2+ for all communications
- ✅ Encrypted CloudWatch logs

**CC6.7 - Data Retention**
- ✅ Point-in-time recovery (35 days)
- ✅ CloudWatch log retention (7 days)
- ✅ Deletion protection enabled

**CC7.2 - Monitoring**
- ✅ CloudWatch metrics and alarms
- ✅ AWS Config compliance checks
- ✅ SNS notifications

---

### GDPR (General Data Protection Regulation)

**Article 32 - Security of Processing:**

✅ **Pseudonymization & Encryption**
- KMS encryption at rest
- TLS encryption in transit
- Log IDs (UUID v4) for pseudonymization

✅ **Confidentiality**
- IAM authorization
- Least privilege access
- External IDs for role assumption

✅ **Integrity & Availability**
- Multi-AZ deployment
- Point-in-time recovery
- Deletion protection

✅ **Regular Testing**
- Automated testing suite
- Compliance monitoring (AWS Config)
- Quarterly security reviews

---

### HIPAA (Health Insurance Portability and Accountability Act)

**Technical Safeguards:**

✅ **Access Control (§164.312(a)(1))**
- Unique user identification (IAM roles)
- Emergency access procedure (break-glass role)
- Automatic logoff (session timeout)
- Encryption and decryption (KMS)

✅ **Audit Controls (§164.312(b))**
- CloudTrail logging
- CloudWatch monitoring
- AWS Config compliance

✅ **Integrity (§164.312(c)(1))**
- Encryption (KMS)
- Request signing (SigV4)
- Deletion protection

✅ **Transmission Security (§164.312(e)(1))**
- TLS 1.2+ encryption
- AWS SigV4 authentication

**Note:** HIPAA compliance requires Business Associate Agreement (BAA) with AWS.

---

## AWS Config Rules

### Implemented Rules

**1. DynamoDB Encryption Enabled**
- **Rule:** `dynamodb-table-encrypted-kms`
- **Check:** DynamoDB table uses KMS encryption
- **Remediation:** SNS notification to security team
- **Frequency:** Configuration change

**2. DynamoDB Point-in-Time Recovery**
- **Rule:** `dynamodb-pitr-enabled`
- **Check:** Point-in-time recovery is enabled
- **Remediation:** SNS notification to operations team
- **Frequency:** Configuration change

**3. Lambda Function Encryption**
- **Rule:** `lambda-function-settings-check`
- **Check:** Lambda environment variables encrypted
- **Remediation:** SNS notification to development team
- **Frequency:** Configuration change

**4. CloudWatch Log Encryption**
- **Rule:** `cloudwatch-log-group-encrypted`
- **Check:** CloudWatch log groups use KMS encryption
- **Remediation:** SNS notification to operations team
- **Frequency:** Configuration change

---

### Compliance Dashboard

**AWS Config Dashboard Metrics:**
- Total resources: 15
- Compliant resources: 15 (100%)
- Non-compliant resources: 0 (0%)
- Evaluation frequency: Real-time

**SNS Topic:** `simple-log-service-compliance-notifications-prod`

---

## Encryption Standards

### Encryption at Rest

**DynamoDB Table:**
- Algorithm: AES-256
- Key: KMS customer-managed key
- Key Alias: `alias/simple-log-service-prod`
- Key Rotation: Enabled (annual)

**CloudWatch Logs:**
- Algorithm: AES-256
- Key: KMS customer-managed key
- Encryption: Enabled for all log groups

**Lambda Environment Variables:**
- Algorithm: AES-256
- Key: AWS-managed key (default)
- Encryption: Automatic

---

### Encryption in Transit

**API Gateway:**
- Protocol: HTTPS only
- TLS Version: 1.2+ (minimum)
- Cipher Suites: AWS-recommended strong ciphers
- Certificate: AWS Certificate Manager (ACM)

**Lambda → DynamoDB:**
- Protocol: HTTPS
- TLS Version: 1.2+
- AWS internal network (encrypted)

**Client → API Gateway:**
- Protocol: HTTPS
- TLS Version: 1.2+
- AWS SigV4 request signing

---

### Key Management

**KMS Key Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::033667696152:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow Lambda to decrypt",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow DynamoDB to use key",
      "Effect": "Allow",
      "Principal": {
        "Service": "dynamodb.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*"
    }
  ]
}
```

**Key Rotation:**
- Frequency: Annual (automatic)
- Last Rotation: 2026-01-15
- Next Rotation: 2027-01-15

---

## Access Control

### IAM Role Structure

**Principle of Least Privilege:**

**Ingest Role** (`simple-log-service-ingest-prod`):
- `dynamodb:PutItem` on logs table only
- `execute-api:Invoke` on POST /logs only
- `kms:Decrypt` on KMS key only

**Read Role** (`simple-log-service-read-prod`):
- `dynamodb:Query`, `dynamodb:Scan` on logs table only
- `execute-api:Invoke` on GET /logs/recent only
- `kms:Decrypt` on KMS key only

**Full Access Role** (`simple-log-service-full-access-prod`):
- All DynamoDB operations on logs table
- All API Gateway operations
- `kms:Encrypt`, `kms:Decrypt` on KMS key

---

### External IDs

**Purpose:** Prevent confused deputy problem

**Implementation:**
- Ingest Role: `simple-log-service-ingest-prod`
- Read Role: `simple-log-service-read-prod`
- Full Access Role: `simple-log-service-full-prod`

**Rotation Policy:** Quarterly (manual)

---

### Session Management

**Temporary Credentials:**
- Duration: 900 seconds (15 minutes)
- Renewal: Automatic (via AWS SDK)
- Expiration: Hard cutoff (no grace period)

**Best Practices:**
- Use temporary credentials only
- Rotate external IDs quarterly
- Enable MFA for administrative roles
- Review IAM policies monthly

---

## Audit & Logging

### CloudTrail

**Configuration:**
- Trail Name: `simple-log-service-trail`
- S3 Bucket: `simple-log-service-cloudtrail-logs`
- Encryption: KMS encrypted
- Log File Validation: Enabled
- Multi-Region: Enabled

**Events Logged:**
- All API calls (read and write)
- IAM role assumptions
- KMS key usage
- DynamoDB operations
- Lambda invocations

**Retention:** 90 days (S3 lifecycle policy)

---

### CloudWatch Logs

**Log Groups:**
- `/aws/lambda/simple-log-service-ingest-prod` (7 days)
- `/aws/lambda/simple-log-service-read-recent-prod` (7 days)
- `/aws/apigateway/simple-log-service-prod` (7 days)

**Log Format:**
- JSON structured logging
- Timestamp (ISO 8601)
- Request ID (correlation)
- Error details (if applicable)

**Encryption:** KMS customer-managed key

---

### Monitoring & Alerting

**CloudWatch Alarms:**

**Lambda Errors:**
- Metric: `Errors`
- Threshold: > 5 errors in 5 minutes
- Action: SNS notification
- Severity: High

**DynamoDB Throttling:**
- Metric: `UserErrors` (throttled requests)
- Threshold: > 10 in 1 minute
- Action: SNS notification
- Severity: Medium

**API Gateway 5xx Errors:**
- Metric: `5XXError`
- Threshold: > 10 in 5 minutes
- Action: SNS notification
- Severity: High

**SNS Topic:** `simple-log-service-alarms-prod`

---

## Incident Response

### Incident Classification

**Severity Levels:**

**Critical (P1):**
- Data breach or unauthorized access
- Service outage (> 1 hour)
- Compliance violation

**High (P2):**
- Elevated error rates (> 10%)
- Performance degradation (> 50%)
- Security misconfiguration

**Medium (P3):**
- Intermittent errors (< 10%)
- Minor performance issues
- Non-critical compliance findings

**Low (P4):**
- Informational alerts
- Planned maintenance
- Documentation updates

---

### Response Procedures

**P1 Incident Response:**
1. **Detection** (0-5 minutes)
   - CloudWatch alarm triggers
   - SNS notification sent
   - On-call engineer paged

2. **Assessment** (5-15 minutes)
   - Review CloudWatch logs
   - Check CloudTrail for unauthorized access
   - Assess impact and scope

3. **Containment** (15-30 minutes)
   - Disable compromised credentials
   - Rotate external IDs
   - Enable additional logging

4. **Eradication** (30-60 minutes)
   - Remove unauthorized access
   - Patch vulnerabilities
   - Update IAM policies

5. **Recovery** (1-2 hours)
   - Restore from point-in-time recovery (if needed)
   - Verify system integrity
   - Resume normal operations

6. **Post-Incident** (24-48 hours)
   - Root cause analysis
   - Update runbooks
   - Implement preventive measures

---

### Runbook: Data Breach Response

**Scenario:** Unauthorized access to DynamoDB table detected

**Steps:**
1. Disable compromised IAM credentials immediately
2. Review CloudTrail logs for access patterns
3. Identify affected data (service_name, timestamp range)
4. Notify security team and stakeholders
5. Rotate all external IDs
6. Update IAM policies to prevent recurrence
7. Document incident in security log
8. Conduct post-incident review

**Contacts:**
- Security Team: security@example.com
- On-Call Engineer: oncall@example.com
- AWS Support: Premium Support (24/7)

---

## Compliance Checklist

### Monthly Review

- [ ] Review IAM policies for least privilege
- [ ] Check CloudWatch alarms for false positives
- [ ] Verify KMS key rotation schedule
- [ ] Review CloudTrail logs for anomalies
- [ ] Update external IDs (quarterly)
- [ ] Test disaster recovery procedures
- [ ] Review AWS Config compliance dashboard
- [ ] Update documentation (if needed)

---

### Quarterly Review

- [ ] Rotate external IDs for all roles
- [ ] Conduct security audit (internal)
- [ ] Review and update incident response runbooks
- [ ] Test backup and restore procedures
- [ ] Review cost optimization opportunities
- [ ] Update compliance documentation
- [ ]
