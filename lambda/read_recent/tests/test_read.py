
import json
import os
import pytest
from moto import mock_aws
import boto3
from datetime import datetime, timedelta

# Set environment variable before importing the handler
os.environ['DYNAMODB_TABLE_NAME'] = 'test-logs-table'

from lambda.read_recent.index import lambda_handler

@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

@pytest.fixture
def dynamodb_table_with_data(aws_credentials):
    """Create a mocked DynamoDB table with test data"""
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
        
        # Add test data
        current_time = datetime.utcnow()
        test_logs = [
            {
                'log_id': 'log-1',
                'timestamp': (current_time - timedelta(minutes=5)).isoformat(),
                'service_name': 'test-service',
                'log_type': 'application',
                'level': 'INFO',
                'message': 'Test log 1'
            },
            {
                'log_id': 'log-2',
                'timestamp': (current_time - timedelta(minutes=10)).isoformat(),
                'service_name': 'test-service',
                'log_type': 'application',
                'level': 'ERROR',
                'message': 'Test log 2'
            },
            {
                'log_id': 'log-3',
                'timestamp': (current_time - timedelta(minutes=15)).isoformat(),
                'service_name': 'other-service',
                'log_type': 'system',
                'level': 'WARNING',
                'message': 'Test log 3'
            }
        ]
        
        for log in test_logs:
            table.put_item(Item=log)
        
        yield table

def test_read_recent_logs_success(dynamodb_table_with_data):
    """Test successful retrieval of recent logs"""
    with mock_aws():
        event = {
            'queryStringParameters': None
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        
        body = json.loads(response['body'])
        assert 'logs' in body
        assert 'count' in body
        assert body['count'] == 3
        assert len(body['logs']) == 3

def test_read_recent_logs_with_service_filter(dynamodb_table_with_data):
    """Test retrieval with service name filter"""
    with mock_aws():
        event = {
            'queryStringParameters': {
                'service_name': 'test-service'
            }
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        
        body = json.loads(response['body'])
        assert body['count'] == 2
        for log in body['logs']:
            assert log['service_name'] == 'test-service'

def test_read_recent_logs_with_limit(dynamodb_table_with_data):
    """Test retrieval with limit parameter"""
    with mock_aws():
        event = {
            'queryStringParameters': {
                'limit': '2'
            }
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        
        body = json.loads(response['body'])
        assert len(body['logs']) <= 2

def test_read_recent_logs_with_log_type(dynamodb_table_with_data):
    """Test retrieval with log type filter"""
    with mock_aws():
        event = {
            'queryStringParameters': {
                'log_type': 'application'
            }
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        
        body = json.loads(response['body'])
        assert body['count'] == 2
        for log in body['logs']:
            assert log['log_type'] == 'application'

def test_read_recent_logs_no_results(dynamodb_table_with_data):
    """Test retrieval with no matching results"""
    with mock_aws():
        event = {
            'queryStringParameters': {
                'service_name': 'non-existent-service'
            }
        }
        
        response = lambda_handler(event, None)
        
        assert response['statusCode'] == 200
        
        body = json.loads(response['body'])
        assert body['count'] == 0
        assert len(body['logs']) == 0

