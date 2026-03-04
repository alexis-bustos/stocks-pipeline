# Input Variables
# These keep secrets and config OUT of your code.
# Values are provided via terraform.tfvars (which is gitignored).

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "polygon_api_key" {
  description = "API key for Polygon.io stock data"
  type        = string
  sensitive   = true  # Terraform will mask this in output
}

variable "project_name" {
  description = "Project name used for consistent resource naming"
  type        = string
  default     = "stocks-pipeline"
}
