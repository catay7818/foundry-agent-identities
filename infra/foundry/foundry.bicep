targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string

@description('Name of the Azure Foundry resource')
param foundryName string

@description('Name of the existing Key Vault Resource')
param keyVaultName string

@description('Name of the existing Storage Account Resource')
param storageAccountName string

@description('Name of the existing Application Insights resource')
param appInsightsName string

param sku object = {
  name: 'S0'
}
param disableLocalAuth bool = false

param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules)
  ? {
      defaultAction: 'Allow'
    }
  : {
      ipRules: allowedIpRules
      defaultAction: 'Deny'
    }

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryName
  location: location
  sku: sku
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    networkAcls: networkAcls
    disableLocalAuth: disableLocalAuth
  }
}

resource aiServiceConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'aoai-connection'
  parent: account
  properties: {
    category: 'AzureOpenAI'
    authType: 'AAD'
    isSharedToAll: true
    target: account.properties.endpoints['OpenAI Language Model Instance API']
    metadata: {
      ApiType: 'azure'
      ResourceId: account.id
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Creates the Azure Foundry connection to your Azure App Insights resource
resource appInsightConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'app-insight-connection'
  parent: account
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights.properties.InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Creates the Azure Foundry connection to your Azure Storage resource
resource storageAccountConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  name: 'storage-account-connection'
  parent: account
  properties: {
    category: 'AzureStorageAccount'
    target: storageAccount.properties.primaryEndpoints.blob
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: storageAccount.id
    }
  }
}

output foundryName string = account.name
output foundryId string = account.id
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output appInsightsName string = appInsights.name
