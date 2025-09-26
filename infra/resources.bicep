param environmentName string
param location string = resourceGroup().location
param resourceToken string

param kustoCluster string = ''
param kustoDatabase string = 'SubscriptionDB'
param logicAppUrl string = ''

@secure()
param secretKey string = ''

// Generate a unique secret key if not provided
var generatedSecretKey = !empty(secretKey) ? secretKey : uniqueString(resourceGroup().id, environmentName)

// Container registry
resource containerRegistry 'Microsoft.ContainerRegistry@2023-01-01-preview' = {
  name: 'cr${resourceToken}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${resourceToken}'
  location: location
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
  name: 'cae-${resourceToken}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// User-assigned managed identity for the container app
resource containerAppUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-${resourceToken}'
  location: location
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ca-${resourceToken}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUserAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 5000
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'secret-key'
          value: generatedSecretKey
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/hello-world'
          name: 'stratos'
          env: [
            {
              name: 'SECRET_KEY'
              secretRef: 'secret-key'
            }
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
              value: empty(kustoCluster) ? 'true' : 'false'
            }
            {
              name: 'FLASK_ENV'
              value: 'production'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
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
  }
}

// Output values
output WEB_IDENTITY_PRINCIPAL_ID string = containerAppUserAssignedIdentity.properties.principalId
output WEB_NAME string = containerApp.name
output WEB_URI string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output WEB_IMAGE_NAME string = '${containerRegistry.properties.loginServer}/stratos'

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name