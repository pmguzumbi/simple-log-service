import sys
import os
from unittest.mock import MagicMock
import unittest
import json
from datetime import datetime, timedelta

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

# Import Lambda functions
sys.path.insert(0, os.path.join(project_root, 'lambda', 'ingest'))
sys.path.insert(0, os.path.join(project_root, 'lambda', 'read_recent'))

import lambda.ingest.index as ingest_module
import lambda.read_recent.index as read_module

class TestIngest(unittest.TestCase):
    def setUp(self):
        mock_table.reset_mock()
        mock_table.put_item.side_effect = None
    
    def test_valid(self):
        event = {'severity': 'info', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 201)
    
    def test_missing_severity(self):
        event = {'message': 'Test'}
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
    
    def test_error(self):
        mock_table.put_item.side_effect = Exception('Error')
        event = {'severity': 'info', 'message': 'Test'}
        response = ingest_module.lambda_handler(event, None)
        self.assertEqual(response['statusCode'], 500)

class TestRead(unittest.TestCase):
    def setUp(self):
        mock_table.reset_mock()
        mock_table.query.side_effect = None
        base_time = datetime.utcnow()
        self.entries = [{'id': str(i), 'datetime': (base_time - timedelta(minutes=i)).isoformat() + 'Z', 'severity': 'info', 'message': 'Test', 'record_type': 'log'} for i in range(10)]
    
    def test_query(self):
        mock_table.query.return_value = {'Items': self.entries}
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 10)
    
    def test_empty(self):
        mock_table.query.return_value = {'Items': []}
        response = read_module.lambda_handler({}, None)
        self.assertEqual(response['statusCode'], 200)

if __name__ == '__main__':
    unittest.main(verbosity=2)
