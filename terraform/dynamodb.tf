# DynamoDB table for storing logs
resource "aws_dynamodb_table" "logs" {
  name           = "${var.project_name}-logs-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "log_id"
  
  attribute {
    name = "log_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "service_name"
    type = "S"
  }

  # Global Secondary Index for querying by timestamp
  global_secondary_index {
    name            = "timestamp-index"
    hash_key        = "timestamp"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying by service name
  global_secondary_index {
    name            = "service-name-index"
    hash_key        = "service_name"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Enable server-side encryption with customer-managed KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Enable deletion protection
  deletion_protection_enabled = true

  # Enable TTL for automatic log expiration (optional)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

