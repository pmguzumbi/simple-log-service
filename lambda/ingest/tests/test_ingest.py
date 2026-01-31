import json
import pytest
import os
from moto import mock_dynamodb, mock_cloudwatch
import boto3
from decimal import Decimal

# Set environment variables before importing Lambda function
os.environ['DYNAMODB_TABLE_NAME'] = 'LogsTable'
os.environ['AWS_DEFAULT_REGION'] = 'eu-west-2'

from lambda.ingest_log.index import lambda_handler

@pytest.fixture
def aws_credentials():
    """Mock AWS credentials for moto testing"""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'

@pytest.fixture
def dynamodb_table(aws_credentials):
    """Create mock DynamoDB table for testing"""
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
        
        yield table

@mock_cloudwatch
def test_successful_log_ingestion(dynamodb_table):
    """Test successful log ingestion with all required fields"""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'log_type': 'application',
            'level': 'INFO',
            'message': 'Test log message',
            'metadata': {'key': 'value'}
        })
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response
    assert response['statusCode'] == 201
    body = json.loads(response['body'])
    assert 'log_id' in body
    assert body['message'] == 'Log ingested successfully'

@mock_cloudwatch
def test_missing_required_field(dynamodb_table):
    """Test error handling when required field is missing"""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'message': 'Test message'
            # Missing log_type
        })
    }
    
    response = lambda_handler(event, None)
    
    # Verify error response
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body

@mock_cloudwatch
def test_invalid_json(dynamodb_table):
    """Test error handling for invalid JSON input"""
    event = {
        'body': 'invalid json{'
    }
    
    response = lambda_handler(event, None)
    
    # Verify error response
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body

@mock_cloudwatch
def test_default_log_level(dynamodb_table):
    """Test that log level defaults to INFO when not provided"""
    event = {
        'body': json.dumps({
            'service_name': 'test-service',
            'log_type': 'application',
            'message': 'Test message'
            # No level specified
        })
    }
    
    response = lambda_handler(event, None)
    
    # Verify successful response
    assert response['statusCode'] == 201

``
