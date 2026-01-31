
"""
Unit tests for ingest Lambda function
"""

import json
import os
import pytest
from moto import mock_dynamodb
import boto3
from datetime import datetime

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
def dynamodb_table(aws_credentials):
    """Create mock DynamoDB table"""
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
        
        os.environ['DYNAMODB_TABLE_NAME'] = 'test-logs-table'
        yield table


def test_ingest_log_success(dynamodb_table):
    """Test successful log ingestion"""
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
    assert body['message'] == 'Log entry created successfully'
    assert 'log_id' in body


def test_ingest_log_missing_required_field(dynamodb_table):
    """Test ingestion with missing required field"""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'log_type': 'application'
            # Missing 'level' and 'message'
        })
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body


def test_ingest_log_invalid_json(dynamodb_table):
    """Test ingestion with invalid JSON"""
    event = {
        'body': 'invalid json'
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body


def test_ingest_log_with_metadata(dynamodb_table):
    """Test ingestion with optional metadata"""
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
    assert body['message'] == 'Log entry created successfully'

