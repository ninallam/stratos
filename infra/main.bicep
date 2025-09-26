targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters
@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('URL of the existing Kusto cluster')
param kustoCluster string = ''

@description('Name of the Kusto database')
param kustoDatabase string = 'SubscriptionDB'

@description('URL of the existing Logic App for email sending')
param logicAppUrl string = ''

@description('Whether to run in demo mode')
param demoMode string = 'true'

// Generate a unique suffix for resources
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Deploy container apps environment and the app
module containerApps './app.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    name: 'stratos'
    location: location
    tags: tags
    resourceToken: resourceToken
    principalId: principalId
    kustoCluster: kustoCluster
    kustoDatabase: kustoDatabase
    logicAppUrl: logicAppUrl
    demoMode: demoMode
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = containerApps.outputs.SERVICE_WEB_IDENTITY_PRINCIPAL_ID
output SERVICE_WEB_NAME string = containerApps.outputs.SERVICE_WEB_NAME
output SERVICE_WEB_URI string = containerApps.outputs.SERVICE_WEB_URI