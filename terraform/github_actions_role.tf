# IAM role for GitHub Actions to deploy infrastructure via OIDC
resource "aws_iam_role" "github_actions_deployment" {
  name        = "GitHubActionsDeploymentRole"
  description = "Role for GitHub Actions to deploy infrastructure via OIDC"

  # Trust policy allowing GitHub Actions OIDC and AWS root account
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:pmguzumbi/simple-log-service:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActionsDeploymentRole"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD"
  }
}

# Attach AdministratorAccess policy to the role
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_deployment.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Output the role ARN for reference
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deployment role"
  value       = aws_iam_role.github_actions_deployment.arn
}

