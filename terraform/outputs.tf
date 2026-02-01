
# outputs.tf - Terraform outputs for Simple Log Service
# This file defines output values that are NOT already defined in other files

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
