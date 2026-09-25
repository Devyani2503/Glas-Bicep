param location string
param webAppName string
param serverFarmId string
param keyVaultName string
param containerImage string
param acrLoginServer string
param appInsightsConnectionString string
param subnetId string
param cosmosEndpoint string

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
    virtualNetworkSubnetId: subnetId
    vnetRouteAllEnabled: true
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
        {
          name: 'COSMOS_ENDPOINT'
          value: cosmosEndpoint
        }
      ]
    }
  }
}

output principalId string = webApp.identity.principalId
