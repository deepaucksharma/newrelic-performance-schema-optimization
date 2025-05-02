#!/usr/bin/env bash
set -e

# Create build directory
mkdir -p build

# Install dependencies
pip install --upgrade -r requirements.txt --target build

# Copy Lambda function
cp index.py build/

# Create Lambda package
cd build && zip -r ../lambda.zip .

# Create layer package (optional - useful for deployment)
mkdir -p layer/python
pip install --upgrade -r ../requirements.txt --target layer/python
cd layer && zip -r ../pymysql-pyyaml-layer.zip .

echo "lambda.zip and pymysql-pyyaml-layer.zip ready – upload to S3 & reference in IaC"
echo "Usage: aws s3 cp lambda.zip s3://your-bucket/lambda.zip"
echo "       aws s3 cp pymysql-pyyaml-layer.zip s3://your-bucket/pymysql-pyyaml-layer.zip"
