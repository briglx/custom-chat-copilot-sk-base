param name string
param location string
param tags object = {}
param sku string

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
  }
}



output id string = acr.id
output name string = acr.name
