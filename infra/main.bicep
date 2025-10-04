targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the existing Kusto cluster (without the .kusto.windows.net suffix)')
param kustoClusterName string = ''

@description('Name of the Kusto database to use')
param kustoDatabaseName string = 'SubscriptionDB'

@description('Id of the user or app to assign application roles')
param principalId string = ''

// Optional parameters to override the default Azure resource names
param appServicePlanName string = ''
param appServiceName string = ''
param applicationInsightsName string = ''
param keyVaultName string = ''
param resourceGroupName string = ''

@description('Flag to use demo mode (no Azure dependencies)')
param demoMode bool = false

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application database
module api './resources/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(appServiceName) ? appServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    tags: tags
    appServicePlanName: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    keyVaultName: keyVault.outputs.name
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    kustoClusterName: kustoClusterName
    kustoDatabaseName: kustoDatabaseName
    demoMode: demoMode
  }
}

// Logic App removed - using Microsoft Graph API directly

// The application database
module keyVault './resources/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Monitor application with Azure Monitor
module monitoring './resources/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

// Data outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

// App outputs
output API_BASE_URL string = api.outputs.SERVICE_API_URI
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output KUSTO_CLUSTER string = !empty(kustoClusterName) ? 'https://${kustoClusterName}.kusto.windows.net' : ''
output KUSTO_DATABASE string = kustoDatabaseName