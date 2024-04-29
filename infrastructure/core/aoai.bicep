param name string
param location string
param tags object = {}

param sku string = 'S0'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: toLower(name)
  }
}
