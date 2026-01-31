# CloudWatch monitoring configuration

# SNS topic for alarms
resource "aws_sns_topic" "alarms" {
  name              = "${local.name_prefix}-alarms"
  display_name      = "Simple Log Service Alarms"
  kms_master_key_id = aws_kms_key.logs.id
  
  tags = {
    Name = "${local.name_prefix}-alarms"
  }
}

# SNS topic subscription (email)
resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch alarm for Lambda errors (ingest)
resource "aws_cloudwatch_metric_alarm" "ingest_errors" {
  alarm_name          = "${local.name_prefix}-ingest-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ingest Lambda errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    FunctionName = aws_lambda_function.ingest_log.function_name
  }
  
  tags = {
    Name = "${local.name_prefix}-ingest-errors"
  }
}

# CloudWatch alarm for Lambda errors (read)
resource "aws_cloudwatch_metric_alarm" "read_errors" {
  alarm_name          = "${local.name_prefix}-read-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors read Lambda errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    FunctionName = aws_lambda_function.read_recent.function_name
  }
  
  tags = {
    Name = "${local.name_prefix}-read-errors"
  }
}

# CloudWatch alarm for Lambda duration (ingest)
resource "aws_cloudwatch_metric_alarm" "ingest_duration" {
  alarm_name          = "${local.name_prefix}-ingest-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "This metric monitors ingest Lambda duration"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    FunctionName = aws_lambda_function.ingest_log.function_name
  }
  
  tags = {
    Name = "${local.name_prefix}-ingest-duration"
  }
}

# CloudWatch alarm for DynamoDB throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${local.name_prefix}-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors DynamoDB throttling"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    TableName = aws_dynamodb_table.logs.name
  }
  
  tags = {
    Name = "${local.name_prefix}-dynamodb-throttles"
  }
}

# CloudWatch alarm for API Gateway 4xx errors
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${local.name_prefix}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors API Gateway 4xx errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
  }
  
  tags = {
    Name = "${local.name_prefix}-api-4xx-errors"
  }
}

# CloudWatch alarm for API Gateway 5xx errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors API Gateway 5xx errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
  }
  
  tags = {
    Name = "${local.name_prefix}-api-5xx-errors"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Ingest Invocations" }, { FunctionName = aws_lambda_function.ingest_log.function_name }],
            [".", ".", { stat = "Sum", label = "Read Invocations" }, { FunctionName = aws_lambda_function.read_recent.function_name }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Invocations"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum", label = "Ingest Errors" }, { FunctionName = aws_lambda_function.ingest_log.function_name }],
            [".", ".", { stat = "Sum", label = "Read Errors" }, { FunctionName = aws_lambda_function.read_recent.function_name }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Errors"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Ingest Duration" }, { FunctionName = aws_lambda_function.ingest_log.function_name }],
            [".", ".", { stat = "Average", label = "Read Duration" }, { FunctionName = aws_lambda_function.read_recent.function_name }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Duration (ms)"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }, { TableName = aws_dynamodb_table.logs.name }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }, { TableName = aws_dynamodb_table.logs.name }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "DynamoDB Capacity"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum" }, { ApiName = aws_api_gateway_rest_api.main.name }],
            [".", "4XXError", { stat = "Sum" }, { ApiName = aws_api_gateway_rest_api.main.name }],
            [".", "5XXError", { stat = "Sum" }, { ApiName = aws_api_gateway_rest_api.main.name }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["SimpleLogService", "LogsIngested", { stat = "Sum" }],
            [".", "LogsRetrieved", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Custom Business Metrics"
        }
      }
    ]
  })
}

