# ─────────────────────────────────────────────
# MODULE: networking
# VPC, subredes públicas/privadas, IGW, NAT GWs,
# tablas de rutas y VPC Endpoints.
# ─────────────────────────────────────────────

# ── VPC ───────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

# ── Internet Gateway ──────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ── Subredes Públicas ─────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public-${var.availability_zones[count.index]}" }
}

# ── Subredes Privadas ─────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.name_prefix}-private-${var.availability_zones[count.index]}" }
}

# ── Elastic IPs para NAT ──────────────────────
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = { Name = "${var.name_prefix}-eip-nat-${count.index}" }
}

# ── NAT Gateways (uno por AZ — alta disponibilidad) ──
resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${var.name_prefix}-nat-${var.availability_zones[count.index]}" }
  depends_on = [aws_internet_gateway.igw]
}

# ── Tabla de rutas pública ────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.name_prefix}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Tablas de rutas privadas (una por AZ → su NAT) ──
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = { Name = "${var.name_prefix}-rt-private-${var.availability_zones[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ── Security Group: VPC Endpoint SQS ─────────
resource "aws_security_group" "vpce_sqs" {
  name        = "${var.name_prefix}-sg-vpce-sqs"
  description = "Permite TCP 443 desde las Lambdas hacia el VPC Endpoint de SQS."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde upload-lambda"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.upload_lambda.id,
      aws_security_group.crop_lambda.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-vpce-sqs" }
}

# ── Security Group: upload-lambda ────────────
resource "aws_security_group" "upload_lambda" {
  name        = "${var.name_prefix}-sg-upload-lambda"
  description = "SG de upload-lambda: sin inbound, outbound HTTPS al VPC Endpoint."
  vpc_id      = aws_vpc.main.id

  # Sin reglas de entrada (Lambda no recibe conexiones directas)
  egress {
    description = "HTTPS a S3 Gateway Endpoint y SQS Interface Endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-upload-lambda" }
}

# ── Security Group: crop-lambda ───────────────
resource "aws_security_group" "crop_lambda" {
  name        = "${var.name_prefix}-sg-crop-lambda"
  description = "SG de crop-lambda: sin inbound, outbound HTTPS al VPC Endpoint."
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS a S3 y SQS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-crop-lambda" }
}

# ── VPC Endpoint: S3 Gateway (sin costo, sin ENI) ──
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "*"
    }]
  })

  tags = { Name = "${var.name_prefix}-vpce-s3" }
}

# ── VPC Endpoint: SQS Interface (ENI por AZ) ──
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sqs.id]
  private_dns_enabled = true

  tags = { Name = "${var.name_prefix}-vpce-sqs" }
}

data "aws_region" "current" {}
