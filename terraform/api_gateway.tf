# API Gateway configuration for log service

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-api"
  description = "API Gateway for Simple Log Service"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = {
    Name = "${local.name_prefix}-api"
  }
}

# /logs resource
resource "aws_api_gateway_resource" "logs" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "logs"
}

# /logs/recent resource
resource "aws_api_gateway_resource" "recent" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.logs.id
  path_part   = "recent"
}

# POST /logs method (ingest)
resource "aws_api_gateway_method" "post_logs" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.logs.id
  http_method   = "POST"
  authorization = "AWS_IAM"  # AWS SigV4 authentication
}

# POST /logs integration
resource "aws_api_gateway_integration" "post_logs" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.logs.id
  http_method             = aws_api_gateway_method.post_logs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ingest_log.invoke_arn
}

# GET /logs/recent method (read)
resource "aws_api_gateway_method" "get_recent" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.recent.id
  http_method   = "GET"
  authorization = "AWS_IAM"  # AWS SigV4 authentication
  
  request_parameters = {
    "method.request.querystring.service_name" = false
    "method.request.querystring.log_type"     = false
    "method.request.querystring.limit"        = false
  }
}

# GET /logs/recent integration
resource "aws_api_gateway_integration" "get_recent" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.recent.id
  http_method             = aws_api_gateway_method.get_recent.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read_recent.invoke_arn
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.logs.id,
      aws_api_gateway_resource.recent.id,
      aws_api_gateway_method.post_logs.id,
      aws_api_gateway_method.get_recent.id,
      aws_api_gateway_integration.post_logs.id,
      aws_api_gateway_integration.get_recent.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_integration.post_logs,
    aws_api_gateway_integration.get_recent
  ]
}

# API Gateway stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
  
  # Enable CloudWatch logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  # Enable X-Ray tracing
  xray_tracing_enabled = true
  
  tags = {
    Name = "${local.name_prefix}-${var.environment}"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name = "${local.name_prefix}-api-gateway-logs"
  }
}

# API Gateway method settings
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"
  
  settings {
    metrics_enabled        = true
    logging_level         = "INFO"
    data_trace_enabled    = true
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}

