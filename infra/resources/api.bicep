param name string
param location string = resourceGroup().location
param tags object = {}

param applicationInsightsName string = ''
param appServicePlanName string
param keyVaultName string
param managedIdentity bool = !empty(keyVaultName)

param logicAppTriggerUrl string = ''
param kustoClusterName string = ''
param kustoDatabaseName string = 'SubscriptionDB'
param demoMode bool = false

param appCommandLine string = ''
param runtimeName string = 'python'
param runtimeVersion string = '3.11'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'B1'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (managedIdentity && !empty(keyVaultName)) {
  name: keyVaultName
}

resource managedIdentityResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (managedIdentity) {
  name: '${name}-identity'
  location: location
  tags: tags
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: '${runtimeName}|${runtimeVersion}'
      appCommandLine: appCommandLine
      numberOfWorkers: 1
      minimumElasticInstanceCount: 0
      use32BitWorkerProcess: false
      functionAppScaleLimit: 0
      healthCheckPath: '/health'
    }
    clientAffinityEnabled: false
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
  }
  identity: managedIdentity ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResource.id}': {}
    }
  } : { type: 'None' }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: union(
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
        FLASK_ENV: 'production'
        SECRET_KEY: managedIdentity && !empty(keyVaultName) ? '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/SECRET-KEY)' : uniqueString(resourceGroup().id)
        LOGIC_APP_URL: logicAppTriggerUrl
        KUSTO_CLUSTER: !empty(kustoClusterName) ? 'https://${kustoClusterName}.kusto.windows.net' : ''
        KUSTO_DATABASE: kustoDatabaseName
        DEMO_MODE: string(demoMode)
      },
      !empty(applicationInsightsName) ? { APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString } : {},
      managedIdentity ? { AZURE_CLIENT_ID: managedIdentityResource.properties.clientId } : {})
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = if (managedIdentity && !empty(keyVaultName)) {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        objectId: managedIdentityResource.properties.principalId
        permissions: { secrets: [ 'get', 'list' ] }
        tenantId: subscription().tenantId
      }
    ]
  }
}

output SERVICE_API_IDENTITY_PRINCIPAL_ID string = managedIdentity ? managedIdentityResource.properties.principalId : ''
output SERVICE_API_NAME string = appService.name
output SERVICE_API_URI string = 'https://${appService.properties.defaultHostName}'