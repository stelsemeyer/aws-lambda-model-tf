import json
import os

from model import ModelWrapper


BUCKET_NAME = os.environ["BUCKET_NAME"]

# load outside of handler for warm start
model_wrapper = ModelWrapper(bucket_name=BUCKET_NAME)
model_wrapper.load_model()


def handler(event, context):
    print("Event received:", event)

    data = event["body"]
    if isinstance(data, str):
        data = json.loads(data)
    print("Data received:", data)

    label, proba = model_wrapper.predict(data=data)

    body = {
        "prediction": {
            "label": label,
            "probability": round(proba, 4),
        },
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(body),
        "isBase64Encoded": False,
        # additional headers can be passed here..
    }
    return response
