param name string
param location string = resourceGroup().location
param tags object = {}
param principalId string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    accessPolicies: !empty(principalId) ? [
      {
        objectId: principalId
        permissions: { secrets: [ 'get', 'list', 'set', 'delete', 'recover', 'backup', 'restore' ] }
        tenantId: subscription().tenantId
      }
    ] : []
  }

  resource secretKey 'secrets' = {
    name: 'SECRET-KEY'
    properties: {
      value: uniqueString(resourceGroup().id, 'secret-key')
    }
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name