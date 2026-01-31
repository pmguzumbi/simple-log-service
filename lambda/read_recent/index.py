
"""
Lambda function for retrieving recent log entries from DynamoDB
Supports filtering by service name, log type, and time range
"""

import json
import os
from datetime import datetime, timedelta
import boto3
from boto3.dynamodb.conditions import Key, Attr

# Initialize DynamoDB resource (but don't get table yet)
dynamodb = boto3.resource('dynamodb')

# Initialize CloudWatch client for custom metrics
cloudwatch = boto3.client('cloudwatch')


def lambda_handler(event, context):
    """
    Main Lambda handler for retrieving recent logs
    
    Args:
        event: API Gateway event with optional query parameters
        context: Lambda context object
        
    Returns:
        dict: API Gateway response with logs and count
    """
    try:
        # Get table name from environment variable (lazy load)
        table_name = os.environ.get('DYNAMODB_TABLE_NAME')
        if not table_name:
            return create_response(500, {'error': 'DYNAMODB_TABLE_NAME not configured'})
        
        table = dynamodb.Table(table_name)
        
        # Parse query parameters
        params = event.get('queryStringParameters') or {}
        service_name = params.get('service_name')
        log_type = params.get('log_type')
        limit = int(params.get('limit', 100))
        
        # Calculate cutoff timestamp (24 hours ago)
        cutoff_time = int((datetime.utcnow() - timedelta(hours=24)).timestamp())
        
        # Query logs based on parameters
        if service_name:
            # Query by service name (partition key)
            logs = query_by_service(table, service_name, cutoff_time, limit)
        elif log_type:
            # Query by log type using GSI
            logs = query_by_log_type(table, log_type, cutoff_time, limit)
        else:
            # Scan all recent logs
            logs = scan_recent_logs(table, cutoff_time, limit)
        
        # Publish custom metric
        publish_metric('LogsRetrieved', len(logs), service_name or 'all')
        
        # Return success response
        return create_response(200, {
            'logs': logs,
            'count': len(logs)
        })
        
    except ValueError as e:
        return create_response(400, {'error': f'Invalid parameter: {str(e)}'})
    
    except Exception as e:
        print(f"Error retrieving logs: {str(e)}")
        publish_metric('LogRetrievalErrors', 1, 'unknown')
        return create_response(500, {'error': 'Internal server error'})


def query_by_service(table, service_name, cutoff_time, limit):
    """
    Query logs by service name (most efficient)
    
    Args:
        table: DynamoDB table resource
        service_name: Service name to filter by
        cutoff_time: Minimum timestamp
        limit: Maximum number of results
        
    Returns:
        list: List of log entries
    """
    response = table.query(
        KeyConditionExpression=Key('service_name').eq(service_name) & 
                              Key('timestamp').gte(cutoff_time),
        Limit=limit,
        ScanIndexForward=False  # Sort by timestamp descending
    )
    return response.get('Items', [])


def query_by_log_type(table, log_type, cutoff_time, limit):
    """
    Query logs by log type using GSI
    
    Args:
        table: DynamoDB table resource
        log_type: Log type to filter by
        cutoff_time: Minimum timestamp
        limit: Maximum number of results
        
    Returns:
        list: List of log entries
    """
    response = table.query(
        IndexName='TimestampIndex',
        KeyConditionExpression=Key('log_type').eq(log_type) & 
                              Key('timestamp').gte(cutoff_time),
        Limit=limit,
        ScanIndexForward=False  # Sort by timestamp descending
    )
    return response.get('Items', [])


def scan_recent_logs(table, cutoff_time, limit):
    """
    Scan all recent logs (least efficient, use sparingly)
    
    Args:
        table: DynamoDB table resource
        cutoff_time: Minimum timestamp
        limit: Maximum number of results
        
    Returns:
        list: List of log entries
    """
    response = table.scan(
        FilterExpression=Key('timestamp').gte(cutoff_time),
        Limit=limit
    )
    
    # Sort by timestamp descending
    logs = response.get('Items', [])
    logs.sort(key=lambda x: x['timestamp'], reverse=True)
    
    return logs


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
        'body': json.dumps(body, default=str)  # Handle Decimal types
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

