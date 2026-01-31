import json
import boto3
import os
from datetime import datetime, timedelta
from decimal import Decimal
from boto3.dynamodb.conditions import Key

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE_NAME', 'LogsTable')
table = dynamodb.Table(table_name)

# Initialize CloudWatch client for custom metrics
cloudwatch = boto3.client('cloudwatch')

class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert Decimal to float for JSON serialization"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Lambda function to retrieve recent logs (last 24 hours).
    
    Query parameters:
    - service_name: Filter by service (optional)
    - log_type: Filter by log type (optional)
    - limit: Maximum number of results (default: 100)
    
    Args:
        event: API Gateway event containing query parameters
        context: Lambda context object
        
    Returns:
        API Gateway response with logs from last 24 hours
    """
    try:
        # Parse query parameters - handle None case
        params = event.get('queryStringParameters', {}) or {}
        service_name = params.get('service_name')
        log_type = params.get('log_type')
        limit = int(params.get('limit', 100))
        
        # Calculate timestamp for 24 hours ago
        twenty_four_hours_ago = datetime.utcnow() - timedelta(hours=24)
        cutoff_timestamp = Decimal(str(twenty_four_hours_ago.timestamp()))
        
        # Query DynamoDB based on provided parameters
        if service_name:
            # Query by service_name (primary key) - most efficient
            response = table.query(
                KeyConditionExpression=Key('service_name').eq(service_name) & 
                                     Key('timestamp').gte(cutoff_timestamp),
                Limit=limit,
                ScanIndexForward=False  # Sort descending (newest first)
            )
        elif log_type:
            # Query using GSI (TimestampIndex) for log_type
            response = table.query(
                IndexName='TimestampIndex',
                KeyConditionExpression=Key('log_type').eq(log_type) & 
                                     Key('timestamp').gte(cutoff_timestamp),
                Limit=limit,
                ScanIndexForward=False  # Sort descending (newest first)
            )
        else:
            # Scan entire table (less efficient, use with caution in production)
            response = table.scan(
                FilterExpression=Key('timestamp').gte(cutoff_timestamp),
                Limit=limit
            )
        
        # Extract logs from response
        logs = response.get('Items', [])
        
        # Publish custom metric to CloudWatch for monitoring
        cloudwatch.put_metric_data(
            Namespace='SimpleLogService',
            MetricData=[
                {
                    'MetricName': 'LogsRetrieved',
                    'Value': len(logs),
                    'Unit': 'Count'
                }
            ]
        )
        
        # Return response with logs
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'count': len(logs),
                'logs': logs
            }, cls=DecimalEncoder)  # Use custom encoder for Decimal
        }
        
    except ValueError as e:
        # Handle invalid parameter values (e.g., non-numeric limit)
        print(f"Value error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid parameter value'})
        }
    
    except Exception as e:
        # Handle all other errors
        print(f"Error retrieving logs: {str(e)}")
        
        # Publish error metric for monitoring
        try:
            cloudwatch.put_metric_data(
                Namespace='SimpleLogService',
                MetricData=[
                    {
                        'MetricName': 'RetrievalErrors',
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
