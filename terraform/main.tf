# Main Terraform configuration for Simple Log Service

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  
  # Optional: Configure S3 backend for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "simple-log-service/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  #   kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
  # }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
  
  # Default tags applied to all resources
  default_tags {
    tags = {
      Project     = "SimpleLogService"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps"
      CostCenter  = "Engineering"
    }
  }
}

# Data source for available availability zones
data "aws_availability_zones" "available" {
  state = "available"
  
  # Filter to only include zones in the configured region
  filter {
    name   = "region-name"
    values = [var.aws_region]
  }
}

# Local variables for common values
locals {
  account_id = data.aws_caller_identity.current.account_id
  
  # Availability zones for multi-AZ deployment
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Common resource naming prefix
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

