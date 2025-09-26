# Azure Deployment Guide for Stratos

This guide explains how to deploy Stratos to Azure using the Azure Developer CLI (azd).

## Prerequisites

1. **Azure Developer CLI (azd)** - Install from [aka.ms/azd](https://aka.ms/azd)
2. **Azure CLI** - Install from [docs.microsoft.com](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **Docker** - For building container images (optional, azd handles this)
4. **An existing Azure Kusto cluster** (if not using demo mode)
5. **An existing Azure Logic App** for email sending (if not using demo mode)

## Quick Deployment

### 1. Clone and Setup

```bash
git clone https://github.com/ninallam/stratos.git
cd stratos
```

### 2. Login to Azure

```bash
azd auth login
```

### 3. Initialize Environment

```bash
azd init
```

When prompted:
- Environment name: Choose a unique name (e.g., `stratos-dev`)
- Azure location: Choose your preferred region (e.g., `eastus`)

### 4. Configure Environment Variables (Optional)

If you have existing Kusto cluster and Logic App:

```bash
# Set your existing Kusto cluster URL
azd env set KUSTO_CLUSTER "https://your-cluster.kusto.windows.net"

# Set your Kusto database name (default: SubscriptionDB)
azd env set KUSTO_DATABASE "SubscriptionDB"

# Set your Logic App webhook URL
azd env set LOGIC_APP_URL "https://your-logic-app.azurewebsites.net/api/workflows/manual/triggers/When_a_HTTP_request_is_received/paths/invoke"

# Disable demo mode to use real Azure services
azd env set DEMO_MODE "false"
```

### 5. Deploy to Azure

```bash
azd up
```

This command will:
- Provision Azure resources (Container Registry, Container Apps, etc.)
- Build and push the Docker image
- Deploy the application
- Display the deployment results

## What Gets Deployed

The deployment creates the following Azure resources:

- **Resource Group**: Contains all resources for the environment
- **Azure Container Registry**: Stores the application container image
- **Azure Container Apps Environment**: Managed environment for containers
- **Container App**: Runs the Stratos application
- **Log Analytics Workspace**: For monitoring and logs
- **Managed Identity**: For secure access between resources

## Environment Variables

The application supports these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `KUSTO_CLUSTER` | (empty) | URL of your existing Kusto cluster |
| `KUSTO_DATABASE` | `SubscriptionDB` | Name of the Kusto database |
| `LOGIC_APP_URL` | (empty) | URL of your Logic App for sending emails |
| `DEMO_MODE` | `true` | Run in demo mode with mock data |
| `SECRET_KEY` | (auto-generated) | Flask secret key for sessions |

## Post-Deployment Configuration

### 1. Get the Application URL

After deployment, azd will display the application URL. You can also get it with:

```bash
azd env get SERVICE_WEB_URI
```

### 2. Configure Kusto Database (if using real Kusto)

If using a real Kusto cluster, ensure your database has the required table:

```kusto
.create table SubscriptionAccountTeams (
    SubscriptionId: string,
    AccountTeamEmail: string,
    AccountTeamName: string
)
```

### 3. Configure Logic App (if using real Logic App)

Create a Logic App with an HTTP trigger that accepts this JSON payload:

```json
{
    "to": ["email1@company.com", "email2@company.com"],
    "subject": "Email Subject",
    "body": "Email content",
    "from": "sender@company.com",
    "timestamp": "2024-01-01T00:00:00"
}
```

## Updating the Application

To update the deployed application:

```bash
azd deploy
```

This will rebuild and redeploy just the application without reprovisioning infrastructure.

## Monitoring and Logs

### View Application Logs

```bash
# Get logs from the container app
az containerapp logs show --name <app-name> --resource-group <resource-group>
```

### Access Monitoring

- **Azure Portal**: Navigate to your Container App for monitoring dashboards
- **Log Analytics**: View detailed logs and metrics in the workspace

## Cleanup

To remove all deployed resources:

```bash
azd down
```

## Troubleshooting

### Common Issues

1. **Deployment fails with permissions error**
   - Ensure you have Contributor access to the Azure subscription
   - Check that your account can create resources in the selected region

2. **Application doesn't start**
   - Check the container logs in Azure Portal
   - Verify environment variables are set correctly

3. **Can't access the application**
   - Ensure the Container App ingress is enabled and set to external
   - Check if there are any network restrictions

### Getting Help

- Check the [azd documentation](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- Review Container Apps logs in Azure Portal
- Create an issue in the repository for application-specific problems

## Security Considerations

- The deployment uses managed identities for secure authentication
- Secrets are stored in Container Apps configuration
- Only HTTPS endpoints are accessible externally
- Consider using Azure Key Vault for sensitive configuration in production