// aliasaurus infrastructure (V1 control plane).
// Deploys the Functions app, ledger storage, and least-privilege role assignment.
// No secrets: the Function App authenticates with a system-assigned managed identity.

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Base name for resources (lowercase, 3-11 chars).')
@minLength(3)
@maxLength(11)
param appName string = 'aliasaurus'

@description('The custom domain used for aliases, e.g. example.com')
param aliasDomain string

@description('The Microsoft 365 organization, e.g. example.onmicrosoft.com')
param organization string

@description('Primary mailbox that alias mail is delivered to.')
param primaryMailbox string

@description('Comma-separated intake shared mailbox UPNs.')
param intakeMailboxes string

@description('Comma-separated graveyard shared mailbox UPNs.')
param graveyardMailboxes string

@description('The owner UPN allowed to use the app (Easy Auth).')
param ownerUpn string

@description('Entra app (client) ID for Easy Auth. Leave empty to skip enabling Easy Auth.')
param authClientId string = ''

var storageName = toLower('${appName}${uniqueString(resourceGroup().id)}')
var ledgerTableName = 'aliases'
// Built-in role: Storage Table Data Contributor.
var tableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource ledgerTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  parent: tableService
  name: ledgerTableName
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${appName}-plan'
  location: location
  // Y1 = Consumption. Note: the Exchange Online module has cold-start overhead;
  // switch to an Elastic Premium (EP1) plan if interactive latency matters (see ADR-0002).
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${appName}-func'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PowerShell|7.4'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'powershell' }
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'ALIAS_DOMAIN', value: aliasDomain }
        { name: 'M365_ORGANIZATION', value: organization }
        { name: 'PRIMARY_MAILBOX', value: primaryMailbox }
        { name: 'OWNER_UPN', value: ownerUpn }
        { name: 'INTAKE_MAILBOXES', value: intakeMailboxes }
        { name: 'GRAVEYARD_MAILBOXES', value: graveyardMailboxes }
        { name: 'LEDGER_STORAGE_ACCOUNT', value: storage.name }
        { name: 'LEDGER_TABLE', value: ledgerTableName }
        { name: 'POOL_TARGET', value: '25' }
        { name: 'POOL_LOW_WATER', value: '10' }
        { name: 'MAX_PROXIES_PER_MAILBOX', value: '300' }
      ]
    }
  }
}

// Least-privilege data-plane access to the ledger storage account (Principle III).
resource tableRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, functionApp.id, tableDataContributorRoleId)
  scope: storage
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', tableDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Easy Auth (App Service Authentication) with Entra, requiring sign-in.
resource authSettings 'Microsoft.Web/sites/config@2023-12-01' = if (!empty(authClientId)) {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          openIdIssuer: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${authClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

output functionAppName string = functionApp.name
output functionPrincipalId string = functionApp.identity.principalId
output storageAccountName string = storage.name
