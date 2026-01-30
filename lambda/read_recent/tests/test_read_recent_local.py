import unittest
import json
import os
from moto import mock_dynamodb
import boto3
from datetime import datetime, timedelta


class TestReadRecentLambdaLocal(unittest.TestCase):
    """Local tests for Read Recent Lambda using moto for AWS mocking"""
    
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
        
        # Add test data
        base_time = datetime.utcnow()
        for i in range(10):
            self.table.put_item(Item={
                'id': f'test-id-{i}',
                'datetime': (base_time - timedelta(minutes=i)).isoformat() + 'Z',
                'severity': ['info', 'warning', 'error'][i % 3],
                'message': f'Test log message {i}',
                'record_type': 'log'
            })
    
    @mock_dynamodb
    def test_successful_query(self):
        """Test successful retrieval of log entries"""
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 10)
        self.assertEqual(len(body['log_entries']), 10)
        
    @mock_dynamodb
    def test_empty_results(self):
        """Test with no log entries"""
        # Create empty table
        dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
        dynamodb.create_table(
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
        
        import sys
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        
        if 'index' in sys.modules:
            del sys.modules['index']
            
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 0)


if __name__ == '__main__':
    unittest.main()
