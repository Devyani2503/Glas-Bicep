param acrName string
param principalIds array

var acrPullRoleId = '7f951fda-4a9e-40b6-a46b-5f9c1b0d7d1e'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in principalIds: {
  name: guid(acr.id, principalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${acrPullRoleId}'
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
