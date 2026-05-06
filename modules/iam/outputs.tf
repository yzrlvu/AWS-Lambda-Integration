output "upload_lambda_role_arn"  { value = aws_iam_role.upload_lambda.arn }
output "upload_lambda_role_name" { value = aws_iam_role.upload_lambda.name }
output "crop_lambda_role_arn"    { value = aws_iam_role.crop_lambda.arn }
output "crop_lambda_role_name"   { value = aws_iam_role.crop_lambda.name }
