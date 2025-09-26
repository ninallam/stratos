#!/bin/bash

# Stratos Deployment Script
# This script helps deploy the Stratos application to Azure using azd

set -e

echo "🚀 Stratos Azure Deployment Script"
echo "=================================="

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI (azd) is not installed."
    echo "Please install it from: https://aka.ms/azd-install"
    exit 1
fi

# Check if user is logged in to Azure
if ! azd auth show &> /dev/null; then
    echo "🔑 Logging in to Azure..."
    azd auth login
fi

# Display current configuration
echo ""
echo "📋 Current Configuration:"
echo "KUSTO_CLUSTER: ${KUSTO_CLUSTER:-'Not set (will use demo mode)'}"
echo "KUSTO_DATABASE: ${KUSTO_DATABASE:-'SubscriptionDB'}"
echo "LOGIC_APP_URL: ${LOGIC_APP_URL:-'Not set (will use demo mode)'}"
echo ""

# Ask user if they want to continue
read -p "Do you want to continue with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Set default values if not provided
export KUSTO_DATABASE="${KUSTO_DATABASE:-SubscriptionDB}"

echo ""
echo "🏗️  Starting deployment..."

# Run azd up
if azd up; then
    echo ""
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "📊 Getting deployment information..."
    azd show
    echo ""
    echo "🌐 Your application is now running on Azure!"
    echo "Use 'azd show' to get the application URL and other details."
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Check the error messages above and try running 'azd up' again."
    echo "For more details, use 'azd show --verbose'"
    exit 1
fi