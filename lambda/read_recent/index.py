
import json
import boto3
from botocore.exceptions import ClientError
import os

# Initialize DynamoDB client at module level
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'log-entries')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function to retrieve the 100 most recent log entries
    Returns entries sorted by datetime in descending order (newest first)
    """
    try:
        # Query using GSI datetime-index
        response = table.query(
            IndexName='datetime-index',
            KeyConditionExpression='#pk = :pk',
            ExpressionAttributeNames={
                '#pk': 'record_type'
            },
            ExpressionAttributeValues={
                ':pk': 'log'
            },
            ScanIndexForward=False,  # Sort descending (newest first)
            Limit=100
        )
        
        log_entries = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'count': len(log_entries),
                'log_entries': log_entries
            }, default=str)
        }
        
    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        
        # Fallback to scan if GSI query fails
        try:
            response = table.scan(Limit=100)
            items = response.get('Items', [])
            
            # Sort by datetime descending
            sorted_items = sorted(
                items,
                key=lambda x: x.get('datetime', ''),
                reverse=True
            )[:100]
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'count': len(sorted_items),
                    'log_entries': sorted_items,
                    'note': 'Retrieved using scan fallback'
                }, default=str)
            }
        except Exception as scan_error:
            print(f"Scan fallback error: {str(scan_error)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'Failed to retrieve log entries',
                    'details': str(scan_error)
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

