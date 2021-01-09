variable aws_profile {
  type    = string
  default = "lambda-model"
}

# constant settings
locals {
  image_name           = "my-lambda-model"
  image_version        = "latest"

  bucket_name          = "my-lambda-model-bucket"

  lambda_function_name = "my-lambda-model-function"

  api_name             = "my-lambda-model-api"
  api_path             = "predict"
}
