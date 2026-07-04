# Exchange Online prerequisites (V1)

aliasaurus performs Exchange changes from an Azure Functions **managed identity**.
These one-time steps grant that identity least-privilege access and set up the
intake/graveyard mailboxes and mail routing. Run them once per tenant, after
`infra/main.bicep` is deployed (so the managed identity exists).

> No secrets are stored. The Function App's managed identity is granted an
> app-only Exchange role scoped to only the cmdlets aliasaurus uses.

## What gets created

1. **Intake shared mailbox** (unlicensed): holds warm-pool and active alias proxy
   addresses; forwards all mail to your primary mailbox.
2. **Graveyard shared mailbox** (unlicensed): holds disabled alias proxy
   addresses; a mail-flow rule silently deletes everything sent to it.
3. **Mail-flow rule**: "Delete the message without notifying anyone" for mail to
   the graveyard mailbox (silent drop, no NDR).
4. **Custom management role**: scoped to `Set-Mailbox` and `Get-Mailbox`, assigned
   to the managed identity via a service principal in Exchange (`New-ServicePrincipal`
   + `New-ManagementRoleAssignment`).

## Prerequisites

- The `ExchangeOnlineManagement` module (`Install-Module ExchangeOnlineManagement`).
- The managed identity's **object (principal) ID** and **application ID**
  (from the `infra` deployment output / Entra).

## Run

```powershell
./scripts/Setup-ExchangePrereqs.ps1 `
    -Organization       'example.onmicrosoft.com' `
    -PrimaryMailbox     'you@example.com' `
    -IntakeMailbox      'intake@example.com' `
    -GraveyardMailbox   'graveyard@example.com' `
    -ManagedIdentityAppId     '<app-id-guid>' `
    -ManagedIdentityObjectId  '<object-id-guid>'
```

The script is idempotent: it skips resources that already exist.

## Notes

- The 300-proxy-address limit applies per mailbox. Provision additional intake or
  graveyard shared mailboxes and add them to `INTAKE_MAILBOXES` /
  `GRAVEYARD_MAILBOXES` when a mailbox nears the limit.
- Sending *as* an alias (`SendFromAliasEnabled`) is not required for V1 (aliases
  are receive-only) and is deferred to V2.
