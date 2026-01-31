```terraform

# IAM roles for API Gateway authentication with temporary credentials

# IAM role for log ingestion (write access)
resource "aws_iam_role" "log_ingest_role" {
  name = "${var.project_name}-log-ingest-role-${var.environment}"
  
  # Trust policy - who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # Allow specific AWS accounts or services to assume this role
          AWS = var.allowed_ingest_principals
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id_ingest
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-log-ingest-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "API authentication for log ingestion"
  }
}

# IAM policy for log ingestion role
resource "aws_iam_role_policy" "log_ingest_policy" {
  name = "${var.project_name}-log-ingest-policy-${var.environment}"
  role = aws_iam_role.log_ingest_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = [
          "${aws_api_gateway_rest_api.log_service.execution_arn}/*/POST/logs"
        ]
      }
    ]
  })
}

# IAM role for log reading (read access)
resource "aws_iam_role" "log_read_role" {
  name = "${var.project_name}-log-read-role-${var.environment}"
  
  # Trust policy - who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # Allow specific AWS accounts or services to assume this role
          AWS = var.allowed_read_principals
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id_read
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-log-read-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "API authentication for log reading"
  }
}

# IAM policy for log reading role
resource "aws_iam_role_policy" "log_read_policy" {
  name = "${var.project_name}-log-read-policy-${var.environment}"
  role = aws_iam_role.log_read_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = [
          "${aws_api_gateway_rest_api.log_service.execution_arn}/*/GET/logs/recent"
        ]
      }
    ]
  })
}

# IAM role for full access (both read and write)
resource "aws_iam_role" "log_full_access_role" {
  name = "${var.project_name}-log-full-access-role-${var.environment}"
  
  # Trust policy - who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # Allow specific AWS accounts or services to assume this role
          AWS = var.allowed_full_access_principals
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id_full_access
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-log-full-access-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "API authentication for full log access"
  }
}

# IAM policy for full access role
resource "aws_iam_role_policy" "log_full_access_policy" {
  name = "${var.project_name}-log-full-access-policy-${var.environment}"
  role = aws_iam_role.log_full_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = [
          "${aws_api_gateway_rest_api.log_service.execution_arn}/*/*"
        ]
      }
    ]
  })
}

```
