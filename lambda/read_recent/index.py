import json
import os
from datetime import datetime, timedelta
import boto3
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError

# Get table name from environment variable
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

def get_dynamodb_table():
    """Get DynamoDB table resource - allows for easier mocking in tests"""
    dynamodb = boto3.resource('dynamodb')
    return dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Lambda handler for retrieving recent log entries
    
    Query parameters:
    - limit: Maximum number of logs to return (default: 100, max: 1000)
    - service_name: Filter by service name (optional)
    - log_type: Filter by log type (optional)
    - level: Filter by log level (optional)
    - hours: Number of hours to look back (default: 24)
    """
    try:
        # Parse query parameters
        params = event.get('queryStringParameters') or {}
        
        # Get limit parameter (default 100, max 1000)
        try:
            limit = int(params.get('limit', 100))
            limit = min(max(1, limit), 1000)  # Clamp between 1 and 1000
        except (ValueError, TypeError):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid limit parameter'})
            }
        
        # Get time range parameter (default 24 hours)
        try:
            hours = int(params.get('hours', 24))
            hours = min(max(1, hours), 168)  # Clamp between 1 hour and 7 days
        except (ValueError, TypeError):
            hours = 24
        
        # Calculate cutoff timestamp
        cutoff_time = (datetime.utcnow() - timedelta(hours=hours)).isoformat()
        
        # Scan table with filters
        table = get_dynamodb_table()
        scan_kwargs = {
            'Limit': limit,
            'FilterExpression': Attr('timestamp').gte(cutoff_time)
        }
        
        # Add optional filters
        if 'service_name' in params:
            scan_kwargs['FilterExpression'] &= Attr('service_name').eq(params['service_name'])
        
        if 'log_type' in params:
            scan_kwargs['FilterExpression'] &= Attr('log_type').eq(params['log_type'])
        
        if 'level' in params:
            scan_kwargs['FilterExpression'] &= Attr('level').eq(params['level'].upper())
        
        # Execute scan
        response = table.scan(**scan_kwargs)
        items = response.get('Items', [])
        
        # Sort by timestamp descending (newest first)
        items.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        # Limit results
        items = items[:limit]
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'count': len(items),
                'logs': items
            }, default=str)  # default=str handles datetime serialization
        }
        
    except ClientError as e:
        print(f"Error retrieving logs: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to retrieve log entries'})
        }
    except Exception as e:
        print(f"Error retrieving logs: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

