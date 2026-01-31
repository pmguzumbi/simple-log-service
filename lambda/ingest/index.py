
"""
Lambda function for ingesting log entries into DynamoDB
Validates input, generates unique IDs, and stores logs with timestamp
"""

import json
import os
import uuid
from datetime import datetime
import boto3
from decimal import Decimal

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

# Initialize CloudWatch client for custom metrics
cloudwatch = boto3.client('cloudwatch')


def lambda_handler(event, context):
    """
    Main Lambda handler for log ingestion
    
    Args:
        event: API Gateway event containing log data in body
        context: Lambda context object
        
    Returns:
        dict: API Gateway response with status code and body
    """
    try:
        # Parse request body
        if 'body' not in event:
            return create_response(400, {'error': 'Missing request body'})
        
        body = json.loads(event['body'])
        
        # Validate required fields
        required_fields = ['service_name', 'log_type', 'level', 'message']
        for field in required_fields:
            if field not in body:
                return create_response(400, {'error': f'Missing required field: {field}'})
        
        # Generate unique log ID and timestamp
        log_id = str(uuid.uuid4())
        timestamp = int(datetime.utcnow().timestamp())
        
        # Prepare log entry
        log_entry = {
            'service_name': body['service_name'],
            'timestamp': timestamp,
            'log_id': log_id,
            'log_type': body['log_type'],
            'level': body['level'],
            'message': body['message']
        }
        
        # Add optional metadata if provided
        if 'metadata' in body:
            log_entry['metadata'] = body['metadata']
        
        # Write to DynamoDB
        table.put_item(Item=log_entry)
        
        # Publish custom metric to CloudWatch
        publish_metric('LogsIngested', 1, body['service_name'])
        
        # Return success response
        return create_response(201, {
            'message': 'Log entry created successfully',
            'log_id': log_id,
            'timestamp': timestamp
        })
        
    except json.JSONDecodeError:
        return create_response(400, {'error': 'Invalid JSON in request body'})
    
    except Exception as e:
        print(f"Error ingesting log: {str(e)}")
        publish_metric('LogIngestionErrors', 1, 'unknown')
        return create_response(500, {'error': 'Internal server error'})


def create_response(status_code, body):
    """
    Create standardized API Gateway response
    
    Args:
        status_code: HTTP status code
        body: Response body dictionary
        
    Returns:
        dict: Formatted API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }


def publish_metric(metric_name, value, service_name):
    """
    Publish custom metric to CloudWatch
    
    Args:
        metric_name: Name of the metric
        value: Metric value
        service_name: Service name for dimension
    """
    try:
        cloudwatch.put_metric_data(
            Namespace='SimpleLogService',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'ServiceName',
                            'Value': service_name
                        }
                    ]
                }
            ]
        )
    except Exception as e:
        print(f"Error publishing metric: {str(e)}")

