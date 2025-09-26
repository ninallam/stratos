# Deployment Guide for Stratos

This guide explains how to deploy the Stratos application to Azure using Azure Developer CLI (azd).

## Prerequisites

1. **Azure Developer CLI**: Install from [https://aka.ms/azd-install](https://aka.ms/azd-install)
2. **Azure CLI**: Install from [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **Docker**: Required for building the container image
4. **Azure Subscription**: Active Azure subscription with permissions to create resources

## Quick Start

1. **Initialize the project**:
   ```bash
   azd init --template .
   ```

2. **Login to Azure**:
   ```bash
   azd auth login
   ```

3. **Deploy the application**:
   ```bash
   azd up
   ```

## Configuration

The deployment can be configured with the following optional parameters:

### Environment Variables

Set these before running `azd up` to configure Azure service integration:

```bash
# Optional: Existing Kusto cluster for production use
export KUSTO_CLUSTER="https://your-cluster.kusto.windows.net"
export KUSTO_DATABASE="SubscriptionDB"

# Optional: Existing Logic App URL for email sending
export LOGIC_APP_URL="https://your-logic-app-url.com/triggers/manual/paths/invoke"

# Optional: Custom secret key (auto-generated if not provided)
export SECRET_KEY="your-secret-key-here"
```

### Demo Mode vs Production Mode

- **Demo Mode**: If `KUSTO_CLUSTER` and `LOGIC_APP_URL` are not configured, the app runs in demo mode with mock data
- **Production Mode**: When Azure services are configured, the app connects to real Kusto and Logic Apps

## Deployment Process

The `azd up` command will:

1. **Provision Infrastructure**:
   - Container Registry for storing the app image
   - Container Apps Environment for hosting
   - Log Analytics Workspace for monitoring
   - Container App with managed identity

2. **Build and Deploy**:
   - Build Docker image from the application code
   - Push image to Azure Container Registry
   - Deploy to Azure Container Apps

3. **Configure Application**:
   - Set environment variables for Azure service integration
   - Configure scaling rules and health checks

## Post-Deployment

After deployment, you'll get:

- **Application URL**: Access the web interface
- **Health Check**: Available at `/health` endpoint
- **Logs**: Available in Azure Portal under Container Apps

## Managing the Deployment

```bash
# View deployment status
azd show

# View application logs
az containerapp logs show --name <app-name> --resource-group <resource-group>

# Update environment variables
az containerapp update --name <app-name> --resource-group <resource-group> --set-env-vars KEY=VALUE

# Scale the application
az containerapp update --name <app-name> --resource-group <resource-group> --min-replicas 2 --max-replicas 5

# Clean up resources
azd down
```

## Azure Services Integration

### Setting up Kusto Database

If you have an existing Kusto cluster, ensure it has a table with this schema:

```kusto
.create table SubscriptionAccountTeams (
    SubscriptionId: string,
    AccountTeamEmail: string,
    AccountTeamName: string
)
```

### Setting up Logic Apps

Create a Logic App with an HTTP trigger that accepts:

```json
{
    "to": ["email1@company.com", "email2@company.com"],
    "subject": "Email Subject",
    "body": "Email content",
    "from": "sender@company.com",
    "timestamp": "2024-01-01T00:00:00"
}
```

## Troubleshooting

### Common Issues

1. **Build Failures**: Ensure Docker is running and you have internet access
2. **Permission Errors**: Check Azure CLI login and subscription permissions
3. **SSL Certificate Issues**: The container handles this automatically with trusted hosts

### Getting Help

- Check application logs in Azure Portal
- Use `azd show --verbose` for detailed deployment information  
- Visit the `/health` endpoint to check application status

## Security Notes

- The application uses managed identity for Azure service authentication
- Environment variables containing secrets are stored securely in Azure
- Container runs as non-root user for security
- HTTPS is enforced for external traffic