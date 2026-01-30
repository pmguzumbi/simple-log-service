import sys
import os
import subprocess
import shutil

def clean_cache():
    """Remove all Python cache files"""
    print("Cleaning Python cache...")
    for root, dirs, files in os.walk('.'):
        # Remove __pycache__ directories
        if '__pycache__' in dirs:
            cache_path = os.path.join(root, '__pycache__')
            shutil.rmtree(cache_path, ignore_errors=True)
            print(f"  Removed: {cache_path}")
        
        # Remove .pyc files
        for file in files:
            if file.endswith('.pyc'):
                file_path = os.path.join(root, file)
                os.remove(file_path)
                print(f"  Removed: {file_path}")

def run_tests():
    """Run tests with clean environment"""
    print("
" + "="*60)
    print("Running Unit Tests with Clean Environment")
    print("="*60 + "
")
    
    # Ensure no DynamoDB endpoint is set
    env = os.environ.copy()
    env.pop('DYNAMODB_ENDPOINT', None)
    env['TABLE_NAME'] = 'log-entries'
    
    # Run pytest
    result = subprocess.run(
        [sys.executable, '-m', 'pytest', 'lambda/', '-v', '--tb=short'],
        env=env
    )
    
    return result.returncode

if __name__ == '__main__':
    clean_cache()
    exit_code = run_tests()
    sys.exit(exit_code)

