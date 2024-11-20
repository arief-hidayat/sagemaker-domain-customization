#!/bin/bash

# Get the requirements.txt S3 location from the first argument
REQUIREMENTS_S3_LOCATION=$1

# Exit on any error
set -e

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Main execution
log_message "Bootstrap action started"

# Create a directory for our requirements file
sudo mkdir -p /opt/python_deps
cd /opt/python_deps

# Download requirements.txt from S3
log_message "Downloading requirements.txt from $REQUIREMENTS_S3_LOCATION"
sudo aws s3 cp "$REQUIREMENTS_S3_LOCATION" ./requirements.txt

# Install requirements
log_message "Installing Python packages from requirements.txt"
sudo python3 -m pip install -r requirements.txt

# Verify Python packages are installed
log_message "Verifying installations"
python3 -m pip list

log_message "Bootstrap action completed"
