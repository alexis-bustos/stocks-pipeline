# ============================================================
# Outputs
# ============================================================
# These values are printed after 'terraform apply' and can be
# referenced with 'terraform output <name>'.
# They give you the URLs you need to test and share your project.
# ============================================================

output "api_url" {
  description = "The URL for the GET /movers endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/movers"
}

output "frontend_url" {
  description = "The public URL of the S3-hosted frontend"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "frontend_bucket_name" {
  description = "S3 bucket name (needed for uploading frontend files)"
  value       = aws_s3_bucket.frontend.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.top_movers.name
}

output "ingestion_lambda_name" {
  description = "Name of the ingestion Lambda function"
  value       = aws_lambda_function.ingestion.function_name
}
