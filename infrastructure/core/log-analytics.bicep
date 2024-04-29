// --------------------------------------------------------------------------------
// Creates a Log Analytics Workspace
// --------------------------------------------------------------------------------
param name string
param location string = resourceGroup().location
param tags object = {}

// --------------------------------------------------------------------------------
resource logWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
        name: 'PerGB2018' // Standard
    }
  }
}

// --------------------------------------------------------------------------------
output id string = logWorkspaceResource.id
output name string = logWorkspaceResource.name
