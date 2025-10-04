# Stratos - Azure Deployment Guide

This guide explains how to deploy the Stratos application to Azure using Azure Developer CLI (azd).

## Prerequisites

1. **Azure Developer CLI (azd)**: [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
2. **Azure CLI**: [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **Azure Subscription**: An active Azure subscription with appropriate permissions
4. **Existing Kusto Cluster**: An Azure Data Explorer (Kusto) cluster with the required database

## Deployment Steps

### 1. Initialize the Environment

```bash
# Clone the repository
git clone https://github.com/ninallam/stratos.git
cd stratos

# Initialize azd environment
azd init
```

### 2. Configure Environment Variables

```bash
# Set your Azure environment name (will be used to create unique resource names)
azd env set AZURE_ENV_NAME "stratos-dev"

# Set the Azure location where you want to deploy
azd env set AZURE_LOCATION "eastus"

# Set your existing Kusto cluster name (without .kusto.windows.net suffix)
azd env set KUSTO_CLUSTER_NAME "your-kusto-cluster-name"

# Set your Kusto database name (optional, defaults to SubscriptionDB)
azd env set KUSTO_DATABASE_NAME "SubscriptionDB"

# Set demo mode if you want to run without Kusto dependencies
azd env set DEMO_MODE "false"
```

### 3. Login to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-id"
```

### 4. Deploy the Application

```bash
# Deploy the infrastructure and application
azd up
```

This command will:
- Create a resource group
- Deploy the infrastructure using Bicep templates
- Create an App Service to host the Flask application
- Create a Logic App for sending emails
- Set up Application Insights for monitoring
- Create a Key Vault for secure configuration
- Deploy the application code to App Service

### 5. Configure the Logic App Connection

After deployment, you'll need to authorize the Office 365 connection for the Logic App:

1. Go to the Azure Portal
2. Navigate to your resource group
3. Open the Logic App resource (`logic-{unique-id}`)
4. Go to "API connections" in the left menu
5. Select the "office365" connection
6. Click "Edit API connection"
7. Click "Authorize" and sign in with your Office 365 account
8. Save the connection

### 6. Set Up Kusto Database Permissions

Grant the App Service managed identity access to your Kusto cluster:

```kusto
// In your Kusto cluster, run this command to grant viewer permissions
.add database SubscriptionDB viewers ('aadapp=YOUR_APP_SERVICE_MANAGED_IDENTITY_CLIENT_ID')
```

The managed identity client ID will be displayed in the azd deployment output.

### 7. Verify Deployment

1. Open the deployed application URL (shown in azd output)
2. Check the `/health` endpoint to verify configuration
3. Test the application functionality

## Post-Deployment Configuration

### Environment Variables

The following environment variables are automatically configured:

- `KUSTO_CLUSTER`: Your Kusto cluster URL
- `KUSTO_DATABASE`: Your Kusto database name
- `LOGIC_APP_URL`: The Logic App HTTP trigger URL
- `SECRET_KEY`: Automatically generated secret key
- `FLASK_ENV`: Set to "production"
- `DEMO_MODE`: Set based on your configuration

### Kusto Database Schema

Ensure your Kusto database has the required table:

```kusto
.create table SubscriptionAccountTeams (
    SubscriptionId: string,
    AccountTeamEmail: string,
    AccountTeamName: string
)
```

## Monitoring and Troubleshooting

### Application Insights

Monitor your application using Azure Application Insights:
- View logs and metrics in the Azure Portal
- Set up alerts for errors or performance issues

### App Service Logs

Enable and view App Service logs:
```bash
# Enable logging
az webapp log config --name YOUR_APP_NAME --resource-group YOUR_RG --web-server-logging filesystem

# Stream logs
az webapp log tail --name YOUR_APP_NAME --resource-group YOUR_RG
```

### Common Issues

1. **Logic App Authorization**: Ensure the Office 365 connection is properly authorized
2. **Kusto Permissions**: Verify the managed identity has access to your Kusto cluster
3. **Key Vault Access**: Check that the App Service can access Key Vault secrets

## Cleanup

To remove all deployed resources:

```bash
azd down
```

## Cost Considerations

The deployment creates the following billable resources:
- App Service Plan (B1 tier)
- App Service
- Logic App
- Application Insights
- Key Vault
- Log Analytics Workspace

Consider using smaller tiers for development/testing environments.

### 5. Configure Kusto Permissions (After Deployment)

After successful deployment, you need to grant the managed identity access to your Kusto cluster:

**Option 1 - Using PowerShell Script:**
```powershell
# Run the provided script
.\scripts\configure-kusto-permissions.ps1 `
    -KustoClusterName "your-kusto-cluster" `
    -KustoDatabase "SubscriptionDB" `
    -ResourceGroupName "rg-stratos-dev" `
    -AppServiceName "your-app-service-name"
```

**Option 2 - Manual Configuration:**
1. Get your app's managed identity principal ID from Azure Portal
2. Go to your Kusto cluster web UI: `https://your-cluster.kusto.windows.net`
3. Run these KQL commands:
```kql
.add database SubscriptionDB users ('aadapp=<PRINCIPAL_ID>') 'Stratos App Managed Identity'
.add database SubscriptionDB viewers ('aadapp=<PRINCIPAL_ID>') 'Stratos App Managed Identity'
```

**Option 3 - Using Azure CLI:**
```bash
# Install Kusto extension if not already installed
az extension add --name kusto

# Create database principal assignment
az kusto database-principal-assignment create \
    --cluster-name your-kusto-cluster \
    --database-name SubscriptionDB \
    --resource-group rg-stratos-dev \
    --principal-assignment-name stratos-app-permissions \
    --principal-id <PRINCIPAL_ID> \
    --principal-type App \
    --role Viewer
```

## Security

- **Managed Identity Authentication**: App Service uses managed identity to authenticate to Kusto (no credentials stored)
- **Secrets Management**: Application secrets are stored in Azure Key Vault
- **HTTPS Enforcement**: All connections use HTTPS
- **Secure Configuration**: Application Insights and other Azure services use secure connection strings
- **Role-Based Access**: Kusto permissions are granted using Azure RBAC principles

## Support

For deployment issues:
1. Check the azd deployment logs
2. Review Azure Portal for resource status
3. Check Application Insights for runtime errors
4. Create an issue in the GitHub repository