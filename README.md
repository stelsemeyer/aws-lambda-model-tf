# Serverless & containerized ML model using AWS Lambda, API Gateway and Terraform

![Lambda model](lambda-model.png)

### Goal:

Have an endpoint which can serve model predictions:

```
$ curl \
$  -X POST \
$  --header "Content-Type: application/json" \
$  --data '{"sepal_length": 5.9, "sepal_width": 3, "petal_length": 5.1, "petal_width": 1.8}' \
$  https://my-endpoint-id.execute-api.eu-central-1.amazonaws.com/predict/
{"prediction": {"label": "virginica", "probability": 0.9997}}
```

### Prerequisities
Running on 

- Terraform v0.14.0
- aws-cli/1.18.206 Python/3.7.9 Darwin/19.6.0 botocore/1.19.46


## Authentication:
We need authenticate to AWS to:

- set up the infrastructure using Terraform
- train the model and store the resulting model artifact in S3
- test the infrastructure using the AWS CLI

The AWS credentials are set up within the [credentials file](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
`~/.aws/credentials`, using a profile named `lambda-model`:

```
[lambda-model]
aws_access_key_id=...
aws_secret_access_key=...
region=eu-central-1
```

The lambda function itself will authenticate using a role, and therefore no explicit credentials are needed.

Moreover we need to define the region and bucket name to interact with the AWS CLI.
Same variables are also defined within the [Terraform variables](./terraform/variables.tf).

```
export AWS_REGION=$(aws --profile lambda-model configure get region)
export BUCKET_NAME=my-lambda-model-bucket
export LAMBDA_FUNCTION_NAME=my-lambda-model-function
export API_NAME=my-lambda-model-api
export IMAGE_NAME=my-lambda-model
export IMAGE_TAG=latest
```

### Create ECR and S3 resources
Create docker image repository (for model code and lambda handler)
and S3 bucket (to store model artifact):

```
(cd terraform &&  \
  terraform apply \
  -target=aws_ecr_repository.lambda_model_repository \
  -target=aws_s3_bucket.lambda_model_bucket)
```

### Build and push docker image
Build docker image with model, including

- model and model utils (`model.py, utils.py`)
- lambda handler (`app.py`)
- scripts for training and offline prediction (`train.py, predict.py`)

We define more environment variables to communicate with ECR:

```
export REGISTRY_ID=$(aws ecr \
  --profile lambda-model \
  describe-repositories \
  --query 'repositories[?repositoryName == `'$IMAGE_NAME'`].registryId' \
  --output text)
export IMAGE_URI=${REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}
```

Log in to ECR:

```
$(aws --profile lambda-model \
  ecr get-login \
  --region $AWS_REGION \
  --registry-ids $REGISTRY_ID \
  --no-include-email)
```

Build and push image from `app` directory:

```
(cd app && \
  docker build -t $IMAGE_URI . && \
  docker push $IMAGE_URI:$IMAGE_TAG)
```

### Train model
Training the model to store artifact in s3, 
using our profile to authenticate to S3:

```
docker run \
  -v ~/.aws:/root/.aws \
  -e AWS_PROFILE=lambda-model \
  -e BUCKET_NAME=$BUCKET_NAME \
  --entrypoint=python \
  $IMAGE_URI:$IMAGE_TAG \
  train.py
```

```
# Loading data.
# Creating model.
# Fitting model with 150 datapoints.
# Saving model.
```

### Test model 
Running prediction for two different payloads:

```
docker run \
  -v ~/.aws:/root/.aws \
  -e AWS_PROFILE=lambda-model \
  -e BUCKET_NAME=$BUCKET_NAME \
  --entrypoint=python \
  $IMAGE_URI:$IMAGE_TAG \
  predict.py \
  '{"sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2}'
```

```
# Loading model.
# Data: {'sepal_length': 5.1, 'sepal_width': 3.5, 'petal_length': 1.4, 'petal_width': 0.2}
# Prediction: ('setosa', 0.9999555689374946)
```

We can also have missing values, since we used the `SimpleImputer` in our model pipeline:

```
docker run \
  -v ~/.aws:/root/.aws \
  -e AWS_PROFILE=lambda-model \
  -e BUCKET_NAME=$BUCKET_NAME \
  --entrypoint=python \
  $IMAGE_URI:$IMAGE_TAG \
  predict.py \
  '{"sepal_length": 5.4, "sepal_width": 3, "petal_length": null, "petal_width": 0.2}'
```

```
# Loading model.
# Data: {'sepal_length': 5.4, 'sepal_width': 3, 'petal_length': None, 'petal_width': 0.2}
# Prediction: ('versicolor', 0.6082744786165051)
```

### Plan and create lambda and API

```
(cd terraform && terraform apply)
```

### Test lambda function
Invoking the lambda with a sample request like above:

```
aws --profile lambda-model \
  lambda \
  invoke \
  --function-name $LAMBDA_FUNCTION_NAME \
  --payload '{"body": {"sepal_length": 5.9, "sepal_width": 3, "petal_length": 5.1, "petal_width": 1.8}}' \
  response.json
```

This should return something like 

```
# {
#     "StatusCode": 200,
#     "ExecutedVersion": "$LATEST"
# }
```
and also a response in `response.json`:

```
cat response.json
# {"statusCode": 200, "body": "{\"prediction\": {\"label\": \"virginica\", \"probability\": 0.9997}}", "isBase64Encoded": false}%
```

### Test Rest API
Construct endpoint URL from endpoint ID, 
which has the [format](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-call-api.html#apigateway-how-to-call-rest-api)
`https://{restapi_id}.execute-api.{region}.amazonaws.com/{stage_name}/`
where we defined `stage_name` as `predict` in the Terraform locals.

```
export ENDPOINT_ID=$(aws \
  --profile lambda-model \
  apigateway \
  get-rest-apis \
  --query 'items[?name == `'$API_NAME'`].id' \
  --output text)

export ENDPOINT_URL=https://${ENDPOINT_ID}.execute-api.${AWS_REGION}.amazonaws.com/predict
```

Sending a sample POST request to the API:

```
curl \
  -X POST \
  --header "Content-Type: application/json" \
  --data '{"sepal_length": 5.9, "sepal_width": 3, "petal_length": 5.1, "petal_width": 1.8}' \
  $ENDPOINT_URL
```

This should return something like

```
# {"prediction": {"label": "virginica", "probability": 0.9997}}
```

Alternatively via python:

```
import requests
import os

endpoint_url = os.environ['ENDPOINT_URL']
data = {"sepal_length": 5.9, "sepal_width": 3, "petal_length": 5.1, "petal_width": 1.8}

req = requests.post(endpoint_url, json=data)
req.json()
```
 
### Update lambda with latest container image
To update the lambda with the latest container 
image we can use the AWS CLI:

```
aws --profile lambda-model \
  lambda \
  update-function-code \
  --function-name $LAMBDA_FUNCTION_NAME \
  --image-uri $IMAGE_URI:$IMAGE_TAG
```

### Clean up
Deletes(!) S3 bucket content and destroys(!) resources:

```
# aws s3 --profile lambda-model rm s3://${BUCKET_NAME}/model.pkl
# (cd terraform && terraform destroy)
```
