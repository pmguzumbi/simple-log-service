```python

"""
Simple test runner for Lambda functions without AWS connectivity
Place this file in the project root directory
"""

import sys
import os

# Ensure we're in the project root
project_root = os.path.dirname(os.path.abspath(__file__))
os.chdir(project_root)

# Mock boto3 BEFORE any imports
from unittest.mock import MagicMock, patch

# Create mock boto3
mock_dynamodb = MagicMock()
mock_table = MagicMock()
mock_dynamodb.Table.return_value = mock_table

# Patch boto3 globally
sys.modules['boto3'] = MagicMock()
sys.modules['boto3'].resource = MagicMock(return_value=mock_dynamodb)

# Set environment variables
os.environ['TABLE_NAME'] = 'log-entries'
os.environ['AWS_DEFAULT_REGION'] = 'eu-west-1'

# Now run the actual tests
import unittest
import json
from datetime import datetime, timedelta

# Import Lambda functions AFTER mocking
sys.path.insert(0, os.path.join(project_root, 'lambda', 'ingest'))
sys.path.insert(0, os.path.join(project_root, 'lambda', 'read_recent'))

import lambda.ingest.index as ingest_module
import lambda.read_recent.index as read_module

class TestIngestFunction(unittest.TestCase):
    """Test ingest Lambda function"""
    
    def setUp(self):
        mock_table.reset_mock()
        mock_table.put_item.side_effect = None
    
    def test_valid_log_entry(self):
        event = {'severity': 'info', 'message': 'Test message'}
        response = ingest_module.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 201)
        body = json.loads(response['body'])
        self.assertEqual(body['log_entry']['severity'], 'info')
        mock_table.put_item.assert_called_once()
    
    def test_missing_severity(self):
        event = {'message': 'Test message'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
    
    def test_missing_message(self):
        event = {'severity': 'info'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
    
    def test_invalid_severity(self):
        event = {'severity': 'critical', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
    
    def test_all_severities(self):
        for severity in ['info', 'warning', 'error']:
            mock_table.reset_mock()
            event = {'severity': severity, 'message': f'Test {severity}'}
            response = ingest_module.lambda_handler(event, None)
            self.assertEqual(response['statusCode'], 201, f"Failed for {severity}")
    
    def test_dynamodb_error(self):
        mock_table.put_item.side_effect = Exception('DynamoDB error')
        event = {'severity': 'info', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 500)

class TestReadRecentFunction(unittest.TestCase):
    """Test read recent Lambda function"""
    
    def setUp(self):
        mock_table.reset_mock()
        mock_table.query.side_effect = None
        mock_table.scan.side_effect = None
        
        # Create mock entries
        base_time = datetime.utcnow()
        self.mock_entries = [
            {
                'id': f'test-{i}',
                'datetime': (base_time - timedelta(minutes=i)).isoformat() + 'Z',
                'severity': ['info', 'warning', 'error'][i % 3],
                'message': f'Test message {i}',
                'record_type': 'log'
            }
            for i in range(10)
        ]
    
    def test_successful_query(self):
        mock_table.query.return_value = {'Items': self.mock_entries}
        response = read_module.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 10)
    
    def test_empty_results(self):
        mock_table.query.return_value = {'Items': []}
        response = read_module.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 0)
    
    def test_query_fallback(self):
        from botocore.exceptions import ClientError
        mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException'}}, 'Query'
        )
        mock_table.scan.return_value = {'Items': self.mock_entries}
        
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)
    
    def test_complete_failure(self):
        from botocore.exceptions import ClientError
        mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException'}}, 'Query'
        )
        mock_table.scan.side_effect = Exception('Scan failed')
        
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 500)

if __name__ == '__main__':
    # Run tests
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    suite.addTests(loader.loadTestsFromTestCase(TestIngestFunction))
    suite.addTests(loader.loadTestsFromTestCase(TestReadRecentFunction))
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Exit with appropriate code
    sys.exit(0 if result.wasSuccessful() else 1)

```
