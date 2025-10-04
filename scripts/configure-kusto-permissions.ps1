# Script to configure Kusto permissions for the managed identity
# Run this after deploying the infrastructure

param(
    [Parameter(Mandatory=$true)]
    [string]$KustoClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$KustoDatabase = "SubscriptionDB",
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName
)

Write-Host "Configuring Kusto permissions for managed identity..." -ForegroundColor Green

try {
    # Get the managed identity principal ID
    $identityInfo = az webapp identity show --name $AppServiceName --resource-group $ResourceGroupName | ConvertFrom-Json
    $principalId = $identityInfo.principalId

    if (-not $principalId) {
        throw "Could not retrieve managed identity principal ID"
    }

    Write-Host "Managed Identity Principal ID: $principalId" -ForegroundColor Yellow

    # Display instructions for Kusto permissions
    Write-Host @"

To complete the setup, choose one of these options:

OPTION 1 - Using Kusto Web UI:
1. Go to: https://$KustoClusterName.kusto.windows.net
2. Run this KQL command to add the managed identity as a database user:
   .add database $KustoDatabase users ('aadapp=$principalId') 'Stratos App Managed Identity'
3. Grant viewer permissions:
   .add database $KustoDatabase viewers ('aadapp=$principalId') 'Stratos App Managed Identity'

OPTION 2 - Using Azure CLI (if Kusto extension is installed):
az kusto database-principal-assignment create \
    --cluster-name $KustoClusterName \
    --database-name $KustoDatabase \
    --resource-group $ResourceGroupName \
    --principal-assignment-name stratos-app-permissions \
    --principal-id $principalId \
    --principal-type App \
    --role Viewer

OPTION 3 - Using Azure PowerShell (if Az.Kusto module is installed):
New-AzKustoDatabasePrincipalAssignment \
    -ResourceGroupName $ResourceGroupName \
    -ClusterName $KustoClusterName \
    -DatabaseName $KustoDatabase \
    -PrincipalAssignmentName "stratos-app-permissions" \
    -PrincipalId $principalId \
    -PrincipalType "App" \
    -Role "Viewer"

"@ -ForegroundColor Cyan

    Write-Host "Configuration script completed!" -ForegroundColor Green
}
catch {
    Write-Error "Error: $_"
    exit 1
}