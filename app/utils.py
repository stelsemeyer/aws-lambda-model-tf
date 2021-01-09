import boto3
import pickle
import pandas as pd
import os

# use aws profile if provided
PROFILE_NAME = os.environ.get("AWS_PROFILE", None)

session = boto3.Session(profile_name=PROFILE_NAME)
s3_client = session.client("s3")


def load_object(bucket_name, key, file):
    """Load object from S3 key (saving in file in between)."""
    s3_client.download_file(bucket_name, key, file)
    with open(file, "rb") as f:
        object = pickle.load(f)
    return object


def save_object(object, bucket_name, key, file):
    """Save object to S3 key (saving in file in between)."""
    with open(file, "wb") as f:
        pickle.dump(object, f)
    s3_client.upload_file(file, bucket_name, key)
    return


def load_data(url, feature_cols, target_col):
    """Load data from URL, splitting it into x and y."""
    data = pd.read_csv(url, sep=",")

    # normalize col names
    data.columns = [col.replace(" ", "_").replace(".", "_").lower() for col in data.columns]

    y = data[target_col]
    x = data[feature_cols]
    return x, y
