resource "aws_api_gateway_rest_api" "lambda_model_api" {
  name        = local.api_name
}

resource "aws_api_gateway_resource" "lambda_model_gateway" {
   rest_api_id = aws_api_gateway_rest_api.lambda_model_api.id
   parent_id   = aws_api_gateway_rest_api.lambda_model_api.root_resource_id
   path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "lambda_model_proxy" {
   rest_api_id   = aws_api_gateway_rest_api.lambda_model_api.id
   resource_id   = aws_api_gateway_resource.lambda_model_gateway.id
   http_method   = "POST"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_model_integration" {
   rest_api_id = aws_api_gateway_rest_api.lambda_model_api.id
   resource_id = aws_api_gateway_method.lambda_model_proxy.resource_id
   http_method = aws_api_gateway_method.lambda_model_proxy.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.lambda_model_function.invoke_arn
}

resource "aws_api_gateway_method" "lambda_model_method" {
   rest_api_id   = aws_api_gateway_rest_api.lambda_model_api.id
   resource_id   = aws_api_gateway_rest_api.lambda_model_api.root_resource_id
   http_method   = "POST"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = aws_api_gateway_rest_api.lambda_model_api.id
   resource_id = aws_api_gateway_method.lambda_model_method.resource_id
   http_method = aws_api_gateway_method.lambda_model_method.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.lambda_model_function.invoke_arn
}

resource "aws_api_gateway_deployment" "lambda_model_deployment" {
   depends_on = [
     aws_api_gateway_integration.lambda_model_integration,
     aws_api_gateway_integration.lambda_root,
   ]

   rest_api_id = aws_api_gateway_rest_api.lambda_model_api.id
   stage_name  = local.api_path

   # added to stream changes
   stage_description = "deployed at ${timestamp()}"

   lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "lambda_model_permission" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.lambda_model_function.function_name
   principal     = "apigateway.amazonaws.com"

   # The "/*/*" portion grants access from any method on any resource
   # within the API Gateway REST API.
   source_arn = "${aws_api_gateway_rest_api.lambda_model_api.execution_arn}/*/*"
}

output "endpoint_url" {
  value = aws_api_gateway_deployment.lambda_model_deployment.invoke_url
}
