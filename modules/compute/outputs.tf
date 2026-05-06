output "api_gateway_url"      { value = aws_apigatewayv2_stage.default.invoke_url }
output "api_gateway_id"       { value = aws_apigatewayv2_api.http.id }
output "upload_lambda_arn"    { value = aws_lambda_function.upload.arn }
output "upload_lambda_name"   { value = aws_lambda_function.upload.function_name }
output "crop_lambda_arn"      { value = aws_lambda_function.crop.arn }
output "crop_lambda_name"     { value = aws_lambda_function.crop.function_name }
