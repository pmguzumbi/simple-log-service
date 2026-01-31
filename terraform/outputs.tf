# Outputs for Simple Log Service

# API Gateway outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

# DynamoDB outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.logs.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.logs.arn
}

output "dynamodb_gsi_name" {
  description = "DynamoDB Global Secondary Index name"
  value       = "TimestampIndex"
}

# Lambda outputs
output "ingest_lambda_arn" {
  description = "Ingest Lambda function ARN"
  value       = aws_lambda_function.ingest_log.arn
}

output "ingest_lambda_name" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest_log.function_name
}

output "read_lambda_arn" {
  description = "Read Lambda function ARN"
  value       = aws_lambda_function.read_recent.arn
}

output "read_lambda_name" {
  description = "Read Lambda function name"
  value       = aws_lambda_function.read_recent.function_name
}

# KMS outputs
output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.logs.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.logs.arn
}

# CloudWatch outputs
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "cloudwatch_log_group_ingest" {
  description = "CloudWatch log group for ingest Lambda"
  value       = aws_cloudwatch_log_group.ingest_log.name
}

output "cloudwatch_log_group_read" {
  description = "CloudWatch log group for read Lambda"
  value       = aws_cloudwatch_log_group.read_recent.name
}

# SNS outputs
output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

# AWS Config outputs
output "config_recorder_name" {
  description = "AWS Config recorder name"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}

output "config_bucket_name" {
  description = "S3 bucket for AWS Config snapshots"
  value       = var.enable_config ? aws_s3_bucket.config[0].id : null
}

# IAM outputs
output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution.arn
}

# Deployment information
output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "deployment_environment" {
  description = "Environment name"
  value       = var.environment
}

output "availability_zones" {
  description = "Availability zones used for deployment"
  value       = local.azs
}

