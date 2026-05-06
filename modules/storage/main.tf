resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "images" {
  bucket        = "${var.name_prefix}-images-${random_id.suffix.hex}"
  force_destroy = var.environment != "prod" # Protección en prod

  tags = { Name = "${var.name_prefix}-images" }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-uploads"
    status = "Enabled"
    filter { prefix = "uploads/" }
    expiration { days = var.uploads_lifecycle_days }
  }

  rule {
    id     = "expire-processed"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = var.processed_lifecycle_days }
  }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-image-dlq"
  message_retention_seconds = var.sqs_dlq_retention

  tags = { Name = "${var.name_prefix}-image-dlq" }
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.name_prefix}-image-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20 # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = { Name = "${var.name_prefix}-image-queue" }
}

resource "aws_sqs_queue_policy" "allow_s3_notify" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnLike = { "aws:SourceArn" = aws_s3_bucket.images.arn }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "uploads_to_sqs" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3_notify]
}
