import unittest
import json
import sys
import os
from unittest.mock import patch, MagicMock
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

class TestIngestLambdaLocal(unittest.TestCase):
    """Local tests for Ingest Lambda without AWS connectivity"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.mock_table = MagicMock()
        self.mock_dynamodb = MagicMock()
        self.mock_dynamodb.Table.return_value = self.mock_table
        
    @patch('boto3.resource')
    def test_valid_log_entry(self, mock_boto3):
        """Test ingesting a valid log entry"""
        mock_boto3.return_value = self.mock_dynamodb
        
        # Import after mocking
        from index import lambda_handler
        
        event = {
            'severity': 'info',
            'message': 'Test log message'
        }
        
        response = lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 201)
        body = json.loads(response['body'])
        self.assertIn('log_entry', body)
        self.assertEqual(body['log_entry']['severity'], 'info')
        self.assertEqual(body['log_entry']['message'], 'Test log message')
        self.assertIn('id', body['log_entry'])
        self.assertIn('datetime', body['log_entry'])
        
        # Verify DynamoDB put_item was called
        self.mock_table.put_item.assert_called_once()
        
    @patch('boto3.resource')
    def test_missing_severity(self, mock_boto3):
        """Test with missing severity field"""
        mock_boto3.return_value = self.mock_dynamodb
        
        from index import lambda_handler
        
        event = {
            'message': 'Test log message'
        }
        
        response = lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @patch('boto3.resource')
    def test_missing_message(self, mock_boto3):
        """Test with missing message field"""
        mock_boto3.return_value = self.mock_dynamodb
        
        from index import lambda_handler
        
        event = {
            'severity': 'info'
        }
        
        response = lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @patch('boto3.resource')
    def test_invalid_severity(self, mock_boto3):
        """Test with invalid severity value"""
        mock_boto3.return_value = self.mock_dynamodb
        
        from index import lambda_handler
        
        event = {
            'severity': 'critical',
            'message': 'Test log message'
        }
        
        response = lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        self.assertIn('Invalid severity', body['error'])
        
    @patch('boto3.resource')
    def test_all_severity_levels(self, mock_boto3):
        """Test all valid severity levels"""
        mock_boto3.return_value = self.mock_dynamodb
        
        from index import lambda_handler
        
        severities = ['info', 'warning', 'error']
        
        for severity in severities:
            event = {
                'severity': severity,
                'message': f'Test {severity} message'
            }
            
            response = lambda_handler(event, None)
            
            self.assertEqual(response['statusCode'], 201)
            body = json.loads(response['body'])
            self.assertEqual(body['log_entry']['severity'], severity)
            
    @patch('boto3.resource')
    def test_dynamodb_error(self, mock_boto3):
        """Test DynamoDB error handling"""
        mock_boto3.return_value = self.mock_dynamodb
        self.mock_table.put_item.side_effect = Exception('DynamoDB error')
        
        from index import lambda_handler
        
        event = {
            'severity': 'info',
            'message': 'Test log message'
        }
        
        response = lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 500)
        body = json.loads(response['body'])
        self.assertIn('error', body)

if __name__ == '__main__':
    unittest.main()

