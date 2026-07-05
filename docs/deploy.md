# Deploying aliasaurus (V1)

End-to-end setup. See also `infra/exchange-prereqs.md` and the feature
validation guide `specs/001-alias-management/quickstart.md`.

> [!NOTE]
> aliasaurus is a proof of concept and is not in production use. These steps are
> provided for completeness and experimentation.

The setup has two parts:

1. **[Setup required regardless of how you deploy](#part-1--setup-required-regardless-of-deploy-method)**
   — Azure infrastructure, Exchange Online configuration, and (for the web app)
   an Entra app registration. These describe _what_ must exist in your tenant.
2. **Getting the code deployed** — pick one:
   - **[Option A: Deploy via CI/CD](#option-a-deploy-via-cicd-recommended)** (recommended)
   - **[Option B: Deploy manually](#option-b-deploy-manually)**

## Prerequisites

- An Azure subscription and a Microsoft 365 tenant with a verified custom domain.
- Tooling via mise: `mise install`.
- Azure CLI (`az`) and the Bicep CLI (for manual deploy, or local Bicep work).
- The `ExchangeOnlineManagement` PowerShell module (for the one-time Exchange setup).

## Part 1 — Setup required regardless of deploy method

These resources must exist in your tenant no matter whether you deploy through
CI/CD or manually. CI/CD automates the two Azure steps (infrastructure + app
code); the Exchange and Entra steps below are always one-time manual actions.

### 1a. Azure infrastructure

The `infra/main.bicep` template provisions the Function App (with a
system-assigned managed identity), storage, the ledger table, and the
least-privilege role assignment. It is applied automatically by CI/CD (Option A)
or by hand (Option B, step 1).

Outputs to note for the Exchange step: `functionAppName`, `functionPrincipalId`,
`storageAccountName`.

### 1b. Configure Exchange Online (one-time, always manual)

Run the idempotent setup script as an Exchange administrator, using the managed
identity's app ID and object ID (from the infra deployment / Entra):

```powershell
./scripts/Setup-ExchangePrereqs.ps1 `
    -Organization example.onmicrosoft.com `
    -PrimaryMailbox you@example.com `
    -IntakeMailbox intake@example.com `
    -GraveyardMailbox graveyard@example.com `
    -ManagedIdentityAppId '<app-id>' `
    -ManagedIdentityObjectId '<functionPrincipalId>'
```

### 1c. Entra app for the web app (Easy Auth, one-time, always manual)

The web UI is served from the Function App root and protected by App Service
Authentication (Easy Auth):

1. Register an Entra application; add the redirect URI
   `https://<app>.azurewebsites.net/.auth/login/aad/callback`.
2. Provide the `authClientId` (the Entra app's client ID) and `ownerUpn` (your
   sign-in address) as deployment parameters. Easy Auth then requires sign-in,
   and the API additionally enforces that the caller is the owner.

## Option A: Deploy via CI/CD (recommended)

Delivery is driven by GitHub Actions:

- **`ci-cd.yml`** (single pipeline):
  - **test** — runs on every PR and push to `main`: Pester unit tests,
    PSScriptAnalyzer, and `az bicep build`.
  - **deploy** — runs on version tags (`v*`, created by release-please) or manual
    dispatch: logs in to Azure via **OIDC + the Azure CLI** (no stored
    credentials, no `azure/*` actions), applies `infra/main.bicep` (Part 1a), and
    zip-deploys the Functions app.
- **`lint.yml`**, **`config-sync.yml`**, **`release-please.yml`** — adopted
  DevSecNinja reusable workflows.

So with CI/CD you only perform the always-manual steps (1b Exchange, 1c Entra);
the Azure infrastructure and app code deploy automatically.

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

To cut a release, merge the release-please PR; the resulting `v*` tag triggers the
deploy job. You can also run the workflow via **Run workflow** (manual dispatch).

## Option B: Deploy manually

Use this if you are not wiring up CI/CD.

### 1. Deploy Azure infrastructure (Part 1a, by hand)

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
      graveyardMailboxes=graveyard@example.com \
      ownerUpn=you@example.com \
      authClientId=<entra-app-client-id>
```

Note the outputs: `functionAppName`, `functionPrincipalId`, `storageAccountName`.

### 2. Deploy the function app

```sh
cd src/functions
func azure functionapp publish <functionAppName>
```

Complete the Exchange (1b) and Entra (1c) one-time steps before first real use.

## Validate

Trigger `ReplenishPool` to warm the pool, then run through the scenarios in
`specs/001-alias-management/quickstart.md` (V1-A through V1-F) and
`specs/002-web-app/quickstart.md` (W-A through W-E).

## Local development

No Azure or M365 is needed for day-to-day development or to preview the UI.

```sh
cp src/functions/local.settings.json.example src/functions/local.settings.json
# edit values; local.settings.json is git-ignored
mise run test    # Pester unit tests
mise run lint    # PSScriptAnalyzer
mise run dev     # local mock preview at http://localhost:7071
```

### Preview the web UI locally (no Azure/M365)

`mise run dev` starts a mock server that serves the real SPA and implements the
`/aliases` API with an in-memory store, reusing the actual module logic (alias
generation, warm pool, state transitions, speakable format). It needs no Azure,
Exchange Online, Table Storage, or Easy Auth — ideal for seeing the UI before
provisioning production. It is a preview only: data is in-memory and Exchange
operations are not performed.

Locally, set `AZURE_FUNCTIONS_ENVIRONMENT=Development` to bypass the owner check
when running the actual Functions host (Easy Auth is not present locally).
