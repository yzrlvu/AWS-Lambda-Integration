output "dlq_alarm_arn"   { value = aws_cloudwatch_metric_alarm.dlq_messages.arn }
output "sns_topic_arn"   { value = aws_sns_topic.alerts.arn }
output "dashboard_name"  { value = aws_cloudwatch_dashboard.main.dashboard_name }
