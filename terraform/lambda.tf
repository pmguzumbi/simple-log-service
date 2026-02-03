# Defines the ingest and read_recent Lambda functions with their configurations

# Package the ingest Lambda function code
data "archive_file" "ingest_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  output_path = "${path.module}/lambda_packages/ingest_lambda.zip"
}

# Ingest Lambda Function
resource "aws_lambda_function" "ingest_log" {
  filename         = data.archive_file.ingest_lambda_zip.output_path
  function_name    = "simple-log-service-ingest-${var.environment}"
  role             = aws_iam_role.ingest_lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.ingest_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "simple-log-service-ingest-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# Package the read_recent Lambda function code
data "archive_file" "read_recent_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/read_recent"
  output_path = "${path.module}/lambda_packages/read_recent_lambda.zip"
}

# Read Recent Lambda Function
resource "aws_lambda_function" "read_recent" {
  filename         = data.archive_file.read_recent_lambda_zip.output_path
  function_name    = "simple-log-service-read-recent-${var.environment}"
  role             = aws_iam_role.read_lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.read_recent_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "simple-log-service-read-recent-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# CloudWatch Log Group for Ingest Lambda
resource "aws_cloudwatch_log_group" "ingest_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingest_log.function_name}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "simple-log-service-ingest-logs-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# CloudWatch Log Group for Read Recent Lambda
resource "aws_cloudwatch_log_group" "read_recent_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.read_recent.function_name}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "simple-log-service-read-recent-logs-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# Lambda permission for API Gateway to invoke ingest function
resource "aws_lambda_permission" "api_gateway_ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_log.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_api.execution_arn}/*/*"
}

# Lambda permission for API Gateway to invoke read_recent function
resource "aws_lambda_permission" "api_gateway_read_recent" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_recent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_api.execution_arn}/*/*"
}

