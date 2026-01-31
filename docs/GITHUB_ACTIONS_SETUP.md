# GitHub Actions Setup Guide

## Overview

This guide explains how to set up GitHub Actions to automatically test and deploy the Simple Log Service using OIDC (OpenID Connect) for secure, temporary AWS credentials.

## Prerequisites

- GitHub repository created
- AWS account (033667696152)
- AWS CLI configured with admin access
- Git installed

## Step 1: Configure AWS OIDC Provider and IAM Role

### Option A: Automated Setup (Recommended)

```bash
# Make script executable
chmod +x github-oidc-role-setup.sh

# Edit script to set your GitHub org/repo
nano github-oidc-role-setup.sh
# Update: GITHUB_ORG and GITHUB_REPO

# Run setup script
./github-oidc-role-setup.sh
```

### Option B: Manual Setup

1. **Create OIDC Provider**:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **Create IAM Role**:
```bash
# Create trust-policy.json (see github-oidc-role-setup.sh)
aws iam create-role \
  --role-name GitHubActionsDeploymentRole \
  --assume-role-policy-document file://trust-policy.json
```

3. **Attach Permissions**:
```bash
aws iam attach-role-policy \
  --role-name GitHubActionsDeploymentRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## Step 2: Configure GitHub Repository

### 1. Add Workflow File

The workflow file is already in `.github/workflows/terraform.yml`

### 2. Update Workflow Variables

Edit `.github/workflows/terraform.yml`:

```yaml
env:
  AWS_REGION: eu-west-2
  AWS_ACCOUNT_ID: '033667696152'  # Your account
```

Update role ARN in all jobs:
```yaml
role-to-assume: arn:aws:iam::033667696152:role/GitHubActionsDeploymentRole
```

### 3. Configure GitHub Environments (Optional)

For production deployments with approval:

1. Go to repository **Settings** → **Environments**
2. Create environment: `production`
3. Add protection rules:
   - Required reviewers: Add yourself
   - Wait timer: 5 minutes (optional)

## Step 3: Test GitHub Actions

### 1. Push to Repository

```bash
# Add all files
git add .

# Commit
git commit -m "Add GitHub Actions workflow with OIDC"

# Push to main branch
git push origin main
```

### 2. Monitor Workflow

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Monitor each job:
   - ✓ Validate Terraform
   - ✓ Run Unit Tests
   - ✓ Deploy to AWS
   - ✓ Run Integration Tests

### 3. View Deployment Summary

After successful deployment, check:
- **Summary** tab for deployment details
- **Logs** for detailed execution
- **AWS Console** for deployed resources

## Workflow Triggers

### Automatic Triggers

**On Push to Main**:
- Validates Terraform
- Runs unit tests
- Deploys to AWS
- Runs integration tests

**On Pull Request**:
- Validates Terraform
- Runs unit tests
- Creates Terraform plan
- Comments plan on PR

### Manual Trigger

1. Go to **Actions** tab
2. Select "Deploy Simple Log Service"
3. Click **Run workflow**
4. Choose environment (dev/staging/prod)
5. Click **Run workflow**

## Workflow Jobs

### 1. Validate
- Checks Terraform formatting
- Validates Terraform syntax
- Runs on all branches

### 2. Test
- Sets up Python 3.11
- Installs dependencies
- Runs pytest unit tests
- Uploads test results

### 3. Plan (Pull Requests Only)
- Assumes AWS role via OIDC
- Runs Terraform plan
- Comments plan on PR
- No changes applied

### 4. Deploy (Main Branch Only)
- Assumes AWS role via OIDC
- Applies Terraform changes
- Runs integration tests
- Creates deployment summary

### 5. Manual Deploy
- Triggered manually
- Deploys to chosen environment
- Requires approval (if configured)

## Security Features

### OIDC Benefits
- ✅ No long-term credentials stored
- ✅ Temporary credentials (1 hour)
- ✅ Automatic credential rotation
- ✅ Audit trail via CloudTrail
- ✅ Fine-grained permissions

### GitHub Secrets (Not Required)
With OIDC, you don't need to store:
- ❌ AWS_ACCESS_KEY_ID
- ❌ AWS_SECRET_ACCESS_KEY
- ❌ AWS_SESSION_TOKEN

### Permissions
Workflow has minimal permissions:
```yaml
permissions:
  id-token: write      # For OIDC token
  contents: read       # For code checkout
  pull-requests: write # For PR comments
```

## Troubleshooting

### Issue: OIDC Authentication Fails

**Error**: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Solution**:
1. Verify OIDC provider exists:
```bash
aws iam list-open-id-connect-providers
```

2. Check trust policy allows your repository:
```bash
aws iam get-role --role-name GitHubActionsDeploymentRole
```

3. Verify repository name matches exactly in trust policy

### Issue: Terraform Init Fails

**Error**: "Error configuring the backend"

**Solution**:
- Ensure S3 backend is commented out (or configured)
- Check AWS credentials are valid
- Verify region is correct

### Issue: Unit Tests Fail

**Error**: "ModuleNotFoundError: No module named 'moto'"

**Solution**:
```yaml
# Ensure dependencies are installed
- name: Install dependencies
  run: |
    pip install pytest moto boto3
```

### Issue: Integration Tests Fail

**Error**: "API endpoint not found"

**Solution**:
- Verify Terraform outputs are captured
- Check API Gateway was deployed
- Ensure environment variable is set

## Monitoring

### View Workflow Runs
```bash
# Using GitHub CLI
gh run list
gh run view <run-id>
gh run watch
```

### View AWS Resources
```bash
# List Lambda functions
aws lambda list-functions --region eu-west-2

# List DynamoDB tables
aws dynamodb list-tables --region eu-west-2

# View CloudWatch logs
aws logs tail /aws/lambda/simple-log-service-dev-ingest-log --follow
```

## Cost Considerations

### GitHub Actions
- **Free tier**: 2,000 minutes/month (public repos unlimited)
- **Cost**: $0.008 per minute (private repos, after free tier)
- **Estimated**: $0-5/month for this project

### AWS Resources
- See COST_ESTIMATION.md for detailed breakdown
- **Estimated**: $15-50/month

## Best Practices

1. **Branch Protection**: Require PR reviews before merging to main
2. **Environment Protection**: Add approval for production deployments
3. **Secrets Management**: Use GitHub environments for sensitive values
4. **Monitoring**: Set up notifications for failed workflows
5. **Testing**: Always run tests before deployment
6. **Rollback**: Keep previous Terraform state for rollback

## Next Steps

1. ✅ Configure OIDC provider and IAM role
2. ✅ Push code to GitHub
3. ✅ Monitor first workflow run
4. ✅ Verify deployment in AWS Console
5. ✅ Test API endpoints
6. ✅ Set up branch protection
7. ✅ Configure environment approvals
8. ✅ Add status badges to README

## Additional Resources

- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
