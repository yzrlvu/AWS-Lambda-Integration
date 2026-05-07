data "archive_file" "upload_lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/upload_placeholder.zip"

  source {
    content  = <<-JS
      // upload-lambda placeholder
      // Runtime: nodejs20.x | Handler: index.handler
      // Deps reales: @aws-sdk/client-s3, busboy, uuid
      exports.handler = async (event) => {
        return { statusCode: 200, body: JSON.stringify({ message: "upload-lambda OK" }) };
      };
    JS
    filename = "index.js"
  }
}

data "archive_file" "crop_lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/crop_placeholder.zip"

  source {
    content  = <<-JS
      // crop-lambda placeholder
      // Runtime: nodejs20.x | Handler: index.handler
      // Deps reales: @aws-sdk/client-s3, sharp 0.33
      exports.handler = async (event) => {
        console.log("crop-lambda procesando", event.Records?.length, "mensajes");
        return { batchItemFailures: [] };
      };
    JS
    filename = "index.js"
  }
}

resource "aws_security_group" "upload_lambda" {
  name        = "${var.name_prefix}-sg-upload-lambda"
  description = "upload-lambda: sin inbound, outbound HTTPS."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS a S3 y SQS endpoints"
  }

  tags = { Name = "${var.name_prefix}-sg-upload-lambda" }
}

resource "aws_security_group" "crop_lambda" {
  name        = "${var.name_prefix}-sg-crop-lambda"
  description = "crop-lambda: sin inbound, outbound HTTPS."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS a S3 y SQS endpoints"
  }

  tags = { Name = "${var.name_prefix}-sg-crop-lambda" }
}

resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/${var.name_prefix}-upload"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/${var.name_prefix}-crop"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "upload" {
  function_name    = "${var.name_prefix}-upload"
  role             = var.upload_lambda_role_arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = var.upload_lambda_memory
  timeout          = var.upload_lambda_timeout
  filename         = data.archive_file.upload_lambda_placeholder.output_path
  source_code_hash = data.archive_file.upload_lambda_placeholder.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET     = var.bucket_name
      UPLOAD_PREFIX = "uploads/"
      ENVIRONMENT   = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.upload_lambda]
  tags       = { Name = "${var.name_prefix}-upload" }
}

resource "aws_lambda_function" "crop" {
  function_name    = "${var.name_prefix}-crop"
  role             = var.crop_lambda_role_arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = var.crop_lambda_memory
  timeout          = var.crop_lambda_timeout
  filename         = data.archive_file.crop_lambda_placeholder.output_path
  source_code_hash = data.archive_file.crop_lambda_placeholder.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET         = var.bucket_name
      PROCESSED_PREFIX  = "processed/"
      ENVIRONMENT       = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.crop_lambda]
  tags       = { Name = "${var.name_prefix}-crop" }
}

resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.crop.arn
  batch_size                         = var.crop_sqs_batch_size
  maximum_batching_window_in_seconds = 5
  enabled                            = true

  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 10
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"
  description   = "HTTP API v2 — Image Processor ${var.environment}"

  cors_configuration {
    allow_headers = ["Content-Type", "Authorization"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.api_throttle_rate
    throttling_burst_limit = var.api_throttle_burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      protocol       = "$context.protocol"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_apigatewayv2_integration" "upload_lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_lambda.id}"
}

resource "aws_lambda_permission" "apigw_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*/upload"
}
