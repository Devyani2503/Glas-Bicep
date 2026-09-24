using 'main.bicep'

param location = 'eastus'
param namePrefix = 'costdet'
param environmentName = 'dev'
param appServiceSkuName = 'P0v3'
param appServiceSkuTier = 'Premium0V3'
param deployerObjectId = ''
param deployerPrincipalType = 'User'
param assignKeyVaultRoles = false
param openaiApiKey = ''
param databaseUrl = ''
param jwtSecret = ''
param azureClientSecret = ''
param azureClientId = ''
param azureTenantId = ''
param azureSubscriptionId = ''
param enablePurgeProtection = false
param deployApplicationInsights = false
param logRetentionInDays = 30
param containerRegistrySku = 'Basic'
param cosmosAccountName = 'cosmos-costdet-v2-aeey55tzndc5i'
param cosmosContainerName = 'items'
param alwaysOn = true
param tags = {
  project: 'costdetective'
  environment: 'dev'
}
param webApps = [
  {
    suffix: 'test01'
    linuxFxVersion: 'PYTHON|3.12'
    startupCommand: 'bash startup.sh'
  }
  {
    suffix: 'test02'
    linuxFxVersion: 'NODE|20-lts'
    startupCommand: 'node server.js'
  }
  {
    suffix: 'test03'
    linuxFxVersion: 'NODE|20-lts'
    startupCommand: 'node server.js'
  }
  {
    suffix: 'test04'
    linuxFxVersion: 'PYTHON|3.12'
    startupCommand: ''
  }
]
