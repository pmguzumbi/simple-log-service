import json
import pytest
import os
from moto import mock_dynamodb, mock_cloudwatch
import boto3
from decimal import Decimal
from datetime import datetime, timedelta

# Set environment variables before importing Lambda function
os.environ['DYNAMODB_TABLE_NAME'] = 'LogsTable'
os.environ['AWS_DEFAULT_REGION'] = 'eu-west-2'

from lambda.read_recent.index import lambda_handler

@pytest.fixture
def aws_credentials():
    """Mock AWS credentials for moto testing"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'

@pytest.fixture
def dynamodb_table_with_data(aws_credentials):
    """Create mock DynamoDB table with test data"""
    with mock_dynamodb():
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-2')
        
        # Create table with same schema as production
        table = dynamodb.create_table(
            TableName='LogsTable',
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
            BillingMode='PROVISIONED',
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5
            }
        )
        
        # Add recent test data (within 24 hours)
        now = datetime.utcnow()
        table.put_item(Item={
            'log_id': 'test-1',
            'service_name': 'test-service',
            'log_type': 'application',
            'timestamp': Decimal(str(now.timestamp())),
            'level': 'INFO',
            'message': 'Recent log',
            'metadata': {}
        })
        
        # Add old log (should not be retrieved - older than 24 hours)
        old_time = now - timedelta(hours=48)
        table.put_item(Item={
            'log_id': 'test-2',
            'service_name': 'test-service',
            'log_type': 'application',
            'timestamp': Decimal(str(old_time.timestamp())),
            'level': 'INFO',
            'message': 'Old log',
            'metadata': {}
        })
        
        yield table

@mock_cloudwatch
def test_retrieve_logs_by_service(dynamodb_table_with_data):
    """Test retrieving logs by service name"""
    event = {
        'queryStringParameters': {
            'service_name': 'test-service'
        }
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] >= 1
    assert 'logs' in body

@mock_cloudwatch
def test_retrieve_logs_by_type(dynamodb_table_with_data):
    """Test retrieving logs by log type using GSI"""
    event = {
        'queryStringParameters': {
            'log_type': 'application'
        }
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert 'logs' in body

@mock_cloudwatch
def test_retrieve_logs_with_limit(dynamodb_table_with_data):
    """Test retrieving logs with limit parameter"""
    event = {
        'queryStringParameters': {
            'limit': '1'
        }
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response and limit respected
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['count'] <= 1

@mock_cloudwatch
def test_retrieve_logs_no_parameters(dynamodb_table_with_data):
    """Test retrieving logs without any parameters (scan)"""
    event = {
        'queryStringParameters': None
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert 'logs' in body

``
