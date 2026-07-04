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

## CI/CD

Two GitHub Actions workflows drive delivery, plus adopted org workflows:

- **`ci-cd.yml`** (single pipeline):
  - **test** job on every PR and push to `main`: Pester unit tests,
    PSScriptAnalyzer, and `az bicep build`.
  - **deploy** job on version tags (`v*`, created by release-please) or manual
    dispatch: logs in to Azure via **OIDC + the Azure CLI** (no stored
    credentials, no `azure/*` actions), deploys `infra/main.bicep`, and
    zip-deploys the Functions app.
- **`lint.yml`**, **`config-sync.yml`**, **`release-please.yml`**: adopted
  DevSecNinja reusable workflows.

### Required repository configuration for deploy

Set these as repository **variables** (Settings → Secrets and variables →
Actions → Variables), and configure an Entra app with a **federated credential**
trusting this repo's `production` environment:

| Variable                                                                                          | Example                    |
| ------------------------------------------------------------------------------------------------- | -------------------------- |
| `AZURE_CLIENT_ID`                                                                                 | app registration client ID |
| `AZURE_TENANT_ID`                                                                                 | tenant ID                  |
| `AZURE_SUBSCRIPTION_ID`                                                                           | subscription ID            |
| `AZURE_RESOURCE_GROUP`                                                                            | `aliasaurus-rg`            |
| `AZURE_FUNCTION_APP`                                                                              | `aliasaurus-func`          |
| `ALIAS_DOMAIN`, `M365_ORGANIZATION`, `PRIMARY_MAILBOX`, `INTAKE_MAILBOXES`, `GRAVEYARD_MAILBOXES` | deploy parameters          |

release-please additionally uses the org-provided `RELEASE_PLEASE_APP_ID`
variable and `RELEASE_PLEASE_APP_PRIVATE_KEY` secret.

## Local development

```sh
cp src/functions/local.settings.json.example src/functions/local.settings.json
# edit values; local.settings.json is git-ignored
mise run test    # Pester unit tests
mise run lint    # PSScriptAnalyzer
```
