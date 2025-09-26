param name string
param location string = resourceGroup().location
param tags object = {}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                to: {
                  type: 'array'
                  items: {
                    type: 'string'
                  }
                }
                subject: {
                  type: 'string'
                }
                body: {
                  type: 'string'
                }
                from: {
                  type: 'string'
                }
                timestamp: {
                  type: 'string'
                }
              }
              required: [
                'to'
                'subject'
                'body'
              ]
            }
          }
        }
      }
      actions: {
        'Send_an_email_V2': {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            body: {
              To: '@{join(triggerBody()?[\'to\'], \';\')}'
              Subject: '@triggerBody()?[\'subject\']'
              Body: '<p>@{triggerBody()?[\'body\']}</p>'
              From: '@{triggerBody()?[\'from\']}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
          }
        }
        Response: {
          runAfter: {
            Send_an_email_V2: [
              'Succeeded'
            ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: {
              success: true
              message: 'Email sent successfully'
            }
          }
        }
        Response_Error: {
          runAfter: {
            Send_an_email_V2: [
              'Failed'
            ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 400
            body: {
              success: false
              message: 'Failed to send email'
              error: '@{body(\'Send_an_email_V2\')}'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/office365'
            connectionName: 'office365'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
          }
        }
      }
    }
  }
}

// Create Office 365 Outlook API connection
resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365'
  location: location
  tags: tags
  properties: {
    displayName: 'Office 365 Outlook'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
    }
  }
}

output name string = logicApp.name
output triggerUrl string = listCallbackURL('${logicApp.id}/triggers/manual', '2019-05-01').value