#!/bin/bash

# Stratos Azure Deployment Script
# This script helps deploy Stratos to Azure using Azure Developer CLI

set -e

echo "🚀 Stratos Azure Deployment Script"
echo "=================================="

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI (azd) is not installed."
    echo "Please install it from: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd"
    exit 1
fi

# Check if az is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI (az) is not installed."
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Initialize azd if not already done
if [ ! -f ".azure/config.json" ]; then
    echo "🔧 Initializing Azure Developer CLI..."
    azd init --template .
fi

# Prompt for required parameters
read -p "Enter your Azure environment name (e.g., stratos-dev): " env_name
read -p "Enter Azure location (e.g., eastus): " location
read -p "Enter your existing Kusto cluster name (without .kusto.windows.net): " kusto_cluster
read -p "Enter Kusto database name [SubscriptionDB]: " kusto_db
kusto_db=${kusto_db:-SubscriptionDB}

read -p "Enable demo mode? (true/false) [false]: " demo_mode
demo_mode=${demo_mode:-false}

echo "🔧 Setting environment variables..."
azd env set AZURE_ENV_NAME "$env_name"
azd env set AZURE_LOCATION "$location"
azd env set KUSTO_CLUSTER_NAME "$kusto_cluster"
azd env set KUSTO_DATABASE_NAME "$kusto_db"
azd env set DEMO_MODE "$demo_mode"

echo "🔐 Logging into Azure..."
az login

echo "🚀 Deploying to Azure..."
azd up

echo "✅ Deployment completed!"
echo ""
echo "🔧 Next steps:"
echo "1. Configure the Logic App Office 365 connection in Azure Portal"
echo "2. Grant your App Service managed identity access to the Kusto cluster"
echo "3. Test your application using the provided URL"
echo ""
echo "📋 See DEPLOYMENT.md for detailed post-deployment instructions"