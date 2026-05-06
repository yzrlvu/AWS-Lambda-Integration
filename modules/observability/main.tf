resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_alarm_email
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.name_prefix}-dlq-messages-alarm"
  alarm_description   = "Hay mensajes en la DLQ — revisar errores de crop-lambda."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.sqs_dlq_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "upload_errors" {
  alarm_name          = "${var.name_prefix}-upload-lambda-errors"
  alarm_description   = "upload-lambda está produciendo errores."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = var.upload_lambda_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "crop_errors" {
  alarm_name          = "${var.name_prefix}-crop-lambda-errors"
  alarm_description   = "crop-lambda está produciendo errores."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = var.crop_lambda_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Lambda Invocations"
          period = 60
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.upload_lambda_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.crop_lambda_name],
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Lambda Errors"
          period = 60
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.upload_lambda_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.crop_lambda_name],
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "SQS Messages"
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${replace(var.sqs_dlq_name, "-dlq", "-queue")}"],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_dlq_name],
          ]
        }
      }
    ]
  })
}
