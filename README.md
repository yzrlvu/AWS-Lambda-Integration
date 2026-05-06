# 🖼️ Image Processor — Infraestructura como Código (AWS + Terraform)

> Arquitectura serverless de procesamiento de imágenes desplegada en AWS con soporte para entornos DEV, QA y PROD.

---

## 📐 Descripción de la Arquitectura

Este proyecto implementa un **pipeline serverless de procesamiento de imágenes** en AWS, estructurado en tres capas:

### Flujo principal

```
Cliente → API Gateway HTTP v2 → upload-lambda → S3 (uploads/)
                                                      ↓
                                             S3 Event Notification
                                                      ↓
                                                 SQS Main Queue
                                                      ↓
                                              crop-lambda (ESM)
                                                      ↓
                                           S3 (processed/) → PNG 40×40
```

### Componentes clave

| Capa | Servicio | Descripción |
|------|----------|-------------|
| **Entrada** | API Gateway HTTP v2 | `POST /upload` — TLS 1.2+, CORS habilitado, Payload 2.0 |
| **Cómputo** | Lambda `upload-lambda` | Node.js 20.x · 256 MB · 30 s — Recibe imagen, la sube a S3 |
| **Cómputo** | Lambda `crop-lambda` | Node.js 20.x · 512 MB · 60 s — Recorta a 40×40 PNG circular |
| **Mensajería** | SQS Standard Queue | Desacopla upload y crop; visibility timeout = 6× timeout Lambda |
| **Mensajería** | SQS Dead-Letter Queue | Captura mensajes fallidos tras 3 intentos |
| **Persistencia** | S3 Bucket | `uploads/` (expiración 30 d) + `processed/` (expiración 90 d) |
| **Red** | VPC 10.0.0.0/16 | 2 AZs · subredes públicas (NAT GW) + privadas (Lambdas) |
| **Seguridad** | IAM Least-Privilege | Roles separados con permisos mínimos por Lambda |
| **Endpoints** | VPC Gateway (S3) + Interface (SQS) | Tráfico nunca sale a internet público |
| **Observabilidad** | CloudWatch + SNS | Logs 14 días, Alarm en DLQ, Dashboard de métricas |

### Decisiones de diseño

- **Serverless puro**: sin servidores que gestionar, escala automáticamente a cero.
- **Alta disponibilidad**: Lambdas distribuidas en 2 AZs; NAT Gateway por AZ.
- **Seguridad en profundidad**: Lambdas en subredes privadas, S3 completamente privado, SGs restrictivos.
- **Desacoplamiento**: SQS garantiza que un fallo en crop no afecte la recepción de uploads.

---

## ✅ Prerrequisitos

### Software requerido

