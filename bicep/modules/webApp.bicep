param location string
param webAppName string
param serverFarmId string
param keyVaultName string
param containerImage string
param acrLoginServer string
param appInsightsConnectionString string

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarmId
    httpsOnly: true
    keyVaultReferenceIdentity: 'SystemAssigned'
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${containerImage}'
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'KEY_VAULT_URI'
          value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
  }
}

output principalId string = webApp.identity.principalId
