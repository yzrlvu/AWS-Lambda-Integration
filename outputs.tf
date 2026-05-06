output "api_endpoint_url" {
  description = "URL pública del endpoint POST /upload de API Gateway. Usar para probar la aplicación."
  value       = "${module.compute.api_gateway_url}/upload"
}

output "api_gateway_id" {
  description = "ID del API Gateway HTTP API."
  value       = module.compute.api_gateway_id
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 de imágenes."
  value       = module.storage.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3."
  value       = module.storage.bucket_arn
}

output "sqs_main_queue_url" {
  description = "URL de la cola SQS principal."
  value       = module.storage.sqs_queue_url
}

output "sqs_dlq_url" {
  description = "URL de la Dead-Letter Queue."
  value       = module.storage.sqs_dlq_url
}

output "upload_lambda_arn" {
  description = "ARN de upload-lambda."
  value       = module.compute.upload_lambda_arn
}

output "crop_lambda_arn" {
  description = "ARN de crop-lambda."
  value       = module.compute.crop_lambda_arn
}

output "vpc_id" {
  description = "ID del VPC."
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas."
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = module.networking.public_subnet_ids
}

output "upload_lambda_role_arn" {
  description = "ARN del rol IAM de upload-lambda."
  value       = module.iam.upload_lambda_role_arn
}

output "crop_lambda_role_arn" {
  description = "ARN del rol IAM de crop-lambda."
  value       = module.iam.crop_lambda_role_arn
}

output "cloudwatch_alarm_arn" {
  description = "ARN del CloudWatch Alarm de DLQ."
  value       = module.observability.dlq_alarm_arn
}

output "deployment_summary" {
  description = "Resumen del despliegue para incluir en el informe."
  value = {
    environment     = var.environment
    region          = var.aws_region
    project         = var.project_name
    upload_endpoint = "${module.compute.api_gateway_url}/upload"
    bucket          = module.storage.bucket_name
    main_queue      = module.storage.sqs_queue_url
  }
}
