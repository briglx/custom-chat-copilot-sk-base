targetScope = 'subscription'

// General Parameters
@minLength(1)
@maxLength(64)
@description('Application name')
param applicationName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('SKU name for the Azure Cognitive Search service. Default: standard')
param searchServiceSkuName string = 'standard'
param searchContentIndex string = 'manuals'

// Dependencies
param aoaiServiceEndpoint string  = ''
param aoaiServiceKey string = ''

// Potentialy Existing Resources
param cosmosdbName string =''
param databaseName string = 'ChatHistory'

@description('Name of the log analytics workspace.')
param logAnalyticsWorkspaceName string = ''

@description('Name of the storage account')
param storageAccountName string = ''
@description('Name of the storage container. Default: content')
param storageContainerName string = 'content'

param acrName string = ''

// Variables
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, applicationName, location))
var tags = { 'app-name': applicationName }

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${applicationName}_${location}'
  location: location
  tags: tags
}

// Log Analytics
module logAnalytics './core/log-analytics.bicep' = {
  name: 'logAnalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.webSitesAppService}${applicationName}-${resourceToken}'
    location: location
    tags: tags
  }
}

// Container Registry
module acr './core/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    name: !empty(acrName) ? acrName : '${abbrs.containerRegistryRegistries}${applicationName}${resourceToken}'
    location: location
    tags: tags
    sku: 'Standard'
  }
}

// CosmosDB
module db './core/cosmosdb.bicep' = {
	name: 'cosmosdb'
  scope: rg
	params: {
    name: !empty(cosmosdbName) ? cosmosdbName : '${abbrs.documentDBDatabaseAccounts}${applicationName}-${resourceToken}'
    location: location
    tags: tags
    databaseName: !empty(databaseName) ? databaseName : 'ChatHistory'
	}
}

// Search Service
module searchService './core/search-services.bicep' = {
  name: 'searchService'
  scope: rg
  params: {
    name: '${abbrs.searchSearchServices}${applicationName}-${resourceToken}'
    location: location
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}

// Storage Account
module storage './core/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : substring('${abbrs.storageStorageAccounts}${applicationName}${resourceToken}',0,24)
    location: location
    tags: tags
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: false
    sku: {
      name: 'Standard_ZRS'
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// Container App Environment
module aca './core/aca.bicep' = {
  name: 'aca'
  scope: rg
  params: {
    name: 'chatapp'
    environmentName: '${abbrs.appContainerEnv}${applicationName}'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalytics.outputs.name
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    useExternalIngress: true
    containerPort: 8080

    acrName: acr.outputs.name

    storageAccountName: storage.outputs.name
    storageAccountRG: rg.name
    storageContainerName: storageContainerName

    cosmosDBName: db.outputs.name
    cosmosDBRG: rg.name

    azureSearchName: searchService.outputs.name
    azureSearchRG: rg.name
    azureSearchContentIndex: searchContentIndex

    aoaiPremiumServiceEndpoint: aoaiServiceEndpoint
    aoaiPremiumServiceKey: aoaiServiceKey
    aoaiPremiumChatGptDeployment: 'gpt-35-turbo'

    aoaiStandardServiceEndpoint: aoaiServiceEndpoint
    aoaiStandardServiceKey: aoaiServiceKey
    aoaiStandardChatGptDeployment: 'gpt-35-turbo'

    aoaiEmbeddingsDeployment: 'text-embedding'
  }
}
