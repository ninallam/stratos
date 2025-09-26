#!/bin/bash

# Azure App Service startup script for Python Flask app
echo "Starting Stratos application..."

# Install dependencies if not already done
pip install -r requirements.txt

# Start the Flask application with Gunicorn
echo "Starting Flask app with Gunicorn..."
gunicorn --bind=0.0.0.0:8000 --timeout 600 --access-logfile \
    '-' --error-logfile '-' app:app