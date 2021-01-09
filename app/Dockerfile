FROM public.ecr.aws/lambda/python:3.8

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py utils.py model.py train.py predict.py ./

CMD ["app.handler"]
