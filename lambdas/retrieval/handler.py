# Retrieval Lambda
# This function is invoked by API Gateway on GET /movers.
# It will:
#   1. Query DynamoDB for the last 7 days of records
#   2. Format the results as clean JSON
#   3. Return with proper HTTP status codes and CORS headers
