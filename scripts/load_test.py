#!/usr/bin/env python3
"""
Load Testing Script for Simple Log Service
Simulates concurrent log ingestion and retrieval
Compatible with Windows PowerShell
"""

import json
import time
import statistics
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

# Configuration
API_ENDPOINT = ""  # Set from Terraform output
REGION = "eu-west-2"
NUM_REQUESTS = 100
CONCURRENT_WORKERS = 10

def get_api_endpoint():
    """Get API endpoint from Terraform output"""
    global API_ENDPOINT
    
    if API_ENDPOINT:
        return API_ENDPOINT
    
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
    except Exception:
        pass
    
    API_ENDPOINT = input("Enter API Gateway endpoint URL: ").strip()
    return API_ENDPOINT

def sign_request(method, url, body=None):
    """Sign request with AWS SigV4"""
    session = boto3.Session()
    credentials = session.get_credentials()
    
    request = AWSRequest(method=method, url=url, data=body)
    SigV4Auth(credentials, "execute-api", REGION).add_auth(request)
    return dict(request.headers)

def ingest_log(request_id):
    """Ingest a single log entry"""
    endpoint = get_api_endpoint()
    url = f"{endpoint}/logs"
    
    log_data = {
        "service_name": "load-test-service",
        "log_type": "performance",
        "level": "INFO",
        "message": f"Load test message {request_id}",
        "metadata": {
            "request_id": str(request_id),
            "timestamp": datetime.utcnow().isoformat()
        }
    }
    
    body = json.dumps(log_data)
    headers = sign_request("POST", url, body=body)
    headers["Content-Type"] = "application/json"
    
    start_time = time.time()
    
    try:
        response = requests.post(url, data=body, headers=headers, timeout=30)
        duration = (time.time() - start_time) * 1000  # Convert to ms
        
        return {
            "success": response.status_code == 201,
            "status_code": response.status_code,
            "duration_ms": duration,
            "request_id": request_id
        }
    except Exception as e:
        duration = (time.time() - start_time) * 1000
        return {
            "success": False,
            "status_code": 0,
            "duration_ms": duration,
            "request_id": request_id,
            "error": str(e)
        }

def run_load_test():
    """Run load test with concurrent requests"""
    print("=" * 60)
    print("Simple Log Service - Load Test")
    print("=" * 60)
    print(f"Total Requests: {NUM_REQUESTS}")
    print(f"Concurrent Workers: {CONCURRENT_WORKERS}")
    print("=" * 60)
    
    results = []
    start_time = time.time()
    
    # Execute concurrent requests
    with ThreadPoolExecutor(max_workers=CONCURRENT_WORKERS) as executor:
        futures = [executor.submit(ingest_log, i) for i in range(NUM_REQUESTS)]
        
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            
            # Progress indicator
            if len(results) % 10 == 0:
                print(f"Progress: {len(results)}/{NUM_REQUESTS} requests completed")
    
    total_time = time.time() - start_time
    
    # Calculate statistics
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]
    durations = [r["duration_ms"] for r in successful]
    
    # Print results
    print("" + "=" * 60)
    print("Load Test Results")
    print("=" * 60)
    print(f"Total Requests: {NUM_REQUESTS}")
    print(f"Successful: {len(successful)} ({len(successful)/NUM_REQUESTS*100:.2f}%)")
    print(f"Failed: {len(failed)} ({len(failed)/NUM_REQUESTS*100:.2f}%)")
    print(f"Total Time: {total_time:.2f}s")
    print(f"Requests/Second: {NUM_REQUESTS/total_time:.2f}")
    
    if durations:
        print("
Response Time Statistics (ms):")
        print(f"  Min: {min(durations):.2f}")
        print(f"  Max: {max(durations):.2f}")
        print(f"  Mean: {statistics.mean(durations):.2f}")
        print(f"  Median: {statistics.median(durations):.2f}")
        print(f"  P50: {statistics.quantiles(durations, n=100)[49]:.2f}")
        print(f"  P95: {statistics.quantiles(durations, n=100)[94]:.2f}")
        print(f"  P99: {statistics.quantiles(durations, n=100)[98]:.2f}")
    
    if failed:
        print("
Failed Requests:")
        for result in failed[:5]:  # Show first 5 failures
            print(f"  Request {result['request_id']}: {result.get('error', 'Unknown error')}")
    
    print("=" * 60)
    
    return 0 if len(failed) == 0 else 1

if __name__ == "__main__":
    import sys
    sys.exit(run_load_test())

