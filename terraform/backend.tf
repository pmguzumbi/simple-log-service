
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  # Change this
    key            = "simple-log-service/terraform.tfstate"
    region         = "us-east-1"  # Change to your region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"  # For state locking
  }
}

