# Lambda function for ingesting logs
data "archive_file" "ingest_log" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingest"
  output_path = "${path.module}/.terraform/archive_files/ingest_log.zip"
}

resource "aws_lambda_function" "ingest_log" {
  filename         = data.archive_file.ingest_log.output_path
  function_name    = "${var.project_name}-ingest-${var.environment}"
  role            = aws_iam_role.ingest_lambda_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.ingest_log.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.logs.name
      ENVIRONMENT = var.environment
    }
  }

  kms_key_arn = aws_kms_key.lambda.arn

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
  output_path = "${path.module}/.terraform/archive_files/read_recent.zip"
}

resource "aws_lambda_function" "read_recent" {
  filename         = data.archive_file.read_recent.output_path
  function_name    = "${var.project_name}-read-recent-${var.environment}"
  role            = aws_iam_role.read_lambda_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.read_recent.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.logs.name
      ENVIRONMENT = var.environment
    }
  }

  kms_key_arn = aws_kms_key.lambda.arn

  tags = {
    Name        = "${var.project_name}-read-recent-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}
