# AWS Config S3 bucket for configuration snapshots
resource "aws_s3_bucket" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = "${var.project_name}-config-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-config-bucket-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudwatch.arn
    }
  }
}

# Fixed: Added filter to resolve S3 lifecycle configuration warning
resource "aws_s3_bucket_lifecycle_configuration" "config" {
  count  = var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    id     = "delete-old-snapshots"
    status = "Enabled"

    # Added filter to fix warning
    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-config-role-${var.environment}"

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
    Name        = "${var.project_name}-config-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-config-s3-policy-${var.environment}"
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

# AWS Config Configuration Recorder
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.project_name}-recorder-${var.environment}"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# AWS Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config ? 1 : 0
  name           = "${var.project_name}-delivery-channel-${var.environment}"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  snapshot_delivery_properties {
    delivery_frequency = var.config_snapshot_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Start the Configuration Recorder
resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# AWS Config Rules
resource "aws_config_config_rule" "encrypted_volumes" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-encrypted-volumes-${var.environment}"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-s3-public-read-prohibited-${var.environment}"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-s3-public-write-prohibited-${var.environment}"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "iam_password_policy" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-iam-password-policy-${var.environment}"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "root_account_mfa_enabled" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project_name}-root-mfa-enabled-${var.environment}"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# SNS topic for Config notifications
resource "aws_sns_topic" "config_notifications" {
  count             = var.enable_config ? 1 : 0
  name              = "${var.project_name}-config-notifications-${var.environment}"
  kms_master_key_id = aws_kms_key.cloudwatch.id

  tags = {
    Name        = "${var.project_name}-config-notifications-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sns_topic_subscription" "config_email" {
  count     = var.enable_config && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.config_notifications[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

