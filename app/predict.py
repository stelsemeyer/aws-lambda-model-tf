import json
import sys

from model import ModelWrapper


model_wrapper = ModelWrapper()
model_wrapper.load_model()

data = json.loads(sys.argv[1])
print(f"Data: {data}")

prediction = model_wrapper.predict(data=data)
print(f"Prediction: {prediction}")
