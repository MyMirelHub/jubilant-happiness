FROM python:3.9-slim-buster

WORKDIR /app

# Create non-root user and give ownership of /app
RUN useradd -m -r user && \
    chown user /app

# Copy dependencies to the working directory
COPY ./requirements.txt ./setup.py ./

# Install dependencies
RUN pip install --upgrade pip \
    && pip install -r requirements.txt
# Copy app and test code
COPY ./hello /app/hello
COPY ./tests /app/tests

# Initialise app
RUN python setup.py install

USER user
ENV FLASK_APP=./hello

ENTRYPOINT [ "flask", "run" ]