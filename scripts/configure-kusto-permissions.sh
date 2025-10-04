#!/bin/bash

# Script to configure Kusto permissions for the managed identity
# Run this after deploying the infrastructure

set -e

# Configuration - Update these values
KUSTO_CLUSTER_NAME="your-kusto-cluster"
KUSTO_DATABASE="SubscriptionDB"
RESOURCE_GROUP_NAME="your-resource-group"
APP_SERVICE_NAME="your-app-service-name"

echo "Configuring Kusto permissions for managed identity..."

# Get the managed identity principal ID
PRINCIPAL_ID=$(az webapp identity show \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --query principalId -o tsv)

if [ -z "$PRINCIPAL_ID" ]; then
    echo "Error: Could not retrieve managed identity principal ID"
    exit 1
fi

echo "Managed Identity Principal ID: $PRINCIPAL_ID"

# Grant database user permissions
# Note: This requires Kusto CLI or REST API calls
echo "
To complete the setup, run these commands in your Kusto cluster:

1. Connect to your Kusto cluster: https://$KUSTO_CLUSTER_NAME.kusto.windows.net

2. Run this KQL command to add the managed identity as a database user:
   .add database $KUSTO_DATABASE users ('aadapp=$PRINCIPAL_ID') 'Stratos App Managed Identity'

3. Grant viewer permissions:
   .add database $KUSTO_DATABASE viewers ('aadapp=$PRINCIPAL_ID') 'Stratos App Managed Identity'

Alternatively, you can use the Azure CLI with the Kusto extension:
az kusto database-principal-assignment create \\
    --cluster-name $KUSTO_CLUSTER_NAME \\
    --database-name $KUSTO_DATABASE \\
    --resource-group $RESOURCE_GROUP_NAME \\
    --principal-assignment-name stratos-app-permissions \\
    --principal-id $PRINCIPAL_ID \\
    --principal-type App \\
    --role Viewer
"

echo "Configuration script completed!"