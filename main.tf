# ─────────────────────────────────────────────
# MAIN — image-processor
# Orquesta todos los módulos de la arquitectura.
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── 1. Networking ─────────────────────────────
module "networking" {
  source = "./modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ── 2. IAM Roles ─────────────────────────────
module "iam" {
  source = "./modules/iam"

  name_prefix      = local.name_prefix
  bucket_arn       = module.storage.bucket_arn
  sqs_queue_arn    = module.storage.sqs_queue_arn
  sqs_dlq_arn      = module.storage.sqs_dlq_arn
}

# ── 3. Storage (S3 + SQS) ────────────────────
module "storage" {
  source = "./modules/storage"

  name_prefix              = local.name_prefix
  environment              = var.environment
  uploads_lifecycle_days   = var.uploads_lifecycle_days
  processed_lifecycle_days = var.processed_lifecycle_days
  sqs_visibility_timeout   = var.sqs_visibility_timeout
  sqs_message_retention    = var.sqs_message_retention
  sqs_dlq_retention        = var.sqs_dlq_retention
  sqs_max_receive_count    = var.sqs_max_receive_count
}

# ── 4. Compute (Lambdas + API Gateway) ────────
module "compute" {
  source = "./modules/compute"

  name_prefix            = local.name_prefix
  environment            = var.environment
  aws_region             = var.aws_region

  # Networking
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # IAM
  upload_lambda_role_arn = module.iam.upload_lambda_role_arn
  crop_lambda_role_arn   = module.iam.crop_lambda_role_arn

  # Storage
  bucket_name     = module.storage.bucket_name
  bucket_arn      = module.storage.bucket_arn
  sqs_queue_arn   = module.storage.sqs_queue_arn
  sqs_queue_url   = module.storage.sqs_queue_url

  # Lambda config
  upload_lambda_memory  = var.upload_lambda_memory
  upload_lambda_timeout = var.upload_lambda_timeout
  crop_lambda_memory    = var.crop_lambda_memory
  crop_lambda_timeout   = var.crop_lambda_timeout
  crop_sqs_batch_size   = var.crop_sqs_batch_size

  # API Gateway
  api_throttle_rate  = var.api_throttle_rate
  api_throttle_burst = var.api_throttle_burst

  # Observabilidad
  log_retention_days = var.log_retention_days

  depends_on = [module.networking, module.iam, module.storage]
}

# ── 5. Observabilidad (CloudWatch + SNS) ──────
module "observability" {
  source = "./modules/observability"

  name_prefix        = local.name_prefix
  sqs_dlq_name       = module.storage.sqs_dlq_name
  log_retention_days = var.log_retention_days
  sns_alarm_email    = var.sns_alarm_email

  upload_lambda_name = module.compute.upload_lambda_name
  crop_lambda_name   = module.compute.crop_lambda_name
  api_gateway_id     = module.compute.api_gateway_id

  depends_on = [module.storage, module.compute]
}
