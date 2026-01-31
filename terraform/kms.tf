# KMS key for Lambda function encryption
resource "aws_kms_key" "lambda" {
  description             = "${var.project_name} Lambda encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-lambda-key-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${var.project_name}-lambda-${var.environment}"
  target_key_id = aws_kms_key.lambda.key_id
}

# KMS key for DynamoDB encryption
resource "aws_kms_key" "dynamodb" {
  description             = "${var.project_name} DynamoDB encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-dynamodb-key-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project_name}-dynamodb-${var.environment}"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# KMS key for CloudWatch Logs encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "${var.project_name} CloudWatch Logs encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-key-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${var.project_name}-cloudwatch-${var.environment}"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

