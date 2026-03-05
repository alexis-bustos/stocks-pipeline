# ============================================================
# API Gateway — REST API
# ============================================================
# Creates a public REST API with one endpoint:
#   GET /movers → invokes the Retrieval Lambda
#
# Also configures CORS so the S3-hosted frontend can call it.
# ============================================================

# --- The API itself ---
resource "aws_api_gateway_rest_api" "stocks_api" {
  name        = "${var.project_name}-api"
  description = "REST API for the Stocks Serverless Pipeline"

  tags = {
    Project = var.project_name
  }
}

# --- The /movers resource (URL path) ---
resource "aws_api_gateway_resource" "movers" {
  rest_api_id = aws_api_gateway_rest_api.stocks_api.id
  parent_id   = aws_api_gateway_rest_api.stocks_api.root_resource_id
  path_part   = "movers"
}

# --- GET method on /movers ---
resource "aws_api_gateway_method" "get_movers" {
  rest_api_id   = aws_api_gateway_rest_api.stocks_api.id
  resource_id   = aws_api_gateway_resource.movers.id
  http_method   = "GET"
  authorization = "NONE" # Public endpoint — no auth required
}

# --- Connect GET /movers to the Retrieval Lambda ---
resource "aws_api_gateway_integration" "get_movers_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stocks_api.id
  resource_id             = aws_api_gateway_resource.movers.id
  http_method             = aws_api_gateway_method.get_movers.http_method
  integration_http_method = "POST" # Lambda integrations always use POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.retrieval.invoke_arn
}

# --- Give API Gateway permission to invoke the Lambda ---
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieval.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.stocks_api.execution_arn}/*/*"
}

# ============================================================
# CORS — OPTIONS method for preflight requests
# ============================================================
# Browsers send an OPTIONS request before the actual GET.
# This "preflight" checks if CORS is allowed.
# We handle it with a mock integration (no Lambda needed).
# ============================================================

resource "aws_api_gateway_method" "options_movers" {
  rest_api_id   = aws_api_gateway_rest_api.stocks_api.id
  resource_id   = aws_api_gateway_resource.movers.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.stocks_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.stocks_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.stocks_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_integration]
}

# ============================================================
# Deploy the API
# ============================================================
# The API must be "deployed" to a "stage" to be accessible.
# Think of a stage as an environment (dev, prod, etc).
# ============================================================

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.stocks_api.id

  # Redeploy when any of these resources change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.movers.id,
      aws_api_gateway_method.get_movers.id,
      aws_api_gateway_integration.get_movers_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_movers_integration,
    aws_api_gateway_integration.options_integration,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.stocks_api.id
  stage_name    = "prod"

  tags = {
    Project = var.project_name
  }
}
