output "vpc_id"              { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "upload_lambda_sg_id" { value = aws_security_group.upload_lambda.id }
output "crop_lambda_sg_id"   { value = aws_security_group.crop_lambda.id }
output "vpce_sqs_sg_id"      { value = aws_security_group.vpce_sqs.id }
