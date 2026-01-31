#!/bin/bash
# Setup IAM role for GitHub Actions OIDC authentication
# Run this once to configure GitHub Actions access to AWS

set -e

ACCOUNT_ID="033667696152"
REGION="eu-west-2"
ROLE_NAME="GitHubActionsDeploymentRole"
GITHUB_ORG="yourusername"  # Replace with your GitHub username/org
GITHUB_REPO="simple-log-service"  # Replace with your repo name

echo "=========================================="
echo "GitHub Actions OIDC Role Setup"
echo "=========================================="
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Role: $ROLE_NAME"
echo "GitHub: $GITHUB_ORG/$GITHUB_REPO"
echo "=========================================="

# Create OIDC provider (if not exists)
echo ""
echo "Creating OIDC provider..."

OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" \
  --output text)

if [ -z "$OIDC_PROVIDER_ARN" ]; then
  OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    --query OpenIDConnectProviderArn \
    --output text)
  echo "✓ OIDC provider created: $OIDC_PROVIDER_ARN"
else
  echo "✓ OIDC provider already exists: $OIDC_PROVIDER_ARN"
fi

# Create trust policy
echo ""
echo "Creating trust policy..."

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_ORG/$GITHUB_REPO:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
echo ""
echo "Creating IAM role..."

ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
  ROLE_ARN=$(aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "Role for GitHub Actions to deploy Simple Log Service" \
    --query 'Role.Arn' \
    --output text)
  echo "✓ Role created: $ROLE_ARN"
else
  echo "✓ Role already exists: $ROLE_ARN"
  echo "Updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document file://trust-policy.json
fi

# Create permissions policy
echo ""
echo "Creating permissions policy..."

cat > permissions-policy.json <<EOF
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
        "xray:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/GitHubActionsDeploymentPolicy"

# Check if policy exists
EXISTING_POLICY=$(aws iam get-policy --policy-arn $POLICY_ARN 2>/dev/null || echo "")

if [ -z "$EXISTING_POLICY" ]; then
  POLICY_ARN=$(aws iam create-policy \
    --policy-name GitHubActionsDeploymentPolicy \
    --policy-document file://permissions-policy.json \
    --description "Permissions for GitHub Actions deployment" \
    --query 'Policy.Arn' \
    --output text)
  echo "✓ Policy created: $POLICY_ARN"
else
  echo "✓ Policy already exists: $POLICY_ARN"
  # Create new version
  aws iam create-policy-version \
    --policy-arn $POLICY_ARN \
    --policy-document file://permissions-policy.json \
    --set-as-default
  echo "✓ Policy updated"
fi

# Attach policy to role
echo ""
echo "Attaching policy to role..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN
echo "✓ Policy attached"

# Clean up temporary files
rm -f trust-policy.json permissions-policy.json

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Role ARN: $ROLE_ARN"
echo ""
echo "Add this to your GitHub repository secrets:"
echo "  AWS_ROLE_ARN: $ROLE_ARN"
echo ""
echo "Or update the workflow file with:"
echo "  role-to-assume: $ROLE_ARN"
echo ""
echo "=========================================="

