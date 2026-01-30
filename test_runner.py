```python

import sys
import os
from unittest.mock import MagicMock
import unittest
import json
from datetime import datetime, timedelta
import importlib.util

# Setup
project_root = os.path.dirname(os.path.abspath(__file__))
os.chdir(project_root)

# Mock boto3 before imports
mock_dynamodb = MagicMock()
mock_table = MagicMock()
mock_dynamodb.Table.return_value = mock_table
sys.modules['boto3'] = MagicMock()
sys.modules['boto3'].resource = MagicMock(return_value=mock_dynamodb)

# Environment
os.environ['TABLE_NAME'] = 'log-entries'
os.environ['AWS_DEFAULT_REGION'] = 'eu-west-1'

# Import Lambda functions using importlib to avoid 'lambda' keyword issue
def load_module(module_name, file_path):
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module

ingest_path = os.path.join(project_root, 'lambda', 'ingest', 'index.py')
read_path = os.path.join(project_root, 'lambda', 'read_recent', 'index.py')

ingest_module = load_module('ingest_index', ingest_path)
read_module = load_module('read_index', read_path)

class TestIngest(unittest.TestCase):
    def setUp(self):
        mock_table.reset_mock()
        mock_table.put_item.side_effect = None
    
    def test_valid(self):
        event = {'severity': 'info', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 201)
        print("✓ Valid log entry test passed")
    
    def test_missing_severity(self):
        event = {'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
        print("✓ Missing severity test passed")
    
    def test_missing_message(self):
        event = {'severity': 'info'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
        print("✓ Missing message test passed")
    
    def test_invalid_severity(self):
        event = {'severity': 'critical', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 400)
        print("✓ Invalid severity test passed")
    
    def test_all_severities(self):
        for severity in ['info', 'warning', 'error']:
            mock_table.reset_mock()
            event = {'severity': severity, 'message': 'Test ' + severity}
            response = ingest_module.lambda_handler(event, None)
            self.assertEqual(response['statusCode'], 201)
        print("✓ All severities test passed")
    
    def test_error(self):
        mock_table.put_item.side_effect = Exception('Error')
        event = {'severity': 'info', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 500)
        print("✓ DynamoDB error test passed")

class TestRead(unittest.TestCase):
    def setUp(self):
        mock_table.reset_mock()
        mock_table.query.side_effect = None
        mock_table.scan.side_effect = None
        base_time = datetime.utcnow()
        self.entries = []
        for i in range(10):
            entry = {
                'id': str(i),
                'datetime': (base_time - timedelta(minutes=i)).isoformat() + 'Z',
                'severity': 'info',
                'message': 'Test',
                'record_type': 'log'
            }
            self.entries.append(entry)
    
    def test_query(self):
        mock_table.query.return_value = {'Items': self.entries}
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 10)
        print("✓ Query test passed")
    
    def test_empty(self):
        mock_table.query.return_value = {'Items': []}
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 0)
        print("✓ Empty results test passed")
    
    def test_fallback(self):
        from botocore.exceptions import ClientError
        mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException'}}, 'Query'
        )
        mock_table.scan.return_value = {'Items': self.entries}
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)
        print("✓ Fallback to scan test passed")
    
    def test_complete_failure(self):
        from botocore.exceptions import ClientError
        mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException'}}, 'Query'
        )
        mock_table.scan.side_effect = Exception('Scan failed')
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 500)
        print("✓ Complete failure test passed")

if __name__ == '__main__':
    print("=" * 60)
    print("Simple Log Service - Unit Tests")
    print("=" * 60)
    print()
    unittest.main(verbosity=2)

```
