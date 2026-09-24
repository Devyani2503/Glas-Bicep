targetScope = 'resourceGroup'

param location string
param namePrefix string
param environmentName string
param appServiceSkuName string
param appServiceSkuTier string
param deployerObjectId string
param deployerPrincipalType string
param assignKeyVaultRoles bool
param openaiApiKey string
param databaseUrl string
param jwtSecret string
param azureClientSecret string
param azureClientId string
param azureTenantId string
param azureSubscriptionId string
param enablePurgeProtection bool
param deployApplicationInsights bool
param logRetentionInDays int
param containerRegistrySku string
param cosmosAccountName string
param cosmosContainerName string
param alwaysOn bool
param tags object

type webAppConfig = {
  suffix: string
  linuxFxVersion: string
  startupCommand: string?
}

param webApps webAppConfig[]

var uniqueSuffix = uniqueString(resourceGroup().id, environmentName)

var keyVaultName = take('kv${take(replace(namePrefix, '-', ''), 8)}${uniqueSuffix}', 24)
var planName = take('plan-${namePrefix}-${environmentName}', 40)
var logAnalyticsName = take('log-${namePrefix}-${environmentName}', 63)
var appInsightsName = take('appi-${namePrefix}-${environmentName}', 255)
var containerRegistryName = take(toLower('acr${replace(namePrefix, '-', '')}${environmentName}${uniqueSuffix}'), 50)
var cosmosDatabaseName = '${namePrefix}-${environmentName}'
var vnetName = take('vnet-${namePrefix}-${environmentName}', 64)
var webAppNames = [for app in webApps: take('${namePrefix}-${app.suffix}-${environmentName}-${uniqueSuffix}', 60)]
var webHostName = '${webAppNames[1]}.azurewebsites.net'

var keyVaultSecretUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4338-8f55-ad42a6c5e47e'

var insightsSettings = deployApplicationInsights ? {
  APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.?outputs.connectionString ?? ''
  ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
} : {}

var sharedAppSettings = union({
  KEY_VAULT_URI: keyVault.outputs.uri
  KEY_VAULT_NAME: keyVault.outputs.name
  COSMOS_ENDPOINT: cosmos.outputs.endpoint
  COSMOS_DATABASE_NAME: cosmos.outputs.databaseName
}, insightsSettings)

var appSettingsBySuffix = {
  api: union(sharedAppSettings, {
    OPENAI_API_KEY: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.uri}secrets/OpenAiApiKey)'
    DATABASE_URL: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.uri}secrets/DatabaseUrl)'
    JWT_SECRET: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.uri}secrets/JwtSecret)'
    AZURE_CLIENT_SECRET: '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.uri}secrets/AzureClientSecret)'
    AZURE_CLIENT_ID: azureClientId
    AZURE_TENANT_ID: azureTenantId
    AZURE_SUBSCRIPTION_ID: azureSubscriptionId
    CORS_ORIGINS: 'https://${webHostName}'
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
  })
  web: union(sharedAppSettings, {
    VITE_API_BASE: 'https://${webAppNames[0]}.azurewebsites.net'
  })
  petparadise: sharedAppSettings
  watchdog: union(sharedAppSettings, {
    AZURE_CLIENT_ID: azureClientId
    AZURE_TENANT_ID: azureTenantId
    AZURE_SUBSCRIPTION_ID: azureSubscriptionId
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
  })
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'key-vault'
  params: {
    location: location
    name: keyVaultName
    tenantId: tenant().tenantId
    enablePurgeProtection: enablePurgeProtection
    tags: tags
  }
}

module applicationInsights 'modules/appInsights.bicep' = if (deployApplicationInsights) {
  name: 'application-insights'
  params: {
    location: location
    name: appInsightsName
    workspaceId: logAnalytics.outputs.id
    tags: tags
  }
}

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'log-analytics'
  params: {
    location: location
    name: logAnalyticsName
    retentionInDays: logRetentionInDays
    tags: tags
  }
}

module containerRegistry 'modules/containerRegistry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    name: containerRegistryName
    skuName: containerRegistrySku
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    name: vnetName
    tags: tags
  }
}

module cosmos 'modules/cosmosDb.bicep' = {
  name: 'cosmos-db'
  params: {
    location: location
    name: cosmosAccountName
    databaseName: cosmosDatabaseName
    containerName: cosmosContainerName
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    privateDnsZoneId: network.outputs.cosmosPrivateDnsZoneId
    tags: tags
  }
}

module appServicePlan 'modules/appServicePlan.bicep' = {
  name: 'app-service-plan'
  params: {
    location: location
    name: planName
    skuName: appServiceSkuName
    skuTier: appServiceSkuTier
    tags: tags
  }
}

module sites 'modules/webApp.bicep' = [
  for (app, i) in webApps: {
    name: 'web-app-${app.suffix}'
    params: {
      location: location
      name: webAppNames[i]
      appServicePlanId: appServicePlan.outputs.id
      linuxFxVersion: app.linuxFxVersion
      startupCommand: app.startupCommand ?? ''
      alwaysOn: alwaysOn
      appSettings: contains(appSettingsBySuffix, app.suffix)
        ? appSettingsBySuffix[app.suffix]
        : sharedAppSettings
      logAnalyticsWorkspaceId: logAnalytics.outputs.id
      integrationSubnetId: network.outputs.integrationSubnetId
      privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
      privateDnsZoneId: network.outputs.webAppPrivateDnsZoneId
      tags: union(tags, { app: app.suffix })
    }
  }
]

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  dependsOn: [
    keyVault
  ]
}

resource openaiSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(openaiApiKey)) {
  parent: existingKeyVault
  name: 'OpenAiApiKey'
  tags: tags
  properties: {
    value: openaiApiKey
    contentType: 'text/plain'
  }
}

resource databaseSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(databaseUrl)) {
  parent: existingKeyVault
  name: 'DatabaseUrl'
  tags: tags
  properties: {
    value: databaseUrl
    contentType: 'text/plain'
  }
}

resource jwtSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(jwtSecret)) {
  parent: existingKeyVault
  name: 'JwtSecret'
  tags: tags
  properties: {
    value: jwtSecret
    contentType: 'text/plain'
  }
}

resource azureClientSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(azureClientSecret)) {
  parent: existingKeyVault
  name: 'AzureClientSecret'
  tags: tags
  properties: {
    value: azureClientSecret
    contentType: 'text/plain'
  }
}

resource webAppKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for i in range(0, length(webApps)): if (assignKeyVaultRoles) {
    name: guid(webAppNames[i], keyVaultName, keyVaultSecretUserRoleId)
    scope: existingKeyVault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretUserRoleId)
      principalId: sites[i].outputs.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource deployerKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignKeyVaultRoles && !empty(deployerObjectId)) {
  name: guid(keyVaultName, deployerObjectId, keyVaultSecretsOfficerRoleId)
  scope: existingKeyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)
    principalId: deployerObjectId
    principalType: deployerPrincipalType
  }
}

output resourceGroupName string = resourceGroup().name
output appServicePlanName string = appServicePlan.outputs.name
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output webAppNames array = [for i in range(0, length(webApps)): sites[i].outputs.name]
output webAppUrls array = [for i in range(0, length(webApps)): 'https://${sites[i].outputs.hostName}']
output webAppPrincipalIds array = [for i in range(0, length(webApps)): sites[i].outputs.principalId]
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
output applicationInsightsName string = applicationInsights.?outputs.name ?? ''
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output cosmosAccountName string = cosmos.outputs.name
output cosmosEndpoint string = cosmos.outputs.endpoint
output virtualNetworkName string = network.outputs.name
