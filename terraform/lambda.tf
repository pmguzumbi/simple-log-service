```hcl

# Lambda function for ingesting logs
data "archive_file" "ingest_log" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  output_path = "${path.module}/ingest_lambda.zip"
}

resource "aws_lambda_function" "ingest_log" {
  filename         = data.archive_file.ingest_log.output_path
  function_name    = "${var.project_name}-ingest-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.ingest_log.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
    }
  }

  kms_key_arn = aws_kms_key.lambda.arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.project_name}-ingest-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda function for reading recent logs
data "archive_file" "read_recent" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/read_recent"
  output_path = "${path.module}/read_recent_lambda.zip"
}

resource "aws_lambda_function" "read_recent" {
  filename         = data.archive_file.read_recent.output_path
  function_name    = "${var.project_name}-read-recent-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.read_recent.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
    }
  }

  kms_key_arn = aws_kms_key.lambda.arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.project_name}-read-recent-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "ingest_log" {
  name              = "/aws/lambda/${aws_lambda_function.ingest_log.function_name}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "${var.project_name}-ingest-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "read_recent" {
  name              = "/aws/lambda/${aws_lambda_function.read_recent.function_name}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn

  tags = {
    Name        = "${var.project_name}-read-recent-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "ingest_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_log.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_service.execution_arn}/*/*"
}

resource "aws_lambda_permission" "read_recent_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_recent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.log_service.execution_arn}/*/*"
}

```
