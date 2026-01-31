
"""
Unit tests for read_recent Lambda function
"""

import json
import os
import pytest
from moto import mock_dynamodb
import boto3
from datetime import datetime
import time

# Import the Lambda handler - use sys.path to avoid 'lambda' keyword issue
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from index import lambda_handler


@pytest.fixture
def aws_credentials():
    """Mock AWS credentials for moto"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'eu-west-2'


@pytest.fixture
def dynamodb_table_with_data(aws_credentials):
    """Create mock DynamoDB table with test data"""
    with mock_dynamodb():
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-2')
        
        table = dynamodb.create_table(
            TableName='test-logs-table',
            KeySchema=[
                {'AttributeName': 'service_name', 'KeyType': 'HASH'},
                {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'service_name', 'AttributeType': 'S'},
                {'AttributeName': 'timestamp', 'AttributeType': 'N'},
                {'AttributeName': 'log_type', 'AttributeType': 'S'}
            ],
            GlobalSecondaryIndexes=[
                {
                    'IndexName': 'TimestampIndex',
                    'KeySchema': [
                        {'AttributeName': 'log_type', 'KeyType': 'HASH'},
                        {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}
                    ],
                    'Projection': {'ProjectionType': 'ALL'},
                    'ProvisionedThroughput': {
                        'ReadCapacityUnits': 5,
                        'WriteCapacityUnits': 5
                    }
                }
            ],
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5
            }
        )
        
        # Add test data
        current_time = int(time.time())
        for i in range(10):
            table.put_item(
                Item={
                    'service_name': 'test-service',
                    'timestamp': current_time - i,
                    'log_id': f'test-log-{i}',
                    'log_type': 'application',
                    'level': 'INFO',
                    'message': f'Test log message {i}'
                }
            )
        
        os.environ['DYNAMODB_TABLE_NAME'] = 'test-logs-table'
        yield table


def test_read_recent_logs_success(dynamodb_table_with_data):
    """Test successful retrieval of recent logs"""
    event = {
        'queryStringParameters': None
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert 'logs' in body
    assert 'count' in body
    assert body['count'] > 0


def test_read_recent_logs_with_service_filter(dynamodb_table_with_data):
    """Test retrieval with service name filter"""
    event = {
        'queryStringParameters': {
            'service_name': 'test-service'
        }
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] > 0
    assert all(log['service_name'] == 'test-service' for log in body['logs'])


def test_read_recent_logs_with_limit(dynamodb_table_with_data):
    """Test retrieval with limit parameter"""
    event = {
        'queryStringParameters': {
            'limit': '5'
        }
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] <= 5


def test_read_recent_logs_with_log_type(dynamodb_table_with_data):
    """Test retrieval with log type filter"""
    event = {
        'queryStringParameters': {
            'log_type': 'application'
        }
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert all(log['log_type'] == 'application' for log in body['logs'])


def test_read_recent_logs_no_results(dynamodb_table_with_data):
    """Test retrieval with no matching results"""
    event = {
        'queryStringParameters': {
            'service_name': 'non-existent-service'
        }
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] == 0
    assert body['logs'] == []

