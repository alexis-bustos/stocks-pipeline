# Stocks Serverless Pipeline - Terraform Configuration
# This is the main entry point for Terraform.

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "stocks-pipeline-tfstate-062700375064"
    key            = "stocks-pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "stocks-pipeline-tf-locks" # DynamoDB locking is deprecated; migrating to use_lockfile in a future iteration.
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
