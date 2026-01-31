output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.log_service.invoke_url}/logs"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.logs.name
}

output "ingest_lambda_function_name" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest_log.function_name
}

output "read_recent_lambda_function_name" {
  description = "Read recent Lambda function name"
  value       = aws_lambda_function.read_recent.function_name
}

output "kms_lambda_key_id" {
  description = "KMS key ID for Lambda encryption"
  value       = aws_kms_key.lambda.id
}

output "kms_dynamodb_key_id" {
  description = "KMS key ID for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.id
}

