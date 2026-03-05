# ============================================================
# DynamoDB Table — TopMovers
# ============================================================
# Key Design:
#   Partition Key (PK): "record_type" — always set to "STOCK_MOVER"
#   Sort Key (SK):      "date"        — formatted as "YYYY-MM-DD"
#
# Why this pattern?
#   We need to query the last 7 days efficiently. By using a fixed
#   partition key, all records live in the same partition. This lets
#   us run a single Query with ScanIndexForward=false and Limit=7
#   to get the most recent results — no Scan needed.
#
# Note: DynamoDB only requires you to define key attributes in the
#   schema. The other fields (ticker, percent_change, close_price)
#   are added dynamically when the Lambda writes items.
# ============================================================

resource "aws_dynamodb_table" "top_movers" {
  name         = "${var.project_name}-top-movers"
  billing_mode = "PAY_PER_REQUEST" # Free tier: 25 read/write capacity units

  hash_key  = "record_type" # Partition key
  range_key = "date"         # Sort key

  attribute {
    name = "record_type"
    type = "S" # S = String
  }

  attribute {
    name = "date"
    type = "S" # S = String (YYYY-MM-DD format sorts correctly)
  }

  tags = {
    Project = var.project_name
  }
}
