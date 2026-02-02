#!/usr/bin/env python3
"""
API Testing Script for Simple Log Service
Tests both log ingestion and retrieval endpoints
Compatible with Windows PowerShell
"""

import json
import sys
import time
from datetime import datetime
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

# Configuration
API_ENDPOINT = ""  # Set this from Terraform output or pass as argument
REGION = "eu-west-2"

def get_api_endpoint():
    """Get API endpoint from Terraform output or environment"""
    global API_ENDPOINT
    
    if API_ENDPOINT:
        return API_ENDPOINT
    
    # Try to get from Terraform output
    try:
        import subprocess
        result = subprocess.run(
            ["terraform", "output", "-raw", "api_gateway_url"],
            cwd="../terraform",
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            API_ENDPOINT = result.stdout.strip()
            return API_ENDPOINT
    except Exception as e:
        print(f"Could not get API endpoint from Terraform: {e}")
    
    # Prompt user
    API_ENDPOINT = input("Enter API Gateway endpoint URL: ").strip()
    return API_ENDPOINT

def sign_request(method, url, body=None, params=None):
    """Sign request with AWS SigV4"""
    session = boto3.Session()
    credentials = session.get_credentials()
    
    request = AWSRequest(
        method=method,
        url=url,
        data=body,
        params=params
    )
    
    SigV4Auth(credentials, "execute-api", REGION).add_auth(request)
    return dict(request.headers)

def test_ingest_log():
    """Test log ingestion endpoint"""
    print("=== Testing Log Ingestion ===")
    
    endpoint = get_api_endpoint()
    url = f"{endpoint}/logs"
    
    # Test data
    log_data = {
        "service_name": "test-service",
        "log_type": "application",
        "level": "INFO",
        "message": f"Test log message at {datetime.utcnow().isoformat()}",
        "metadata": {
            "test_id": "12345",
            "environment": "test"
        }
    }
    
    body = json.dumps(log_data)
    headers = sign_request("POST", url, body=body)
    headers["Content-Type"] = "application/json"
    
    try:
        response = requests.post(url, data=body, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 201:
            print("✓ Log ingestion successful")
            return True
        else:
            print("✗ Log ingestion failed")
            return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def test_read_recent():
    """Test log retrieval endpoint"""
    print("=== Testing Log Retrieval ===")
    
    endpoint = get_api_endpoint()
    url = f"{endpoint}/logs/recent"
    
    # Test with different query parameters
    test_cases = [
        {"params": None, "description": "All recent logs"},
        {"params": {"service_name": "test-service"}, "description": "Filter by service"},
        {"params": {"limit": "10"}, "description": "Limit results"},
    ]
    
    success_count = 0
    
    for test_case in test_cases:
        print(f"Test: {test_case['description']}")
        
        headers = sign_request("GET", url, params=test_case["params"])
        
        try:
            response = requests.get(url, params=test_case["params"], headers=headers)
            print(f"Status Code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"Logs retrieved: {data.get('count', 0)}")
                print("✓ Test passed")
                success_count += 1
            else:
                print(f"Response: {response.text}")
                print("✗ Test failed")
        except Exception as e:
            print(f"✗ Error: {e}")
    
    return success_count == len(test_cases)

def run_integration_test():
    """Run complete integration test"""
    print("=" * 60)
    print("Simple Log Service - Integration Test")
    print("=" * 60)
    
    # Test ingestion
    ingest_success = test_ingest_log()
    
    # Wait for data to be available
    print("Waiting 2 seconds for data propagation...")
    time.sleep(2)
    
    # Test retrieval
    read_success = test_read_recent()
    
    # Summary
    print("" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    print(f"Log Ingestion: {'✓ PASSED' if ingest_success else '✗ FAILED'}")
    print(f"Log Retrieval: {'✓ PASSED' if read_success else '✗ FAILED'}")
    
    if ingest_success and read_success:
        print("
✓ All tests passed!")
        return 0
    else:
        print("
✗ Some tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(run_integration_test())

