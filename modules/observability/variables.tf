variable "name_prefix"         { type = string }
variable "sqs_dlq_name"        { type = string }
variable "log_retention_days"  { type = number }
variable "sns_alarm_email"     { type = string }
variable "upload_lambda_name"  { type = string }
variable "crop_lambda_name"    { type = string }
variable "api_gateway_id"      { type = string }
variable "aws_region" { type = string }