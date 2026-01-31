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
