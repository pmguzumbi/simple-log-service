
"""
Unit tests for the ingest Lambda function.
Tests log ingestion with various scenarios.
"""

import os
import sys

# CRITICAL: Set AWS credentials with valid account ID format BEFORE any imports
# Moto 5.x validates account ID format even for mocked services
os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
os.environ['AWS_SECURITY_TOKEN'] = 'testing'
os.environ['AWS_SESSION_TOKEN'] = 'testing'
os.environ['AWS_DEFAULT_REGION'] = 'us-west-2'
# Set table name environment variable
os.environ['TABLE_NAME'] = 'simple-log-service-logs-test'
os.environ['DYNAMODB_TABLE_NAME'] = 'simple-log-service-logs-test'

# Mock AWS account ID to prevent endpoint resolution errors
os.environ['MOTO_ACCOUNT_ID'] = '123456789012'

import json
import pytest
from moto import mock_aws
import boto3

# Add parent directory to path to import Lambda handler
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from index import lambda_handler


@pytest.fixture
def dynamodb_table():
    """
    Create a mocked DynamoDB table for testing.
    Uses mock_aws context manager to intercept boto3 calls.
    """
    with mock_aws():
        # Create DynamoDB resource with mocked AWS services
        dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
        
        # Create test table matching production schema
        table = dynamodb.create_table(
            TableName='simple-log-service-logs-test',
            KeySchema=[
                {'AttributeName': 'log_id', 'KeyType': 'HASH'},
                {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'log_id', 'AttributeType': 'S'},
                {'AttributeName': 'timestamp', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'
        )
        
        # Wait for table creation to complete
        table.meta.client.get_waiter('table_exists').wait(
            TableName='simple-log-service-logs-test'
        )
        
        yield table


def test_ingest_log_success(dynamodb_table):
    """Test successful log ingestion with all required fields."""
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


def test_ingest_log_missing_required_field(dynamodb_table):
    """Test log ingestion with missing required field."""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'log_type': 'application',
            'level': 'ERROR'
            # Missing 'message' field
        })
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'message' in body['error'].lower()


def test_ingest_log_invalid_json(dynamodb_table):
    """Test log ingestion with invalid JSON in request body."""
    event = {
        'body': 'invalid json string'
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body


def test_ingest_log_with_metadata(dynamodb_table):
    """Test log ingestion with optional metadata fields."""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'log_type': 'application',
            'level': 'WARNING',
            'message': 'Test log with metadata',
            'metadata': {
                'user_id': 'user123',
                'request_id': 'req-456'
            }
        })
    }
    
    response = lambda_handler(event, None)
    
    assert response['statusCode'] == 201
    body = json.loads(response['body'])
    assert 'log_id' in body

