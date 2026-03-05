"""
Ingestion Lambda — Daily Top Stock Mover

Triggered by: Amazon EventBridge (daily cron schedule)

What it does:
  1. Fetches open/close prices from Massive.com for each stock in the watchlist
  2. Calculates percentage change: ((Close - Open) / Open) * 100
  3. Finds the stock with the highest absolute % change
  4. Writes the winner to the DynamoDB "TopMovers" table

Key design decisions:
  - Uses time.sleep() between API calls to respect Massive's 5 calls/min rate limit
  - Retries failed API calls up to 3 times with exponential backoff
  - Logs extensively for CloudWatch debugging
  - Uses "previous trading day" logic to handle weekends/holidays
"""

import json
import os
import time
import logging

from datetime import datetime, timedelta, timezone
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

import boto3

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
WATCHLIST = ["AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "NVDA"]
MASSIVE_API_KEY = os.environ["MASSIVE_API_KEY"]
TABLE_NAME = os.environ["DYNAMODB_TABLE"]

# Set up logging — these logs appear in CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB client
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


# ---------------------------------------------------------------------------
# Helper: Call Massive API with retries
# ---------------------------------------------------------------------------
def fetch_daily_data(ticker, date_str):
    """
    Fetch open/close data for a single ticker on a given date.

    Uses the Massive.com Daily Open/Close endpoint:
      GET /v1/open-close/{ticker}/{date}?adjusted=true&apiKey=...

    Returns a dict with 'open' and 'close' keys, or None on failure.
    Implements retry logic with exponential backoff for resilience.
    """
    url = (
        f"https://api.massive.com/v1/open-close/{ticker}/{date_str}"
        f"?adjusted=true&apiKey={MASSIVE_API_KEY}"
    )

    max_retries = 3

    for attempt in range(max_retries):
        try:
            req = Request(url)
            with urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode())

            # Check if Massive returned a valid response
            if data.get("status") == "OK":
                return {
                    "open": float(data["open"]),
                    "close": float(data["close"]),
                }
            elif data.get("status") == "NOT_FOUND":
                logger.warning(f"No data for {ticker} on {date_str} (market closed?)")
                return None
            else:
                logger.warning(f"Unexpected status for {ticker}: {data.get('status')}")
                return None

        except HTTPError as e:
            if e.code == 429:
                # Rate limited — wait longer before retrying
                wait_time = 60 * (attempt + 1)
                logger.warning(f"Rate limited on {ticker}. Waiting {wait_time}s...")
                time.sleep(wait_time)
            elif e.code == 403:
                logger.error(f"Authentication failed. Check your Massive API key.")
                return None
            else:
                logger.error(f"HTTP {e.code} for {ticker}: {e.reason}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)
                else:
                    return None

        except URLError as e:
            logger.error(f"Network error for {ticker}: {e.reason}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
            else:
                return None

    return None


# ---------------------------------------------------------------------------
# Helper: Get the most recent trading day
# ---------------------------------------------------------------------------
def get_previous_trading_day():
    """
    Returns yesterday's date as a string (YYYY-MM-DD).
    If yesterday was a weekend, walks back to Friday.

    Note: This does not account for market holidays (e.g., MLK Day).
    The API will simply return no data for holidays, which we handle
    gracefully in fetch_daily_data().
    """
    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=1)

    # Walk back past weekends: Saturday (5) → Friday, Sunday (6) → Friday
    while yesterday.weekday() >= 5:  # 5 = Saturday, 6 = Sunday
        yesterday -= timedelta(days=1)

    return yesterday.strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# Main Lambda Handler
# ---------------------------------------------------------------------------
def lambda_handler(event, context):
    """
    Entry point for the Lambda function.

    EventBridge sends an event daily, but we don't need anything from it.
    The 'event' and 'context' parameters are required by AWS Lambda.
    """
    # Allow manual date override for backfilling, otherwise use previous trading day
    date_str = event.get("date") if event.get("date") else get_previous_trading_day()
    logger.info(f"Fetching stock data for: {date_str}")

    results = []

    for ticker in WATCHLIST:
        logger.info(f"Fetching data for {ticker}...")
        data = fetch_daily_data(ticker, date_str)

        if data is None:
            logger.warning(f"Skipping {ticker} — no data returned.")
            continue

        # The formula from the project requirements:
        # ((Close - Open) / Open) * 100
        percent_change = ((data["close"] - data["open"]) / data["open"]) * 100

        results.append({
            "ticker": ticker,
            "percent_change": round(percent_change, 2),
            "close_price": data["close"],
        })

        logger.info(
            f"  {ticker}: Open={data['open']}, Close={data['close']}, "
            f"Change={percent_change:.2f}%"
        )

        # Respect Massive's rate limit: 5 calls/min on free tier
        # Sleep 13 seconds between calls to stay safely under the limit
        # (6 tickers * 13s = 78s total, well within Lambda's 15-min timeout)
        time.sleep(13)

    # --- Find the top mover (highest absolute % change) ---
    if not results:
        logger.error("No stock data retrieved for any ticker. Exiting.")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "No data available for any ticker"}),
        }

    top_mover = max(results, key=lambda x: abs(x["percent_change"]))

    logger.info(
        f"Top mover: {top_mover['ticker']} "
        f"with {top_mover['percent_change']}% change"
    )

    # --- Write to DynamoDB ---
    try:
        table.put_item(
            Item={
                "record_type": "STOCK_MOVER",  # Fixed partition key
                "date": date_str,               # Sort key
                "ticker": top_mover["ticker"],
                "percent_change": str(top_mover["percent_change"]),  # DynamoDB stores as Decimal
                "close_price": str(top_mover["close_price"]),
            }
        )
        logger.info(f"Successfully wrote top mover to DynamoDB.")

    except Exception as e:
        logger.error(f"Failed to write to DynamoDB: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Database write failed"}),
        }

    # --- Return success ---
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Top mover recorded successfully",
            "date": date_str,
            "top_mover": top_mover,
        }),
    }