# Lambda function configuration for log ingestion and retrieval

# Data source for Lambda deployment package (ingest)
data "archive_file" "ingest_log" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest_log"
  output_path = "${path.module}/ingest_log.zip"
  
  excludes = [
    "tests",
    "__pycache__",
    "*.pyc",
    ".pytest_cache"
  ]
}

# Data source for Lambda deployment package (read)
data "archive_file" "read_recent" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/read_recent"
  output_path = "${path.module}/read_recent.zip"
  
  excludes = [
    "tests",
    "__pycache__",
    "*.pyc",
    ".pytest_cache"
  ]
}

# Lambda function for log ingestion
resource "aws_lambda_function" "ingest_log" {
  filename         = data.archive_file.ingest_log.output_path
  function_name    = "${local.name_prefix}-ingest-log"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.ingest_log.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  # Environment variables
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      LOG_LEVEL          = "INFO"
      ENVIRONMENT        = var.environment
    }
  }
  
  # Enable encryption for environment variables
  kms_key_arn = aws_kms_key.logs.arn
  
  # Tracing configuration
  tracing_config {
    mode = "Active"
  }
  
  # Reserved concurrent executions (optional)
  reserved_concurrent_executions = -1  # No limit
  
  tags = {
    Name        = "${local.name_prefix}-ingest-log"
    Description = "Lambda function for log ingestion"
  }
  
  depends_on = [
    aws_cloudwatch_log_group.ingest_log,
    aws_iam_role_policy_attachment.lambda_execution
  ]
}

# Lambda function for reading recent logs
resource "aws_lambda_function" "read_recent" {
  filename         = data.archive_file.read_recent.output_path
  function_name    = "${local.name_prefix}-read-recent"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.read_recent.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  # Environment variables
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      LOG_LEVEL          = "INFO"
      ENVIRONMENT        = var.environment
    }
  }
  
  # Enable encryption for environment variables
  kms_key_arn = aws_kms_key.logs.arn
  
  # Tracing configuration
  tracing_config {
    mode = "Active"
  }
  
  # Reserved concurrent executions (optional)
  reserved_concurrent_executions = -1  # No limit
  
  tags = {
    Name        = "${local.name_prefix}-read-recent"
    Description = "Lambda function for reading recent logs"
  }
  
  depends_on = [
    aws_cloudwatch_log_group.read_recent,
    aws_iam_role_policy_attachment.lambda_execution
  ]
}

# CloudWatch Log Group for ingest Lambda
resource "aws_cloudwatch_log_group" "ingest_log" {
  name              = "/aws/lambda/${local.name_prefix}-ingest-log"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name = "${local.name_prefix}-ingest-log-logs"
  }
}

# CloudWatch Log Group for read Lambda
resource "aws_cloudwatch_log_group" "read_recent" {
  name              = "/aws/lambda/${local.name_prefix}-read-recent"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name = "${local.name_prefix}-read-recent-logs"
  }
}

# Lambda permission for API Gateway (ingest)
resource "aws_lambda_permission" "api_gateway_ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_log.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Lambda permission for API Gateway (read)
resource "aws_lambda_permission" "api_gateway_read" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_recent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

