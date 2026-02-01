import json
import os
import uuid
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Get table name from environment variable - check both possible names
TABLE_NAME = os.environ.get('TABLE_NAME') or os.environ.get('DYNAMODB_TABLE_NAME')

# Add debug logging
print(f"Lambda initialized with TABLE_NAME: {TABLE_NAME}")

def get_dynamodb_table():
    """Get DynamoDB table resource - allows for easier mocking in tests"""
    if not TABLE_NAME:
        raise ValueError("TABLE_NAME environment variable is not set")
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
    # Debug: Log the incoming event structure
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse request body - handle both API Gateway and direct invocation
        if 'body' in event:
            if isinstance(event['body'], str):
                # API Gateway wraps the payload in 'body' as a JSON string
                print("Parsing API Gateway event body")
                body = json.loads(event['body'])
            else:
                # Body is already a dict (shouldn't happen but handle it)
                print("Body is already a dict")
                body = event['body']
        else:
            # Direct Lambda invocation - payload is directly in event
            print("Using direct event as body")
            body = event
        
        print(f"Parsed body: {json.dumps(body)}")
        
        # Validate required fields
        required_fields = ['service_name', 'log_type', 'level', 'message']
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            error_msg = f'Missing required fields: {", ".join(missing_fields)}'
            print(f"Validation error: {error_msg}")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': error_msg
                })
            }
        
        # Generate log entry
        log_entry = {
            'log_id': str(uuid.uuid4()),
            'timestamp': body.get('timestamp', datetime.utcnow().isoformat() + 'Z'),
            'service_name': body['service_name'],
            'log_type': body['log_type'],
            'level': body['level'].upper(),
            'message': body['message']
        }
        
        # Add optional metadata if provided
        if 'metadata' in body and body['metadata']:
            log_entry['metadata'] = body['metadata']
        
        print(f"Attempting to write to DynamoDB: {json.dumps(log_entry)}")
        
        # Store in DynamoDB
        table = get_dynamodb_table()
        table.put_item(Item=log_entry)
        
        print(f"Successfully ingested log: service={body['service_name']}, level={body['level']}, timestamp={log_entry['timestamp']}")
        
        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': 'Log entry created successfully',
                'log_id': log_entry['log_id']
            })
        }
        
    except json.JSONDecodeError as e:
        error_msg = f"Invalid JSON in request body: {str(e)}"
        print(f"JSON decode error: {error_msg}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': error_msg})
        }
    except ClientError as e:
        error_msg = f"DynamoDB error: {str(e)}"
        print(error_msg)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': 'Failed to store log entry'})
        }
    except Exception as e:
        error_msg = f"Error ingesting log: {str(e)}"
        print(error_msg)
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }
