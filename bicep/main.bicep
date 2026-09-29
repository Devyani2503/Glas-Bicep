param location string
param appServicePlanName string
param skuName string
param skuTier string
param webAppNames array
param keyVaultName string
param containerImage string
param acrName string
param acrSku string
param staticWebAppName string
param staticWebAppLocation string
param staticWebAppSku string
param staticWebAppProvider string
param repositoryUrl string
param branch string
param logAnalyticsWorkspaceName string
param appInsightsName string
param vnetName string
param vnetAddressPrefix string
param webAppSubnetName string
param webAppSubnetPrefix string
param privateEndpointSubnetName string
param privateEndpointSubnetPrefix string
param cosmosAccountName string
param privateEndpointName string
param privateDnsZoneName string

module appServicePlan 'modules/appServicePlan.bicep' = {
  name: 'appServicePlan'
  params: {
    location: location
    appServicePlanName: appServicePlanName
    skuName: skuName
    skuTier: skuTier
  }
}

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  params: {
    location: location
    appInsightsName: appInsightsName
    workspaceId: logAnalytics.outputs.id
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: acrName
    acrSku: acrSku
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    webAppSubnetName: webAppSubnetName
    webAppSubnetPrefix: webAppSubnetPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
  }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos'
  params: {
    location: location
    cosmosAccountName: cosmosAccountName
  }
}

module privateEndpoint 'modules/privateEndpoint.bicep' = {
  name: 'privateEndpoint'
  params: {
    location: location
    privateEndpointName: privateEndpointName
    privateDnsZoneName: privateDnsZoneName
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    cosmosAccountId: cosmos.outputs.id
  }
}

module webApp 'modules/webApp.bicep' = [for webAppName in webAppNames: {
  name: 'webApp-${webAppName}'
  params: {
    location: location
    webAppName: webAppName
    serverFarmId: appServicePlan.outputs.id
    keyVaultName: keyVaultName
    containerImage: containerImage
    acrLoginServer: acr.outputs.loginServer
    appInsightsConnectionString: appInsights.outputs.connectionString
    subnetId: network.outputs.webAppSubnetId
    cosmosEndpoint: cosmos.outputs.documentEndpoint
  }
}]

module acrPull 'modules/acrPull.bicep' = {
  name: 'acrPull'
  params: {
    acrName: acrName
    principalIds: [for i in range(0, length(webAppNames)): webApp[i].outputs.principalId]
  }
}

module staticWebApp 'modules/staticWebApp.bicep' = {
  name: 'staticWebApp'
  params: {
    location: staticWebAppLocation
    staticWebAppName: staticWebAppName
    skuName: staticWebAppSku
    provider: staticWebAppProvider
    repositoryUrl: repositoryUrl
    branch: branch
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
    principalIds: [for i in range(0, length(webAppNames)): webApp[i].outputs.principalId]
  }
}
