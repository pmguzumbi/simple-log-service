
import json
import os
import pytest
from moto import mock_aws
import boto3

# Set environment variable before importing the handler
os.environ['DYNAMODB_TABLE_NAME'] = 'test-logs-table'

from lambda.ingest.index import lambda_handler

@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

@pytest.fixture
def dynamodb_table(aws_credentials):
    """Create a mocked DynamoDB table"""
    with mock_aws():
        # Create DynamoDB resource
        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        
        # Create table
        table = dynamodb.create_table(
            TableName='test-logs-table',
            KeySchema=[
                {'AttributeName': 'log_id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'log_id', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'
        )
        
        # Wait for table to be created
        table.meta.client.get_waiter('table_exists').wait(TableName='test-logs-table')
        
        yield table

def test_ingest_log_success(dynamodb_table):
    """Test successful log ingestion"""
    with mock_aws():
        event = {
            'body': json.dumps({
                'service_name': 'test-service',
                'log_type': 'application',
                'level': 'INFO',
                'message': 'Test log message'
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 201
        
        body = json.loads(response['body'])
        assert 'log_id' in body
        assert body['message'] == 'Log entry created successfully'
        
        # Verify item was stored in DynamoDB
        stored_item = dynamodb_table.get_item(Key={'log_id': body['log_id']})
        assert 'Item' in stored_item
        assert stored_item['Item']['service_name'] == 'test-service'
        assert stored_item['Item']['level'] == 'INFO'

def test_ingest_log_missing_required_field(dynamodb_table):
    """Test ingestion with missing required field"""
    with mock_aws():
        event = {
            'body': json.dumps({
                'service_name': 'test-service',
                'log_type': 'application',
                'level': 'INFO'
                # Missing 'message' field
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'error' in body
        assert 'message' in body['error'].lower()

def test_ingest_log_invalid_json(dynamodb_table):
    """Test ingestion with invalid JSON"""
    with mock_aws():
        event = {
            'body': 'invalid json {'
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'error' in body

def test_ingest_log_with_metadata(dynamodb_table):
    """Test ingestion with optional metadata"""
    with mock_aws():
        event = {
            'body': json.dumps({
                'service_name': 'test-service',
                'log_type': 'application',
                'level': 'ERROR',
                'message': 'Test error message',
                'metadata': {
                    'user_id': '12345',
                    'request_id': 'abc-def-ghi'
                }
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 201
        
        body = json.loads(response['body'])
        
        # Verify metadata was stored
        stored_item = dynamodb_table.get_item(Key={'log_id': body['log_id']})
        assert 'metadata' in stored_item['Item']
        assert stored_item['Item']['metadata']['user_id'] == '12345'

