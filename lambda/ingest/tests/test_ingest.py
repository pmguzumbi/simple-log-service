"""
Unit tests for the ingest Lambda function.
Tests log ingestion with various scenarios including success cases,
validation errors, and metadata handling.
"""

import os
import sys

# CRITICAL: Set fake AWS credentials BEFORE any boto3/moto imports
# This prevents EndpointResolutionError in GitHub Actions
os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
os.environ['AWS_SECURITY_TOKEN'] = 'testing'
os.environ['AWS_SESSION_TOKEN'] = 'testing'
os.environ['AWS_DEFAULT_REGION'] = 'us-west-2'

# Now safe to import boto3 and moto
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
    This fixture runs before each test and provides a clean table.
    Uses mock_aws context manager to intercept boto3 calls.
    """
    with mock_aws():
        # Create DynamoDB resource with mocked AWS services
        dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
        
        # Create test table matching production schema
        table = dynamodb.create_table(
            TableName='simple-log-service-logs-prod',
            KeySchema=[
                {'AttributeName': 'log_id', 'KeyType': 'HASH'},      # Partition key
                {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}   # Sort key
            ],
            AttributeDefinitions=[
                {'AttributeName': 'log_id', 'AttributeType': 'S'},
                {'AttributeName': 'timestamp', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'  # On-demand billing for test
        )
        
        # Wait for table creation to complete
        table.meta.client.get_waiter('table_exists').wait(
            TableName='simple-log-service-logs-prod'
        )
        
        # Set environment variable for Lambda handler
        os.environ['DYNAMODB_TABLE'] = 'simple-log-service-logs-prod'
        
        yield table


def test_ingest_log_success(dynamodb_table):
    """
    Test successful log ingestion with all required fields.
    Verifies that log entry is stored correctly in DynamoDB with proper attributes.
    """
    # Prepare test event with valid log data
    event = {
        'body': json.dumps({
            'message': 'Test log message',
            'level': 'INFO',
            'service': 'test-service'
        })
    }
    
    # Invoke Lambda handler
    response = lambda_handler(event, None)
    
    # Verify HTTP response
    assert response['statusCode'] == 200, f"Expected 200, got {response['statusCode']}"
    
    # Parse response body
    body = json.loads(response['body'])
    assert 'log_id' in body, "Response missing log_id"
    assert 'timestamp' in body, "Response missing timestamp"
    assert body['message'] == 'Log ingested successfully'
    
    # Verify log was stored in DynamoDB
    log_id = body['log_id']
    timestamp = body['timestamp']
    item = dynamodb_table.get_item(Key={'log_id': log_id, 'timestamp': timestamp})
    
    assert 'Item' in item, "Log not found in DynamoDB"
    assert item['Item']['message'] == 'Test log message'
    assert item['Item']['level'] == 'INFO'
    assert item['Item']['service'] == 'test-service'


def test_ingest_log_missing_required_field(dynamodb_table):
    """
    Test log ingestion with missing required field (message).
    Should return 400 Bad Request error with descriptive message.
    """
    # Prepare event with missing 'message' field
    event = {
        'body': json.dumps({
            'level': 'ERROR',
            'service': 'test-service'
        })
    }
    
    # Invoke Lambda handler
    response = lambda_handler(event, None)
    
    # Verify error response
    assert response['statusCode'] == 400, f"Expected 400, got {response['statusCode']}"
    
    # Parse error body
    body = json.loads(response['body'])
    assert 'error' in body, "Response missing error field"
    assert 'message' in body['error'].lower(), "Error message should mention missing 'message' field"


def test_ingest_log_invalid_json(dynamodb_table):
    """
    Test log ingestion with invalid JSON in request body.
    Should return 400 Bad Request error for malformed JSON.
    """
    # Prepare event with malformed JSON
    event = {
        'body': 'invalid json string {not valid}'
    }
    
    # Invoke Lambda handler
    response = lambda_handler(event, None)
    
    # Verify error response
    assert response['statusCode'] == 400, f"Expected 400, got {response['statusCode']}"
    
    # Parse error body
    body = json.loads(response['body'])
    assert 'error' in body, "Response missing error field"


def test_ingest_log_with_metadata(dynamodb_table):
    """
    Test log ingestion with optional metadata fields.
    Verifies that additional fields are stored correctly alongside required fields.
    """
    # Prepare event with metadata
    event = {
        'body': json.dumps({
            'message': 'Test log with metadata',
            'level': 'WARNING',
            'service': 'test-service',
            'user_id': 'user123',
            'request_id': 'req-456',
            'environment': 'production'
        })
    }
    
    # Invoke Lambda handler
    response = lambda_handler(event, None)
    
    # Verify response
    assert response['statusCode'] == 200, f"Expected 200, got {response['statusCode']}"
    body = json.loads(response['body'])
    
    # Verify metadata was stored in DynamoDB
    log_id = body['log_id']
    timestamp = body['timestamp']
    item = dynamodb_table.get_item(Key={'log_id': log_id, 'timestamp': timestamp})
    
    assert 'Item' in item, "Log not found in DynamoDB"
    assert item['Item']['user_id'] == 'user123'
    assert item['Item']['request_id'] == 'req-456'
    assert item['Item']['environment'] == 'production'

