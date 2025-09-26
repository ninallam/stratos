param name string
param location string = resourceGroup().location
param tags object = {}
param resourceToken string
param principalId string = ''

// Container Apps specific parameters
param kustoCluster string = ''
param kustoDatabase string = 'SubscriptionDB'
param logicAppUrl string = ''
param demoMode string = 'true'

// Load abbreviations
var abbrs = loadJsonContent('./abbreviations.json')

// Container registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Log Analytics workspace for Container Apps
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  location: location
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// Container Apps environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${abbrs.appManagedEnvironments}${resourceToken}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        primarySharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// User assigned managed identity for the container app
resource containerAppUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
  location: location
  tags: tags
}

// Container app
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${abbrs.appContainerApps}${name}-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUserAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: containerAppUserAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'secret-key'
          value: 'dev-secret-key-${uniqueString(resourceGroup().id)}'
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'stratos'
          env: [
            {
              name: 'KUSTO_CLUSTER'
              value: kustoCluster
            }
            {
              name: 'KUSTO_DATABASE'
              value: kustoDatabase
            }
            {
              name: 'LOGIC_APP_URL'
              value: logicAppUrl
            }
            {
              name: 'DEMO_MODE'
              value: demoMode
            }
            {
              name: 'SECRET_KEY'
              secretRef: 'secret-key'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
    workloadProfileName: null
  }
}

// Grant the containerApp identity with Container Registry access
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, containerAppUserAssignedIdentity.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d'))
  properties: {
    roleDefinitionId:  subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
    principalId: containerAppUserAssignedIdentity.properties.principalId
  }
}

// Grant the specified principalId with Container Registry access (for azd to push images)
resource principalAcrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  scope: containerRegistry
  name: guid(containerRegistry.id, principalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec'))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalType: 'User'
    principalId: principalId
  }
}

// Outputs
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = containerAppUserAssignedIdentity.properties.principalId
output SERVICE_WEB_NAME string = containerApp.name
output SERVICE_WEB_URI string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output registryLoginServer string = containerRegistry.properties.loginServer
output registryName string = containerRegistry.name