import json
import boto3
import os
import uuid
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE_NAME', 'LogsTable')
table = dynamodb.Table(table_name)

# Initialize CloudWatch client for custom metrics
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    """
    Lambda function to ingest log entries into DynamoDB.
    
    Expected input format:
    {
        "service_name": "api-service",
        "log_type": "application",
        "level": "INFO",
        "message": "Log message",
        "metadata": {}
    }
    
    Args:
        event: API Gateway event containing log data
        context: Lambda context object
        
    Returns:
        API Gateway response with status code and body
    """
    try:
        # Parse request body - handle both string and dict formats
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', event)
        
        # Validate required fields
        required_fields = ['service_name', 'log_type', 'message']
        for field in required_fields:
            if field not in body:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'error': f'Missing required field: {field}'
                    })
                }
        
        # Generate log entry with unique ID and timestamp
        log_entry = {
            'log_id': str(uuid.uuid4()),
            'service_name': body['service_name'],
            'log_type': body['log_type'],
            'timestamp': Decimal(str(datetime.utcnow().timestamp())),
            'level': body.get('level', 'INFO'),  # Default to INFO if not provided
            'message': body['message'],
            'metadata': body.get('metadata', {})  # Optional metadata
        }
        
        # Write to DynamoDB
        table.put_item(Item=log_entry)
        
        # Publish custom metric to CloudWatch for monitoring
        cloudwatch.put_metric_data(
            Namespace='SimpleLogService',
            MetricData=[
                {
                    'MetricName': 'LogsIngested',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'ServiceName', 'Value': body['service_name']},
                        {'Name': 'LogType', 'Value': body['log_type']},
                        {'Name': 'Level', 'Value': log_entry['level']}
                    ]
                }
            ]
        )
        
        # Return success response
        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Log ingested successfully',
                'log_id': log_entry['log_id']
            })
        }
        
    except json.JSONDecodeError as e:
        # Handle JSON parsing errors
        print(f"JSON decode error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON format'})
        }
    
    except Exception as e:
        # Handle all other errors
        print(f"Error ingesting log: {str(e)}")
        
        # Publish error metric for monitoring
        try:
            cloudwatch.put_metric_data(
                Namespace='SimpleLogService',
                MetricData=[
                    {
                        'MetricName': 'IngestionErrors',
                        'Value': 1,
                        'Unit': 'Count'
                    }
                ]
            )
        except:
            pass  # Don't fail if metric publishing fails
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'details': str(e)
            })
        }

``
