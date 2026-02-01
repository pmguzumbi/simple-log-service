import json
import os
import uuid
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Get table name from environment variable
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

def get_dynamodb_table():
    """Get DynamoDB table resource - allows for easier mocking in tests"""
    dynamodb = boto3.resource('dynamodb')
    return dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Lambda handler for ingesting log entries
    Handles both API Gateway events and direct Lambda invocations
    
    Expected body format:
    {
        "service_name": "string",
        "log_type": "string",
        "level": "string",
        "message": "string",
        "metadata": {} (optional)
    }
    """
    try:
        # Parse request body - handle both API Gateway and direct invocation
        if 'body' in event and isinstance(event.get('body'), str):
            # API Gateway wraps the payload in 'body' as a JSON string
            body = json.loads(event['body'])
        else:
            # Direct Lambda invocation - payload is directly in event
            body = event
        
        # Validate required fields
        required_fields = ['service_name', 'log_type', 'level', 'message']
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': f'Missing required fields: {", ".join(missing_fields)}'
                })
            }
        
        # Generate log entry
        log_entry = {
            'log_id': str(uuid.uuid4()),  # Unique identifier
            'timestamp': datetime.utcnow().isoformat(),  # ISO 8601 format
            'service_name': body['service_name'],
            'log_type': body['log_type'],
            'level': body['level'].upper(),  # Normalize to uppercase
            'message': body['message']
        }
        
        # Add optional metadata if provided
        if 'metadata' in body and body['metadata']:
            log_entry['metadata'] = body['metadata']
        
        # Store in DynamoDB
        table = get_dynamodb_table()
        table.put_item(Item=log_entry)
        
        return {
            'statusCode': 201,
            'body': json.dumps({
                'message': 'Log entry created successfully',
                'log_id': log_entry['log_id']
            })
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except ClientError as e:
        print(f"Error ingesting log: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to store log entry'})
        }
    except Exception as e:
        print(f"Error ingesting log: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
