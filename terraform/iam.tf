

# iam.tf - IAM roles and policies for Simple Log Service
# This file defines IAM roles with proper trust relationships and API Gateway permissions

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# ============================================================================
# LOG INGEST ROLE (Write-Only Access)
# ============================================================================

resource "aws_iam_role" "log_ingest_role" {
  name        = "simple-log-service-log-ingest-role-${var.environment}"
  description = "Role for ingesting logs into the Simple Log Service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "simple-log-service-ingest-${var.environment}"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "simple-log-service-log-ingest-role-${var.environment}"
    Role        = "LogIngest"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for log ingest role - write access to DynamoDB, Lambda invoke, and API Gateway invoke
resource "aws_iam_role_policy" "log_ingest_policy" {
  name = "simple-log-service-log-ingest-policy-${var.environment}"
  role = aws_iam_role.log_ingest_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.ingest_log.arn
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.log_api.id}/${var.environment}/*/logs"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.dynamodb.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# ============================================================================
# LOG READ ROLE (Read-Only Access)
# ============================================================================

resource "aws_iam_role" "log_read_role" {
  name        = "simple-log-service-log-read-role-${var.environment}"
  description = "Role for reading logs from the Simple Log Service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "simple-log-service-read-${var.environment}"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "simple-log-service-log-read-role-${var.environment}"
    Role        = "LogRead"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for log read role - read access to DynamoDB, Lambda invoke, and API Gateway invoke
resource "aws_iam_role_policy" "log_read_policy" {
  name = "simple-log-service-log-read-policy-${var.environment}"
  role = aws_iam_role.log_read_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.logs.arn,
          "${aws_dynamodb_table.logs.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.read_recent.arn
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.log_api.id}/${var.environment}/*/logs/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.dynamodb.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# ============================================================================
# LOG FULL ACCESS ROLE (Read + Write Access)
# ============================================================================

resource "aws_iam_role" "log_full_access_role" {
  name        = "simple-log-service-log-full-access-role-${var.environment}"
  description = "Role for full access to the Simple Log Service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "simple-log-service-full-${var.environment}"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "simple-log-service-log-full-access-role-${var.environment}"
    Role        = "LogFullAccess"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for full access role - full access to DynamoDB, Lambda invoke, and API Gateway invoke
resource "aws_iam_role_policy" "log_full_access_policy" {
  name = "simple-log-service-log-full-access-policy-${var.environment}"
  role = aws_iam_role.log_full_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.logs.arn,
          "${aws_dynamodb_table.logs.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.ingest_log.arn,
          aws_lambda_function.read_recent.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.log_api.id}/${var.environment}/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.dynamodb.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })
}

# ============================================================================
# LAMBDA EXECUTION ROLES
# ============================================================================

resource "aws_iam_role" "ingest_lambda_role" {
  name        = "simple-log-service-ingest-lambda-role-${var.environment}"
  description = "Execution role for the log ingest Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "simple-log-service-ingest-lambda-role-${var.environment}"
    Role        = "LambdaExecution"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "ingest_lambda_policy" {
  name = "simple-log-service-ingest-lambda-policy-${var.environment}"
  role = aws_iam_role.ingest_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.dynamodb.arn,
          aws_kms_key.lambda.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/simple-log-service-ingest-${var.environment}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "read_lambda_role" {
  name        = "simple-log-service-read-lambda-role-${var.environment}"
  description = "Execution role for the log read Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "simple-log-service-read-lambda-role-${var.environment}"
    Role        = "LambdaExecution"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "read_lambda_policy" {
  name = "simple-log-service-read-lambda-policy-${var.environment}"
  role = aws_iam_role.read_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.logs.arn,
          "${aws_dynamodb_table.logs.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.dynamodb.arn,
          aws_kms_key.lambda.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/simple-log-service-read-recent-${var.environment}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "log_ingest_role_arn" {
  description = "ARN of the log ingest IAM role"
  value       = aws_iam_role.log_ingest_role.arn
}

output "log_read_role_arn" {
  description = "ARN of the log read IAM role"
  value       = aws_iam_role.log_read_role.arn
}

output "log_full_access_role_arn" {
  description = "ARN of the log full access IAM role"
  value       = aws_iam_role.log_full_access_role.arn
}

output "ingest_lambda_role_arn" {
  description = "ARN of the ingest Lambda execution role"
  value       = aws_iam_role.ingest_lambda_role.arn
}

output "read_lambda_role_arn" {
  description = "ARN of the read Lambda execution role"
  value       = aws_iam_role.read_lambda_role.arn
}

