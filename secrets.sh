#!/bin/bash

# List of required environment variables
REQUIRED_VARS=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "RDS_PASSWORD" "APP_ENV")

missing=0

echo " Validating required environment variables..."

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Missing required secret: $var"
    missing=1
  else
    echo "$var is set"
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "❗ One or more required secrets are missing. Exiting."
  exit 1
fi

echo "All required secrets are present."
