# variables.tf
variable "name_prefix"              { type = string }
variable "environment"              { type = string }
variable "uploads_lifecycle_days"   { type = number }
variable "processed_lifecycle_days" { type = number }
variable "sqs_visibility_timeout"   { type = number }
variable "sqs_message_retention"    { type = number }
variable "sqs_dlq_retention"        { type = number }
variable "sqs_max_receive_count"    { type = number }
