
# outputs.tf - Terraform outputs for Simple Log Service
# This file defines all output values for the infrastructure

# DynamoDB outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name for log storage"
  value       = aws_dynamodb_table.logs.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.logs.arn
}

# Lambda function outputs
output "ingest_lambda_function_name" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest_log.function_name
}

output "ingest_lambda_function_arn" {
  description = "Ingest Lambda function ARN"
  value       = aws_lambda_function.ingest_log.arn
}

output "read_recent_lambda_function_name" {
  description = "Read recent Lambda function name"
  value       = aws_lambda_function.read_recent.function_name
}

output "read_recent_lambda_function_arn" {
  description = "Read recent Lambda function ARN"
  value       = aws_lambda_function.read_recent.arn
}

# KMS key outputs
output "kms_lambda_key_id" {
  description = "KMS key ID for Lambda encryption"
  value       = aws_kms_key.lambda.id
}

output "kms_lambda_key_arn" {
  description = "KMS key ARN for Lambda encryption"
  value       = aws_kms_key.lambda.arn
}

output "kms_dynamodb_key_id" {
  description = "KMS key ID for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.id
}

output "kms_dynamodb_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.arn
}

output "kms_cloudwatch_key_id" {
  description = "KMS key ID for CloudWatch encryption"
  value       = aws_kms_key.cloudwatch.id
}

output "kms_cloudwatch_key_arn" {
  description = "KMS key ARN for CloudWatch encryption"
  value       = aws_kms_key.cloudwatch.arn
}

# API Gateway outputs (removed duplicate - already in api_gateway.tf)
output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for IAM policies"
  value       = aws_api_gateway_rest_api.log_service.execution_arn
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.log_service.id
}

# IAM role outputs
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

# CloudWatch outputs
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.alarms.arn
}

# Region and account information
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}


