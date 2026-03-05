"""
Retrieval Lambda — GET /movers API Endpoint

Triggered by: API Gateway (GET /movers)

What it does:
  1. Queries DynamoDB for the last 7 days of top stock movers
  2. Formats the results as clean JSON
  3. Returns with proper HTTP status codes and CORS headers

Key design decisions:
  - Uses Query (not Scan) for efficient DynamoDB reads
  - Fixed partition key "STOCK_MOVER" + ScanIndexForward=False gives us
    results sorted by date descending — newest first
  - CORS headers allow the S3-hosted frontend to call this API
  - Separated from the Ingestion Lambda (different IAM role, single responsibility)
"""

import json
import os
import logging
import boto3
from boto3.dynamodb.conditions import Key

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
TABLE_NAME = os.environ["DYNAMODB_TABLE"]

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB client
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

# CORS headers — required so the S3-hosted frontend can call this API.
# Without these, the browser blocks the request (same-origin policy).
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",       # In production, restrict to your S3 URL
    "Access-Control-Allow-Methods": "GET",
    "Access-Control-Allow-Headers": "Content-Type",
}


# ---------------------------------------------------------------------------
# Main Lambda Handler
# ---------------------------------------------------------------------------
def lambda_handler(event, context):
    """
    Entry point for the Lambda function.

    API Gateway sends the HTTP request details in 'event'.
    We only care about GET /movers, so the logic is straightforward.
    """
    logger.info("Received request for /movers")

    try:
        # Query DynamoDB for the last 7 top movers
        # - Partition key = "STOCK_MOVER" (all records share this)
        # - ScanIndexForward=False sorts by date DESCENDING (newest first)
        # - Limit=7 gives us exactly one week of data
        response = table.query(
            KeyConditionExpression=Key("record_type").eq("STOCK_MOVER"),
            ScanIndexForward=False,
            Limit=7,
        )

        items = response.get("Items", [])
        logger.info(f"Retrieved {len(items)} records from DynamoDB")

        # Format the response — convert DynamoDB types to clean JSON
        movers = []
        for item in items:
            movers.append({
                "date": item["date"],
                "ticker": item["ticker"],
                "percent_change": float(item["percent_change"]),
                "close_price": float(item["close_price"]),
            })

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({
                "data": movers,
                "count": len(movers),
            }),
        }

    except Exception as e:
        logger.error(f"Error querying DynamoDB: {str(e)}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({
                "error": "Failed to retrieve data",
                "message": str(e),
            }),
        }