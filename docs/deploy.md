# Deploying aliasaurus (V1)

End-to-end setup. See also `infra/exchange-prereqs.md` and the feature
validation guide `specs/001-alias-management/quickstart.md`.

## Prerequisites

- An Azure subscription and an Microsoft 365 tenant with a verified custom domain.
- Tooling via mise: `mise install`.
- Azure CLI (`az`) and the Bicep CLI.
- The `ExchangeOnlineManagement` PowerShell module (for the one-time Exchange setup).

## 1. Deploy Azure infrastructure

```sh
az group create --name aliasaurus-rg --location westeurope

az deployment group create \
  --resource-group aliasaurus-rg \
  --template-file infra/main.bicep \
  --parameters \
      aliasDomain=example.com \
      organization=example.onmicrosoft.com \
      primaryMailbox=you@example.com \
      intakeMailboxes=intake@example.com \
      graveyardMailboxes=graveyard@example.com
```

Note the outputs: `functionAppName`, `functionPrincipalId`, `storageAccountName`.

## 2. Configure Exchange Online (one-time)

Run the idempotent setup script as an Exchange administrator, using the managed
identity's app ID and object ID:

```powershell
./scripts/Setup-ExchangePrereqs.ps1 `
    -Organization example.onmicrosoft.com `
    -PrimaryMailbox you@example.com `
    -IntakeMailbox intake@example.com `
    -GraveyardMailbox graveyard@example.com `
    -ManagedIdentityAppId '<app-id>' `
    -ManagedIdentityObjectId '<functionPrincipalId>'
```

## 3. Deploy the function app

```sh
cd src/functions
func azure functionapp publish <functionAppName>
```

## 4. Validate

Trigger `ReplenishPool` to warm the pool, then run through the scenarios in
`specs/001-alias-management/quickstart.md` (V1-A through V1-F).

## Local development

```sh
cp src/functions/local.settings.json.example src/functions/local.settings.json
# edit values; local.settings.json is git-ignored
mise run test    # Pester unit tests
mise run lint    # PSScriptAnalyzer
```
