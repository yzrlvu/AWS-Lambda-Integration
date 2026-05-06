variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto. Se usa como prefijo en todos los recursos."
  type        = string
  default     = "image-processor"
}

variable "environment" {
  description = "Entorno de despliegue: dev | qa | prod."
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El entorno debe ser 'dev', 'qa' o 'prod'."
  }
}

variable "vpc_cidr" {
  description = "CIDR block del VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDRs para subredes públicas (una por AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDRs para subredes privadas (una por AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs a usar (debe coincidir con la cantidad de subredes)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "upload_lambda_memory" {
  description = "Memoria en MB para upload-lambda."
  type        = number
  default     = 256
}

variable "upload_lambda_timeout" {
  description = "Timeout en segundos para upload-lambda."
  type        = number
  default     = 30
}

variable "crop_lambda_memory" {
  description = "Memoria en MB para crop-lambda."
  type        = number
  default     = 512
}

variable "crop_lambda_timeout" {
  description = "Timeout en segundos para crop-lambda."
  type        = number
  default     = 60
}

variable "crop_sqs_batch_size" {
  description = "Tamaño de batch para el Event Source Mapping de crop-lambda."
  type        = number
  default     = 5
}

variable "sqs_visibility_timeout" {
  description = "Visibility timeout en segundos para la cola principal (debe ser 6x el timeout de crop-lambda)."
  type        = number
  default     = 360
}

variable "sqs_message_retention" {
  description = "Retención de mensajes en la cola principal (segundos)."
  type        = number
  default     = 86400 # 1 día
}

variable "sqs_dlq_retention" {
  description = "Retención de mensajes en la DLQ (segundos)."
  type        = number
  default     = 1209600 # 14 días
}

variable "sqs_max_receive_count" {
  description = "Número máximo de recepciones antes de enviar a DLQ."
  type        = number
  default     = 3
}

variable "uploads_lifecycle_days" {
  description = "Días hasta que expiran los objetos en el prefijo uploads/."
  type        = number
  default     = 30
}

variable "processed_lifecycle_days" {
  description = "Días hasta que expiran los objetos en el prefijo processed/."
  type        = number
  default     = 90
}

variable "api_throttle_rate" {
  description = "Rate limit en requests por segundo para API Gateway."
  type        = number
  default     = 10000
}

variable "api_throttle_burst" {
  description = "Burst limit para API Gateway."
  type        = number
  default     = 5000
}

variable "log_retention_days" {
  description = "Retención de logs de CloudWatch en días."
  type        = number
  default     = 14
}

variable "sns_alarm_email" {
  description = "Email para recibir alertas del CloudWatch Alarm (DLQ)."
  type        = string
  default     = "alerts@example.com"
}
