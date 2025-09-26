targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters for existing Azure services
@description('Existing Kusto cluster URL (optional)')
param kustoCluster string = ''

@description('Existing Kusto database name (optional)')
param kustoDatabase string = 'SubscriptionDB'

@description('Existing Logic App URL for sending emails (optional)')
param logicAppUrl string = ''

@description('Secret key for Flask application')
@secure()
param secretKey string = ''

// Generate a unique suffix for resource names
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Deploy core infrastructure
module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    resourceToken: resourceToken
    kustoCluster: kustoCluster
    kustoDatabase: kustoDatabase
    logicAppUrl: logicAppUrl
    secretKey: secretKey
  }
}

// Output important values
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

// Container App outputs
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = resources.outputs.WEB_IDENTITY_PRINCIPAL_ID
output SERVICE_WEB_NAME string = resources.outputs.WEB_NAME
output SERVICE_WEB_URI string = resources.outputs.WEB_URI
output SERVICE_WEB_IMAGE_NAME string = resources.outputs.WEB_IMAGE_NAME

// Application configuration outputs
output KUSTO_CLUSTER string = kustoCluster
output KUSTO_DATABASE string = kustoDatabase
output LOGIC_APP_URL string = logicAppUrl