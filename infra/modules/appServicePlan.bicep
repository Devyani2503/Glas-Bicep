param location string
param name string
param skuName string
param skuTier string
param tags object

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: name
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true
  }
}

output id string = plan.id
output name string = plan.name
