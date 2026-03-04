# Ingestion Lambda
# This function is triggered daily by EventBridge.
# It will:
#   1. Call Polygon.io for each stock in the watchlist
#   2. Calculate ((Close - Open) / Open) * 100 for each
#   3. Find the stock with the highest absolute % change
#   4. Write the winner to DynamoDB
