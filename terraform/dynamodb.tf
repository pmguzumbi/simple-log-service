# DynamoDB table configuration for log storage

resource "aws_dynamodb_table" "logs" {
  name           = "${local.name_prefix}-logs"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity
  
  # Primary key configuration
  hash_key  = "service_name"  # Partition key
  range_key = "timestamp"      # Sort key
  
  # Primary key attributes
  attribute {
    name = "service_name"
    type = "S"  # String
  }
  
  attribute {
    name = "timestamp"
    type = "N"  # Number
  }
  
  attribute {
    name = "log_type"
    type = "S"  # String
  }
  
  # Global Secondary Index for querying by log_type and timestamp
  global_secondary_index {
    name            = "TimestampIndex"
    hash_key        = "log_type"
    range_key       = "timestamp"
    projection_type = "ALL"  # Project all attributes
    read_capacity   = var.dynamodb_read_capacity
    write_capacity  = var.dynamodb_write_capacity
  }
  
  # Enable encryption at rest with customer-managed KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.logs.arn
  }
  
  # Enable point-in-time recovery for backup
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  # Enable deletion protection
  deletion_protection_enabled = var.enable_deletion_protection
  
  # TTL configuration (disabled by default)
  ttl {
    attribute_name = "ttl"
    enabled        = false
  }
  
  # Stream configuration for change data capture (optional)
  stream_enabled   = false
  stream_view_type = null
  
  tags = {
    Name        = "${local.name_prefix}-logs"
    Description = "Log storage table with GSI for efficient queries"
  }
}

# Auto-scaling configuration for DynamoDB read capacity
resource "aws_appautoscaling_target" "dynamodb_read" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.logs.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_read_policy" {
  name               = "${local.name_prefix}-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_read.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_read.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0  # Scale when utilization reaches 70%
  }
}

# Auto-scaling configuration for DynamoDB write capacity
resource "aws_appautoscaling_target" "dynamodb_write" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.logs.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_write_policy" {
  name               = "${local.name_prefix}-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_write.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_write.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_write.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0  # Scale when utilization reaches 70%
  }
}

# Auto-scaling for GSI read capacity
resource "aws_appautoscaling_target" "dynamodb_gsi_read" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.logs.name}/index/TimestampIndex"
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_gsi_read_policy" {
  name               = "${local.name_prefix}-gsi-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_gsi_read.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_gsi_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_gsi_read.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

# Auto-scaling for GSI write capacity
resource "aws_appautoscaling_target" "dynamodb_gsi_write" {
  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.logs.name}/index/TimestampIndex"
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_gsi_write_policy" {
  name               = "${local.name_prefix}-gsi-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_gsi_write.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_gsi_write.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_gsi_write.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}

