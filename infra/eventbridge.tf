# ============================================================
# EventBridge — Daily Cron Schedule
# ============================================================
# Triggers the Ingestion Lambda once per day.
#
# Schedule: 8:00 PM UTC = 4:00 PM EST (after market close at 4 PM)
# This ensures the day's final prices are available from Massive.
#
# Two resources needed:
#   1. The rule (the schedule itself)
#   2. The target (what the schedule triggers)
#   3. A permission (allow EventBridge to invoke the Lambda)
# ============================================================

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_name}-daily-trigger"
  description         = "Triggers stock ingestion Lambda daily after market close"
  schedule_expression = "cron(0 20 ? * MON-FRI *)"
  # Cron breakdown:
  #   0    = minute 0
  #   20   = hour 20 (8 PM UTC / 4 PM EST)
  #   ?    = any day of month
  #   *    = every month
  #   MON-FRI = weekdays only (markets don't trade on weekends)
  #   *    = every year

  tags = {
    Project = var.project_name
  }
}

# Tell EventBridge WHAT to trigger
resource "aws_cloudwatch_event_target" "invoke_ingestion" {
  rule = aws_cloudwatch_event_rule.daily_trigger.name
  arn  = aws_lambda_function.ingestion.arn
}

# Give EventBridge PERMISSION to invoke the Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
