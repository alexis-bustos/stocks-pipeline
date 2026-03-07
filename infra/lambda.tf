# ============================================================
# Lambda Functions + IAM Roles
# ============================================================
# Two separate Lambda functions, each with its own IAM role.
# This enforces least-privilege: the ingestion function can
# only WRITE to DynamoDB, the retrieval function can only READ.
# ============================================================


# ============================================================
# 1. INGESTION LAMBDA (triggered by EventBridge)
# ============================================================

# --- IAM Role: What the Ingestion Lambda is allowed to do ---

# Trust policy: "Allow the Lambda service to assume this role"
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingestion_lambda_role" {
  name               = "${var.project_name}-ingestion-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permission policy: Only PutItem on our specific DynamoDB table
data "aws_iam_policy_document" "ingestion_policy" {
  # Allow writing to DynamoDB
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.top_movers.arn]
  }

  # Allow writing logs to CloudWatch (essential for debugging)
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "ingestion_policy" {
  name   = "${var.project_name}-ingestion-policy"
  role   = aws_iam_role.ingestion_lambda_role.id
  policy = data.aws_iam_policy_document.ingestion_policy.json
}

# --- Package the Lambda code as a zip ---
data "archive_file" "ingestion_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/ingestion/handler.py"
  output_path = "${path.module}/../lambdas/ingestion/handler.zip"
}

# --- The Lambda function itself ---
resource "aws_lambda_function" "ingestion" {
  function_name    = "${var.project_name}-ingestion"
  role             = aws_iam_role.ingestion_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.13"
  timeout          = 120 # 2 minutes (needs time for rate-limited API calls)
  filename         = data.archive_file.ingestion_zip.output_path
  source_code_hash = data.archive_file.ingestion_zip.output_base64sha256

  environment {
    variables = {
      MASSIVE_API_KEY = var.massive_api_key
      DYNAMODB_TABLE  = aws_dynamodb_table.top_movers.name
    }
  }

  tags = {
    Project = var.project_name
  }
}


# ============================================================
# 2. RETRIEVAL LAMBDA (triggered by API Gateway)
# ============================================================

resource "aws_iam_role" "retrieval_lambda_role" {
  name               = "${var.project_name}-retrieval-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permission policy: Only Query on our specific DynamoDB table
data "aws_iam_policy_document" "retrieval_policy" {
  # Allow reading from DynamoDB (Query, not Scan)
  statement {
    actions   = ["dynamodb:Query"]
    resources = [aws_dynamodb_table.top_movers.arn]
  }

  # Allow writing logs to CloudWatch
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "retrieval_policy" {
  name   = "${var.project_name}-retrieval-policy"
  role   = aws_iam_role.retrieval_lambda_role.id
  policy = data.aws_iam_policy_document.retrieval_policy.json
}

# --- Package the Lambda code as a zip ---
data "archive_file" "retrieval_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/retrieval/handler.py"
  output_path = "${path.module}/../lambdas/retrieval/handler.zip"
}

# --- The Lambda function itself ---
resource "aws_lambda_function" "retrieval" {
  function_name    = "${var.project_name}-retrieval"
  role             = aws_iam_role.retrieval_lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.13"
  timeout          = 10 # Fast — just a DynamoDB query
  filename         = data.archive_file.retrieval_zip.output_path
  source_code_hash = data.archive_file.retrieval_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.top_movers.name
    }
  }

  tags = {
    Project = var.project_name
  }
}
