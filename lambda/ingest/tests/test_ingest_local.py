import unittest
import json
import os
from moto import mock_dynamodb
import boto3
from datetime import datetime


class TestIngestLambdaLocal(unittest.TestCase):
    """Local tests for Ingest Lambda using moto for AWS mocking"""
    
    @mock_dynamodb
    def setUp(self):
        """Set up test fixtures with mocked DynamoDB"""
        # Set environment variables
        os.environ['TABLE_NAME'] = 'log-entries'
        os.environ['AWS_DEFAULT_REGION'] = 'eu-west-1'
        
        # Create mock DynamoDB table
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        self.table = dynamodb.create_table(
            TableName='log-entries',
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
        
    @mock_dynamodb
    def test_valid_log_entry(self):
        """Test ingesting a valid log entry"""
        # Import here to use mocked AWS
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        # Remove cached module
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        event = {
            'severity': 'info',
            'message': 'Test log message'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 201)
        body = json.loads(response['body'])
        self.assertIn('log_entry', body)
        self.assertEqual(body['log_entry']['severity'], 'info')
        self.assertEqual(body['log_entry']['message'], 'Test log message')
        self.assertIn('id', body['log_entry'])
        self.assertIn('datetime', body['log_entry'])
        
    @mock_dynamodb
    def test_missing_severity(self):
        """Test with missing severity field"""
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        event = {
            'message': 'Test log message'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @mock_dynamodb
    def test_missing_message(self):
        """Test with missing message field"""
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        event = {
            'severity': 'info'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @mock_dynamodb
    def test_invalid_severity(self):
        """Test with invalid severity value"""
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        event = {
            'severity': 'critical',
            'message': 'Test log message'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        self.assertIn('Invalid severity', body['error'])
        
    @mock_dynamodb
    def test_all_severity_levels(self):
        """Test all valid severity levels"""
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        severities = ['info', 'warning', 'error']
        
        for severity in severities:
            event = {
                'severity': severity,
                'message': f'Test {severity} message'
            }
            
            response = index.lambda_handler(event, None)
            
            self.assertEqual(response['statusCode'], 201, f"Failed for severity: {severity}")
            body = json.loads(response['body'])
            self.assertEqual(body['log_entry']['severity'], severity)


if __name__ == '__main__':
    unittest.main()