| Herramienta | Versión mínima | Instalación |
|-------------|---------------|-------------|
| Terraform | ≥ 1.6.0 | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI | ≥ 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Node.js | ≥ 20.x (para desarrollo local de Lambdas) | [nodejs.org](https://nodejs.org) |

### Verificar instalaciones

```bash
terraform version
aws --version
node --version
```

### Configurar AWS CLI

```bash
# Opción 1: Credenciales con perfil nombrado (recomendado)
aws configure --profile image-processor-dev
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: us-east-1
# Default output format: json

# Opción 2: Variables de entorno (útil en CI/CD)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

# Verificar que las credenciales funcionan
aws sts get-caller-identity
```

### Permisos IAM requeridos

La cuenta/usuario de AWS debe tener permisos para crear: VPC, Subredes, IGW, NAT Gateway, Elastic IP, Lambda, API Gateway, S3, SQS, IAM Roles/Policies, CloudWatch, SNS.

> 💡 Para el laboratorio universitario es aceptable usar `AdministratorAccess`. En producción real, usar permisos mínimos.

---

## 🗂️ Estructura del Proyecto

```
terraform-image-processor/
├── main.tf                    # Módulo raíz — orquesta todos los módulos
├── providers.tf               # Provider AWS, versiones requeridas
├── variables.tf               # Todas las variables del proyecto
├── outputs.tf                 # Outputs: URL del API, ARNs, etc.
│
├── modules/
│   ├── networking/            # VPC, subredes, IGW, NAT, SGs, VPC Endpoints
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/                   # Roles y políticas de mínimo privilegio
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/               # S3 Bucket + SQS (main + DLQ) + notificaciones
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/               # Lambdas + API Gateway + ESM
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── observability/         # CloudWatch Alarms, SNS, Dashboard
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── envs/
    ├── dev/terraform.tfvars   # Variables específicas de DEV
    ├── qa/terraform.tfvars    # Variables específicas de QA
    └── prod/terraform.tfvars  # Variables específicas de PROD
```

---

## 🚀 Despliegue por Entorno

> **Nota**: Todos los comandos se ejecutan desde el **directorio raíz** del proyecto (`terraform-image-processor/`).

---

### 🟢 Entorno DEV

```bash
# 1. Inicializar Terraform (descarga providers y módulos)
terraform init

# 2. Planificar — muestra qué recursos se crearán sin aplicar cambios
terraform plan -var-file="envs/dev/terraform.tfvars"

# 3. Aplicar — crea la infraestructura en AWS
#    Escribe 'yes' cuando se solicite confirmación
terraform apply -var-file="envs/dev/terraform.tfvars"

# 4. Ver los outputs (incluye el URL del API)
terraform output
terraform output api_endpoint_url
```

**Resultado esperado en consola:**
```
api_endpoint_url = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/upload"
s3_bucket_name   = "image-processor-dev-images-a1b2c3d4"
...
```

---

### 🟡 Entorno QA

> ⚠️ Terraform mantiene un `tfstate` por directorio de trabajo. Para QA se recomienda un workspace diferente o un backend remoto configurado por entorno. En este laboratorio, usamos `-var-file` + workspaces locales.

```bash
# Crear y seleccionar workspace de QA
terraform workspace new qa
terraform workspace select qa

# Inicializar (si es la primera vez en este workspace)
terraform init

# Planificar para QA
terraform plan -var-file="envs/qa/terraform.tfvars"

# Aplicar para QA
terraform apply -var-file="envs/qa/terraform.tfvars"

# Ver outputs de QA
terraform output api_endpoint_url
```

---

### 🔴 Entorno PROD

```bash
# Crear y seleccionar workspace de PROD
terraform workspace new prod
terraform workspace select prod

terraform init

# SIEMPRE hacer plan antes de apply en PROD
terraform plan -var-file="envs/prod/terraform.tfvars" -out=tfplan-prod.tfplan

# Revisar el plan cuidadosamente, luego aplicar
terraform apply tfplan-prod.tfplan
```

---

## 🧪 Cómo Probar que el Entorno Funciona

### 1. Obtener el URL de salida

```bash
export API_URL=$(terraform output -raw api_endpoint_url)
echo "API URL: $API_URL"
```

### 2. Test con imagen real (multipart/form-data)

```bash
# Descarga una imagen de prueba
curl -o test.jpg https://picsum.photos/200

# Envía la imagen al endpoint
curl -X POST "$API_URL" \
  -F "image=@test.jpg" \
  -H "Content-Type: multipart/form-data" \
  -v
```

**Respuesta esperada (HTTP 200):**
```json
{
  "message": "Image uploaded successfully",
  "key": "uploads/uuid-filename.jpg"
}
```

### 3. Test con JSON + base64

```bash
# Convertir imagen a base64
BASE64_IMG=$(base64 -i test.jpg)

# Enviar como JSON
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"image\": \"$BASE64_IMG\", \"filename\": \"test.jpg\"}" \
  -v
```

### 4. Verificar que la imagen se procesó en S3

```bash
# Obtener nombre del bucket
BUCKET=$(terraform output -raw s3_bucket_name)

# Listar uploads originales
aws s3 ls "s3://$BUCKET/uploads/"

# Listar imágenes procesadas (40×40 PNG)
aws s3 ls "s3://$BUCKET/processed/"
```

### 5. Verificar logs en CloudWatch

```bash
# Ver logs de upload-lambda
aws logs tail /aws/lambda/image-processor-dev-upload --follow

# Ver logs de crop-lambda
aws logs tail /aws/lambda/image-processor-dev-crop --follow
```

---

## 🗑️ Destruir la Infraestructura

> ⚠️ Este comando **elimina TODOS los recursos** del entorno seleccionado. En DEV/QA es seguro; en PROD verificar dos veces.

```bash
# Asegúrate de estar en el workspace correcto
terraform workspace show

# Previsualizar qué se destruirá
terraform plan -destroy -var-file="envs/dev/terraform.tfvars"

# Destruir (escribe 'yes' para confirmar)
terraform destroy -var-file="envs/dev/terraform.tfvars"
```

**Para destruir QA:**
```bash
terraform workspace select qa
terraform destroy -var-file="envs/qa/terraform.tfvars"
```

**Para destruir PROD:**
```bash
terraform workspace select prod
terraform destroy -var-file="envs/prod/terraform.tfvars"
```

---

## 📊 Diferencias entre Entornos

| Parámetro | DEV | QA | PROD |
|-----------|-----|-----|------|
| upload-lambda memoria | 128 MB | 256 MB | 256 MB |
| crop-lambda memoria | 256 MB | 512 MB | 512 MB |
| API throttle rate | 100 rps | 1,000 rps | 10,000 rps |
| Lifecycle uploads/ | 7 días | 15 días | 30 días |
| Lifecycle processed/ | 14 días | 30 días | 90 días |
| Log retention | 7 días | 14 días | 30 días |
| DLQ retention | 7 días | 14 días | 14 días |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |

---

## 🔧 Comandos Útiles

```bash
# Ver el estado actual de Terraform
terraform state list

# Inspeccionar un recurso específico
terraform state show module.networking.aws_vpc.main

# Formatear el código HCL
terraform fmt -recursive

# Validar la sintaxis
terraform validate

# Ver todos los workspaces
terraform workspace list

# Refrescar el estado sin aplicar cambios
terraform refresh -var-file="envs/dev/terraform.tfvars"
```

---

## 🛠️ Troubleshooting

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `Error: No valid credential sources found` | AWS CLI no configurado | Ejecutar `aws configure` |
| `Error: Error creating VPC: VpcLimitExceeded` | Límite de 5 VPCs por región | Eliminar VPCs no usados o solicitar aumento de cuota |
| `Error: InvalidParameterException` en Lambda | ZIP placeholder vacío | Verificar que el `data.archive_file` generó el ZIP |
| `Error acquiring state lock` | Otro proceso usa el estado | Esperar o ejecutar `terraform force-unlock <ID>` |
| Timeout en `terraform apply` | NAT Gateway tarda ~3 min | Es normal, esperar |

---

## 📝 Notas Académicas

- Los Lambdas se despliegan con un **código placeholder** funcional. En un proyecto real, el código Node.js con `sharp`, `busboy`, etc., se empaqueta y sube antes del `terraform apply`.
- El **backend de estado** está configurado localmente (`terraform.tfstate`). Para trabajo en equipo, descomentar el bloque `backend "s3"` en `providers.tf`.
- Los **NAT Gateways** tienen costo por hora y por GB transferido. Destruir los entornos cuando no se usen para evitar cargos en la cuenta universitaria.
