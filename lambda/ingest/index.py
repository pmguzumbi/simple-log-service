
import json
import uuid
import boto3
from datetime import datetime
from botocore.exceptions import ClientError
import os

# Initialize DynamoDB client at module level
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'log-entries')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function to ingest log entries into DynamoDB
    
    Expected input format:
    {
        "severity": "info|warning|error",
        "message": "Log message text"
    }
    """
    try:
        # Parse input
        if isinstance(event, str):
            body = json.loads(event)
        elif 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Validate required fields
        if 'severity' not in body or 'message' not in body:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required fields: severity and message'
                })
            }
        
        severity = body['severity'].lower()
        message = body['message']
        
        # Validate severity
        valid_severities = ['info', 'warning', 'error']
        if severity not in valid_severities:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': f'Invalid severity. Must be one of: {", ".join(valid_severities)}'
                })
            }
        
        # Generate log entry
        log_entry = {
            'id': str(uuid.uuid4()),
            'datetime': datetime.utcnow().isoformat() + 'Z',
            'severity': severity,
            'message': message,
            'record_type': 'log'
        }
        
        # Store in DynamoDB
        table.put_item(Item=log_entry)
        
        return {
            'statusCode': 201,
            'body': json.dumps({
                'message': 'Log entry created successfully',
                'log_entry': log_entry
            })
        }
        
    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to store log entry',
                'details': str(e)
            })
        }
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'details': str(e)
            })
        }

