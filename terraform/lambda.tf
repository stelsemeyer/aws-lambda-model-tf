resource "aws_lambda_function" "lambda_model_function" {
  function_name = local.lambda_function_name

  role = aws_iam_role.lambda_model_role.arn

  # tag is required, "source image ... is not valid" error will pop up
  image_uri    = "${aws_ecr_repository.lambda_model_repository.repository_url}:${local.image_version}"
  package_type = "Image"

  # we can check the memory usage in the lambda dashboard, sklearn is a bit memory hungry..
  memory_size = 512

  environment {
    variables = {
      BUCKET_NAME = local.bucket_name
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_model_policy_attachement" {
  role       = aws_iam_role.lambda_model_role.name
  policy_arn = aws_iam_policy.lambda_model_policy.arn
}

resource "aws_iam_policy" "lambda_model_policy" {
  name = "my-lambda-model-policy"

  policy = <<EOF
{
   	"Version": "2012-10-17",
   	"Statement": [{
   			"Effect": "Allow",
   			"Action": [
   				"logs:*"
   			],
   			"Resource": "arn:aws:logs:*:*:*"
   		},
   		{
   			"Effect": "Allow",
   			"Action": [
   				"s3:*"
   			],
   			"Resource": "arn:aws:s3:::${local.bucket_name}/*"
   		}
   	]
}
EOF
}