import boto3
import json
import time
from datetime import datetime
from botocore.exceptions import ClientError

# Configure for local DynamoDB
dynamodb = boto3.resource(
    'dynamodb',
    endpoint_url='http://localhost:8000',
    region_name='eu-west-1',
    aws_access_key_id='local',
    aws_secret_access_key='local'
)

TABLE_NAME = 'log-entries'

def create_local_table():
    """Create DynamoDB table locally"""
    try:
        table = dynamodb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[
                {'AttributeName': 'id', 'KeyType': 'HASH'},
                {'AttributeName': 'datetime', 'KeyType': 'RANGE'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'id', 'AttributeType': 'S'},
                {'AttributeName': 'datetime', 'AttributeType': 'S'},
                {'AttributeName': 'record_type', 'AttributeType': 'S'}
            ],
            GlobalSecondaryIndexes=[
                {
                    'IndexName': 'datetime-index',
                    'KeySchema': [
                        {'AttributeName': 'record_type', 'KeyType': 'HASH'},
                        {'AttributeName': 'datetime', 'KeyType': 'RANGE'}
                    ],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {
                        'ReadCapacityUnits': 5,
                        'WriteCapacityUnits': 5
                    }
                }
            ],
            BillingMode='PROVISIONED',
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5
            }
        )
        
        # Wait for table to be created
        table.meta.client.get_waiter('table_exists').wait(TableName=TABLE_NAME)
        print(f"✓ Table '{TABLE_NAME}' created successfully")
        return table
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceInUseException':
            print(f"✓ Table '{TABLE_NAME}' already exists")
            return dynamodb.Table(TABLE_NAME)
        else:
            raise

def test_ingest_function():
    """Test the ingest Lambda function locally"""
    print("
=== Testing Ingest Function ===")
    
    # Import the Lambda function
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../lambda/ingest'))
    
    # Set environment variable
    os.environ['TABLE_NAME'] = TABLE_NAME
    
    from index import lambda_handler
    
    test_cases = [
        {'severity': 'info', 'message': 'Test info message'},
        {'severity': 'warning', 'message': 'Test warning message'},
        {'severity': 'error', 'message': 'Test error message'},
    ]
    
    results = []
    for i, test_case in enumerate(test_cases, 1):
        print(f"
Test {i}: {test_case['severity']} - {test_case['message']}")
        response = lambda_handler(test_case, None)
        
        if response['statusCode'] == 201:
            body = json.loads(response['body'])
            print(f"  ✓ Success: Entry ID {body['log_entry']['id']}")
            results.append(body['log_entry'])
        else:
            print(f"  ✗ Failed: {response}")
    
    return results

def test_read_recent_function():
    """Test the read recent Lambda function locally"""
    print("
=== Testing Read Recent Function ===")
    
    # Import the Lambda function
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../lambda/read_recent'))
    
    # Set environment variable
    os.environ['TABLE_NAME'] = TABLE_NAME
    
    from index import lambda_handler
    
    response = lambda_handler({}, None)
    
    if response['statusCode'] == 200:
        body = json.loads(response['body'])
        print(f"
✓ Retrieved {body['count']} log entries")
        
        print("
Recent entries:")
        for entry in body['log_entries'][:5]:
            print(f"  - [{entry['severity'].upper()}] {entry['datetime']}: {entry['message']}")
        
        return body['log_entries']
    else:
        print(f"✗ Failed: {response}")
        return []

def test_error_cases():
    """Test error handling"""
    print("
=== Testing Error Cases ===")
    
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../lambda/ingest'))
    os.environ['TABLE_NAME'] = TABLE_NAME
    
    from index import lambda_handler
    
    error_cases = [
        ({'message': 'Missing severity'}, 'Missing severity field'),
        ({'severity': 'info'}, 'Missing message field'),
        ({'severity': 'critical', 'message': 'Invalid severity'}, 'Invalid severity level'),
    ]
    
    for test_case, description in error_cases:
        print(f"
Test: {description}")
        response = lambda_handler(test_case, None)
        
        if response['statusCode'] == 400:
            print(f"  ✓ Correctly rejected with status 400")
        else:
            print(f"  ✗ Unexpected response: {response}")

def cleanup_table():
    """Delete the local table"""
    try:
        table = dynamodb.Table(TABLE_NAME)
        table.delete()
        print(f"
✓ Table '{TABLE_NAME}' deleted")
    except ClientError as e:
        print(f"
✗ Error deleting table: {e}")

def main():
    """Run all local integration tests"""
    print("=" * 60)
    print("Simple Log Service - Local Integration Tests")
    print("=" * 60)
    
    try:
        # Create table
        create_local_table()
        
        # Wait a moment for table to be ready
        time.sleep(2)
        
        # Run tests
        test_ingest_function()
        test_read_recent_function()
        test_error_cases()
        
        print("
" + "=" * 60)
        print("All tests completed!")
        print("=" * 60)
        
        # Ask if user wants to cleanup
        cleanup = input("
Delete local table? (y/n): ")
        if cleanup.lower() == 'y':
            cleanup_table()
        
    except Exception as e:
        print(f"
✗ Test failed with error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

