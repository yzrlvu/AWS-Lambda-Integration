output "bucket_name"    { value = aws_s3_bucket.images.bucket }
output "bucket_arn"     { value = aws_s3_bucket.images.arn }
output "sqs_queue_url"  { value = aws_sqs_queue.main.url }
output "sqs_queue_arn"  { value = aws_sqs_queue.main.arn }
output "sqs_dlq_url"    { value = aws_sqs_queue.dlq.url }
output "sqs_dlq_arn"    { value = aws_sqs_queue.dlq.arn }
output "sqs_dlq_name"   { value = aws_sqs_queue.dlq.name }
