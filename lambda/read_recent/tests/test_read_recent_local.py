import unittest
import json
import sys
import os
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

class TestReadRecentLambdaLocal(unittest.TestCase):
    """Local tests for Read Recent Lambda without AWS connectivity"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.mock_table = MagicMock()
        self.mock_dynamodb = MagicMock()
        self.mock_dynamodb.Table.return_value = self.mock_table
        
        # Create mock log entries
        self.mock_entries = []
        base_time = datetime.utcnow()
        
        for i in range(10):
            entry = {
                'id': f'test-id-{i}',
                'datetime': (base_time - timedelta(minutes=i)).isoformat() + 'Z',
                'severity': ['info', 'warning', 'error'][i % 3],
                'message': f'Test log message {i}',
                'record_type': 'log'
            }
            self.mock_entries.append(entry)
            
        # Clear any cached imports
        if 'index' in sys.modules:
            del sys.modules['index']
    
    @patch.dict(os.environ, {'TABLE_NAME': 'log-entries'})
    @patch('boto3.resource')
    def test_successful_query(self, mock_boto3):
        """Test successful retrieval of log entries"""
        mock_boto3.return_value = self.mock_dynamodb
        self.mock_table.query.return_value = {
            'Items': self.mock_entries
        }
        
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 10)
        self.assertEqual(len(body['log_entries']), 10)
        
        # Verify query was called
        self.mock_table.query.assert_called_once()
        
    @patch.dict(os.environ, {'TABLE_NAME': 'log-entries'})
    @patch('boto3.resource')
    def test_empty_results(self, mock_boto3):
        """Test with no log entries"""
        mock_boto3.return_value = self.mock_dynamodb
        self.mock_table.query.return_value = {
            'Items': []
        }
        
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertEqual(body['count'], 0)
        self.assertEqual(len(body['log_entries']), 0)
        
    @patch.dict(os.environ, {'TABLE_NAME': 'log-entries'})
    @patch('boto3.resource')
    def test_query_fallback_to_scan(self, mock_boto3):
        """Test fallback to scan when query fails"""
        from botocore.exceptions import ClientError
        
        mock_boto3.return_value = self.mock_dynamodb
        self.mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException', 'Message': 'Query failed'}},
            'Query'
        )
        self.mock_table.scan.return_value = {
            'Items': self.mock_entries
        }
        
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertIn('note', body)
        self.assertIn('scan fallback', body['note'])
        
    @patch.dict(os.environ, {'TABLE_NAME': 'log-entries'})
    @patch('boto3.resource')
    def test_complete_failure(self, mock_boto3):
        """Test when both query and scan fail"""
        from botocore.exceptions import ClientError
        
        mock_boto3.return_value = self.mock_dynamodb
        self.mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException', 'Message': 'Query failed'}},
            'Query'
        )
        self.mock_table.scan.side_effect = Exception('Scan failed')
        
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 500)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @patch.dict(os.environ, {'TABLE_NAME': 'log-entries'})
    @patch('boto3.resource')
    def test_entries_sorted_by_datetime(self, mock_boto3):
        """Test that entries are sorted by datetime descending"""
        from botocore.exceptions import ClientError
        
        mock_boto3.return_value = self.mock_dynamodb
        
        # Create unsorted entries
        unsorted_entries = self.mock_entries.copy()
        import random
        random.shuffle(unsorted_entries)
        
        self.mock_table.query.side_effect = ClientError(
            {'Error': {'Code': 'ValidationException', 'Message': 'Query failed'}},
            'Query'
        )
        self.mock_table.scan.return_value = {
            'Items': unsorted_entries
        }
        
        import index
        
        response = index.lambda_handler({}, None)
        
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        
        # Verify entries are sorted (newest first)
        entries = body['log_entries']
        for i in range(len(entries) - 1):
            self.assertGreaterEqual(entries[i]['datetime'], entries[i + 1]['datetime'])

if __name__ == '__main__':
    unittest.main()

