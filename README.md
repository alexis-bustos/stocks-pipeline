# Stocks Serverless Pipeline

A fully automated serverless system that tracks which tech stock from a curated watchlist had the highest percentage price change each day.

## Architecture Overview

![Architecture Diagram](architecture-diagram.svg)

This project implements a **three-tier serverless architecture**:

| Tier             | AWS Services                          | Purpose                                                                    |
| ---------------- | ------------------------------------- | -------------------------------------------------------------------------- |
| **Presentation** | S3 (Static Website Hosting)           | Single Page Application displaying the Top Mover history                   |
| **Logic**        | EventBridge, Lambda (x2), API Gateway | Ingestion (daily cron) and Retrieval (on-demand API) as separate functions |
| **Data**         | DynamoDB                              | Stores daily winner: date, ticker, % change, closing price                 |

### Key Design Decision: Separation of Concerns

The backend uses **two independent Lambda functions**:

- **Ingestion Lambda** — Triggered daily by EventBridge. Fetches stock data from Polygon.io, calculates percentage change for each ticker, identifies the top mover, and writes the result to DynamoDB.
- **Retrieval Lambda** — Invoked by API Gateway on `GET /movers`. Reads the last 7 days of results from DynamoDB and returns clean JSON.

These functions share no code and have independent IAM roles with least-privilege permissions.

## Tech Stack

- **IaC:** Terraform
- **Runtime:** Python 3.9
- **Stock API:** Polygon.io (Free Tier)
- **AWS Services:** Lambda, DynamoDB, API Gateway, EventBridge, S3

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with your credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- Python 3.9+
- A free [Polygon.io](https://polygon.io/) API key

## Project Structure

```
stocks-pipeline/
├── infra/                    # Terraform configuration
│   ├── main.tf               # Provider and core config
│   ├── variables.tf          # Input variables
│   ├── dynamodb.tf           # DynamoDB table definition
│   ├── lambda.tf             # Lambda functions + IAM roles
│   ├── eventbridge.tf        # Cron schedule rule
│   ├── api_gateway.tf        # REST API definition
│   ├── s3.tf                 # Static website hosting
│   └── outputs.tf            # Useful output values (URLs, ARNs)
├── lambdas/
│   ├── ingestion/            # Daily cron function
│   │   └── handler.py
│   └── retrieval/            # API-triggered function
│       └── handler.py
├── frontend/                 # Single Page Application
│   ├── index.html
│   ├── style.css
│   └── app.js
├── .gitignore
├── architecture-diagram.svg
└── README.md
```

## Deployment

### 1. Clone and Configure

```bash
git clone https://github.com/YOUR_USERNAME/stocks-pipeline.git
cd stocks-pipeline
```

### 2. Set Your Variables

Create a `terraform.tfvars` file in the `infra/` directory (this file is gitignored):

```hcl
polygon_api_key = "your-polygon-api-key-here"
aws_region      = "us-east-1"
```

### 3. Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

### 4. Deploy Frontend

```bash
# After terraform apply, upload the frontend to the S3 bucket:
aws s3 sync ../frontend/ s3://$(terraform output -raw frontend_bucket_name)
```

### 5. Verify

- Visit the S3 website URL from `terraform output frontend_url`
- Check the API at `terraform output api_url`

## API Reference

### GET /movers

Returns the last 7 days of top stock movers.

**Response:**

```json
{
  "data": [
    {
      "date": "2026-03-03",
      "ticker": "TSLA",
      "percent_change": -4.72,
      "close_price": 248.5
    }
  ]
}
```

## Trade-offs & Challenges

<!-- Fill this in as you build — the evaluators want to see self-awareness -->

-
-
-

## License

MIT
