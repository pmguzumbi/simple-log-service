
import unittest
import json
import sys
import os
from unittest.mock import patch, MagicMock

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


class TestIngestLambdaLocal(unittest.TestCase):
    """Local tests for Ingest Lambda without AWS connectivity"""
    
    def setUp(self):
        """Set up test fixtures"""
        # Clear cached module
        if 'index' in sys.modules:
            del sys.modules['index']
        
        # Set environment
        os.environ['TABLE_NAME'] = 'log-entries'
        os.environ['AWS_DEFAULT_REGION'] = 'eu-west-1'
        
    @patch('boto3.resource')
    def test_valid_log_entry(self, mock_boto3):
        """Test ingesting a valid log entry"""
        # Setup mock
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
        # Import after patching
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
        
        # Verify DynamoDB put_item was called
        mock_table.put_item.assert_called_once()
        
    @patch('boto3.resource')
    def test_missing_severity(self, mock_boto3):
        """Test with missing severity field"""
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
        import index
        
        event = {
            'message': 'Test log message'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @patch('boto3.resource')
    def test_missing_message(self, mock_boto3):
        """Test with missing message field"""
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
        import index
        
        event = {
            'severity': 'info'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)
        
    @patch('boto3.resource')
    def test_invalid_severity(self, mock_boto3):
        """Test with invalid severity value"""
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
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
        
    @patch('boto3.resource')
    def test_all_severity_levels(self, mock_boto3):
        """Test all valid severity levels"""
        mock_table = MagicMock()
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
        import index
        
        severities = ['info', 'warning', 'error']
        
        for severity in severities:
            mock_table.reset_mock()
            
            event = {
                'severity': severity,
                'message': f'Test {severity} message'
            }
            
            response = index.lambda_handler(event, None)
            
            self.assertEqual(response['statusCode'], 201, f"Failed for severity: {severity}")
            body = json.loads(response['body'])
            self.assertEqual(body['log_entry']['severity'], severity)
            
    @patch('boto3.resource')
    def test_dynamodb_error(self, mock_boto3):
        """Test DynamoDB error handling"""
        mock_table = MagicMock()
        mock_table.put_item.side_effect = Exception('DynamoDB error')
        mock_dynamodb = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        mock_boto3.return_value = mock_dynamodb
        
        import index
        
        event = {
            'severity': 'info',
            'message': 'Test log message'
        }
        
        response = index.lambda_handler(event, None)
        
        self.assertEqual(response['statusCode'], 500)
        body = json.loads(response['body'])
        self.assertIn('error', body)


if __name__ == '__main__':
    unittest.main()

