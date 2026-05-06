# AWS + Lambda Integration

## Arquitectura

- API Gateway HTTP v2
- AWS Lambda (Node.js 20.x) — upload-lambda y crop-lambda
- Amazon SQS (cola principal + Dead-Letter Queue)
- Amazon S3
- VPC con subredes públicas y privadas (multi-AZ)
- NAT Gateway
- VPC Endpoints (S3 Gateway + SQS Interface)
- IAM Roles con mínimo privilegio
- CloudWatch + SNS

## Prerrequisitos

- Terraform >= 1.6
- AWS CLI v2 configurado (`aws configure`)

## Despliegue

**DEV**
```
terraform init
terraform workspace new dev
terraform apply -var-file="envs/dev/terraform.tfvars"
```

**QA**
```
terraform workspace new qa
terraform apply -var-file="envs/qa/terraform.tfvars"
```

**PROD**
```
terraform workspace new prod
terraform apply -var-file="envs/prod/terraform.tfvars"
```

## Pruebas

Al terminar el `apply`, copiar el valor de `api_endpoint_url` del output y ejecutar:

```
export API_URL=$(terraform output -raw api_endpoint_url)
curl -X POST "$API_URL" -H "Content-Type: application/json" -d '{"test": "ok"}' -v
```

Respuesta esperada: HTTP 200.

## Limpieza

```
terraform destroy -var-file="envs/dev/terraform.tfvars"
```

Reemplazar el `var-file` según el entorno a destruir. Las evidencias del despliegue y destrucción se adjuntan en el informe PDF.
