# AWS Config configuration for compliance monitoring

# S3 bucket for AWS Config
resource "aws_s3_bucket" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = "${local.name_prefix}-config-${local.account_id}"
  
  tags = {
    Name = "${local.name_prefix}-config"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for AWS Config
resource "aws_s3_bucket_policy" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
      },
      {
        Sid    = "AWSConfigBucketPutObject"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-config-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${local.name_prefix}-config-role"
  }
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# IAM policy for Config to write to S3
resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-config-s3-policy"
  role  = aws_iam_role.config[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.config[0].arn,
          "${aws_s3_bucket.config[0].arn}/*"
        ]
      }
    ]
  })
}

# AWS Config recorder
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn
  
  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

# AWS Config delivery channel
resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "${local.name_prefix}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config[0].id
  
  snapshot_delivery_properties {
    delivery_frequency = var.config_snapshot_frequency
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Start Config recorder
resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  
  depends_on = [aws_config_delivery_channel.main]
}

# Config rule: DynamoDB encryption
resource "aws_config_config_rule" "dynamodb_encrypted" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-dynamodb-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTED_KMS"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: DynamoDB PITR
resource "aws_config_config_rule" "dynamodb_pitr" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-dynamodb-pitr"
  
  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_PITR_ENABLED"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: Lambda encryption
resource "aws_config_config_rule" "lambda_encrypted" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-lambda-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_FUNCTION_SETTINGS_CHECK"
  }
  
  input_parameters = jsonencode({
    runtime = "python3.11"
  })
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: CloudWatch Logs encryption
resource "aws_config_config_rule" "cloudwatch_encrypted" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-cloudwatch-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: S3 bucket encryption
resource "aws_config_config_rule" "s3_encrypted" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-s3-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rule: S3 bucket versioning
resource "aws_config_config_rule" "s3_versioning" {
  count = var.enable_config ? 1 : 0
  name  = "${local.name_prefix}-s3-versioning"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# SNS topic for Config notifications
resource "aws_sns_topic" "config_notifications" {
  count             = var.enable_config ? 1 : 0
  name              = "${local.name_prefix}-config-notifications"
  display_name      = "AWS Config Compliance Notifications"
  kms_master_key_id = aws_kms_key.logs.id
  
  tags = {
    Name = "${local.name_prefix}-config-notifications"
  }
}

# SNS topic subscription for Config
resource "aws_sns_topic_subscription" "config_email" {
  count     = var.enable_config && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.config_notifications[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# EventBridge rule for Config compliance changes
resource "aws_cloudwatch_event_rule" "config_compliance" {
  count       = var.enable_config ? 1 : 0
  name        = "${local.name_prefix}-config-compliance-change"
  description = "Trigger on Config compliance changes"
  
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = [
        {
          prefix = local.name_prefix
        }
      ]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

# EventBridge target to send to SNS
resource "aws_cloudwatch_event_target" "config_sns" {
  count     = var.enable_config ? 1 : 0
  rule      = aws_cloudwatch_event_rule.config_compliance[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.config_notifications[0].arn
}

# SNS topic policy to allow EventBridge
resource "aws_sns_topic_policy" "config_notifications" {
  count  = var.enable_config ? 1 : 0
  arn    = aws_sns_topic.config_notifications[0].arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.config_notifications[0].arn
      }
    ]
  })
}
