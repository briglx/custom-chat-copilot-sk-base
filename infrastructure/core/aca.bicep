param name string
param location string
param tags object = {}

param environmentName string

param storageAccountName string
param storageAccountRG string
param storageContainerName string

param cosmosDBName string
param cosmosDBRG string
//param cosmosDBConnectionString string

param azureSearchName string
param azureSearchRG string
param azureSearchContentIndex string

param aoaiPremiumServiceEndpoint string
param aoaiPremiumServiceKey string
param aoaiPremiumChatGptDeployment string

param aoaiStandardServiceEndpoint string
param aoaiStandardServiceKey string
param aoaiStandardChatGptDeployment string

param aoaiEmbeddingsDeployment string

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('Name of the Azure Container Registry')
param acrName string

// Container Image ref
param containerImage string

// Networking
param useExternalIngress bool = false
param containerPort int

// Dependency resources
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
  scope: resourceGroup(storageAccountRG)
}
var keys = listKeys(storageAccount.id, '2019-06-01')
//var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=' + storageAccount.name + ';AccountKey=' + keys.keys[0].value
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${keys.keys[0].value}'
var storageBlobEndpoint = storageAccount.properties.primaryEndpoints.blob

resource searchService 'Microsoft.Search/searchServices@2020-08-01' existing = {
  name: azureSearchName
  scope: resourceGroup(azureSearchRG)
}
var azureSearchServiceKey = searchService.listQueryKeys().value[0].key
var azureSearchServiceEndpoint = 'https://${name}.search.windows.net/'

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' existing = {
  name: cosmosDBName
  scope: resourceGroup(cosmosDBRG)
}
var cosmosDBConnectionString = listConnectionStrings(cosmosDB.id, '2019-12-12').connectionStrings[0].connectionString

// Container App Env
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      secrets: [
        {
          name: 'cosmosdbconnectionstring'
          value: cosmosDBConnectionString
        }
        {
          name: 'aoaistandardservicekey'
          value: aoaiStandardServiceKey
        }
        {
          name: 'aoaipremiumservicekey'
          value: aoaiPremiumServiceKey
        }
        {
          name: 'azuresearchservicekey'
          value: azureSearchServiceKey
        }
        {
          name: 'azurestorageconnectionstring'
          value: storageConnectionString
        }
      ]
      ingress: {
        external: useExternalIngress
        targetPort: containerPort
      }
    }
    template: {
      containers: [
        {
          image: containerImage
          name: name
          env: [
            {
              name: 'AzureStorageAccountEndpoint'
              value: storageBlobEndpoint
            }
            {
              name: 'AzureStorageContainer'
              value: storageContainerName
            }
            {
              name: 'AzureStorageConnectionString'
              secretRef: 'azurestorageconnectionstring'
            }
            {
              name: 'CosmosDBConnectionString'
              secretRef: 'cosmosdbconnectionstring'
            }
            {
              name: 'AzureSearchServiceKey'
              secretRef: 'azuresearchservicekey'
            }
            {
              name: 'AzureSearchServiceEndpoint'
              value: azureSearchServiceEndpoint
            }
            {
              name: 'AzureSearchContentIndex'
              value: azureSearchContentIndex
            }
            {
              name: 'AOAIPremiumServiceEndpoint'
              value: aoaiPremiumServiceEndpoint
            }
            {
              name: 'AOAIPremiumServiceKey'
              secretRef: 'aoaipremiumservicekey'
            }
            {
              name: 'AOAIPremiumChatGptDeployment'
              value: aoaiPremiumChatGptDeployment
            }
            {
              name: 'AOAIStandardServiceEndpoint'
              value: aoaiStandardServiceEndpoint
            }
            {
              name: 'AOAIStandardServiceKey'
              secretRef: 'aoaistandardservicekey'
            }
            {
              name: 'AOAIStandardChatGptDeployment'
              value: aoaiStandardChatGptDeployment
            }
            {
              name: 'AOAIEmbeddingsDeployment'
              value: aoaiEmbeddingsDeployment
            }

          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
