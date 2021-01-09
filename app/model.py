import os
from typing import Tuple
from sklearn.impute import SimpleImputer
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.pipeline import Pipeline

from utils import save_object, load_object, load_data


BUCKET_NAME = os.environ["BUCKET_NAME"]

MODEL_KEY = "model.pkl"
LOCAL_FILE_PATH = os.path.join("/tmp/", MODEL_KEY)  # lambda writeable path
DATA_URL = "https://forge.scilab.org/index.php/p/rdataset/source/file/master/csv/datasets/iris.csv"
FEATURE_COLS = ["sepal_length", "sepal_width", "petal_length", "petal_width"]
TARGET_COL = "species"


def create_model():
    """Create simple model pipeline with imputation step and gradient boosting classifier."""
    pipeline = Pipeline(steps=[
        ("simple_imputer", SimpleImputer()),
        ("model", GradientBoostingClassifier()),
    ])
    return pipeline


class ModelWrapper:
    def __init__(self, bucket_name: str = BUCKET_NAME):
        self.model = None
        self.bucket_name = bucket_name

    def train(self, url: str = DATA_URL):
        """Train model on supplied data and save model artifact to S3."""
        print("Loading data.")
        x, y = load_data(url=url, feature_cols=FEATURE_COLS, target_col=TARGET_COL)

        print("Creating model.")
        self.model = create_model()

        print(f"Fitting model with {len(x)} datapoints.")
        self.model.fit(x, y)
        self.save_model()
        return

    def predict(self, data: dict) -> Tuple[str, float]:
        """Compute predicted label and probability for provided data."""
        if self.model is None:
            self.load_model()

        # sort cols and put into array
        x = [[data[feature] for feature in FEATURE_COLS]]

        label = self.model.predict(x)[0]

        # extract probabilities
        classes = self.model.named_steps['model'].classes_
        probas = dict(zip(classes, self.model.predict_proba(x)[0]))
        proba = probas[label]

        return label, proba

    def load_model(self):
        """Load model artifact from S3."""
        print("Loading model.")
        self.model = load_object(self.bucket_name, MODEL_KEY, LOCAL_FILE_PATH)
        return

    def save_model(self):
        """Save model artifact to S3."""
        print("Saving model.")
        save_object(self.model, self.bucket_name, MODEL_KEY, LOCAL_FILE_PATH)
        return
