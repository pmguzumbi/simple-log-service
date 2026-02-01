import json
import os
import uuid
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Get table name - check both possible environment variable names
TABLE_NAME = os.environ.get('TABLE_NAME') or os.environ.get('DYNAMODB_TABLE_NAME')

def get_dynamodb_table():
    """Get DynamoDB table resource"""
    if not TABLE_NAME:
        raise ValueError("TABLE_NAME environment variable is not set")
    dynamodb = boto3.resource('dynamodb')
    return dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Lambda handler for ingesting log entries
    Handles both API Gateway events and direct Lambda invocations
    """
    print(f"Received event type: {type(event)}")
    print(f"Event keys: {event.keys() if isinstance(event, dict) else 'Not a dict'}")
    
    try:
        # Parse request body - handle both API Gateway and direct invocation
        if isinstance(event, dict) and 'body' in event:
            # API Gateway event - body is a JSON string
            if isinstance(event['body'], str):
                print("Parsing API Gateway event - body is string")
                body = json.loads(event['body'])
            else:
                print("API Gateway event - body is already dict")
                body = event['body']
        else:
            # Direct Lambda invocation
            print("Direct Lambda invocation")
            body = event
        
        print(f"Parsed body keys: {body.keys() if isinstance(body, dict) else 'Not a dict'}")
        
        # Validate required fields
        required_fields = ['service_name', 'log_type', 'level', 'message']
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            error_msg = f'Missing required fields: {", ".join(missing_fields)}'
            print(f"Validation failed: {error_msg}")
            print(f"Body content: {json.dumps(body)}")
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': error_msg})
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
        
        if 'metadata' in body and body['metadata']:
            log_entry['metadata'] = body['metadata']
        
        print(f"Writing to DynamoDB table: {TABLE_NAME}")
        print(f"Log entry: {json.dumps(log_entry)}")
        
        # Store in DynamoDB
        table = get_dynamodb_table()
        table.put_item(Item=log_entry)
        
        print(f"SUCCESS: Log ingested - service={body['service_name']}, level={body['level']}")
        
        return {
            'statusCode': 201,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Log entry created successfully',
                'log_id': log_entry['log_id']
            })
        }
        
    except json.JSONDecodeError as e:
        error_msg = f"Invalid JSON: {str(e)}"
        print(f"ERROR: {error_msg}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': error_msg})
        }
    except ClientError as e:
        print(f"ERROR: DynamoDB ClientError: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to store log entry'})
        }
    except Exception as e:
        print(f"ERROR: Unexpected error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

