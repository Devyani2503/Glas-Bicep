param location string
param staticWebAppName string
param skuName string
param provider string
param repositoryUrl string
param branch string

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    provider: provider
    repositoryUrl: repositoryUrl
    branch: branch
    buildProperties: {
      skipGithubActionWorkflowGeneration: true
    }
  }
}
