# Implementation Plan: Disposable Per-Site Email Aliases (Receive & Manage)

**Branch**: `001-alias-management` | **Date**: 2026-07-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-alias-management/spec.md`

## Summary

V1 delivers on-demand, instantly usable, non-guessable per-site email aliases on
the user's own domain, backed entirely by Exchange Online. Each alias is a
secondary SMTP (proxy) address on a dedicated unlicensed **intake** shared
mailbox that forwards to the user's primary inbox. Disabling an alias moves its
proxy address to a **graveyard** shared mailbox whose mail-flow rule silently
deletes all mail (no bounce), and re-enabling moves it back. A background timer
keeps a **pre-warmed pool** of aged proxy addresses so issuance is instant. A
stateless Azure Functions (PowerShell) control plane performs all Exchange
changes via a **managed identity** with a least-privilege custom RBAC role, and
records alias metadata in an **Azure Table Storage ledger**. Reads use Microsoft
Graph plus the ledger. aliasaurus never relays or stores mail.

## Technical Context

**Language/Version**: PowerShell 7.4 (Azure Functions PowerShell worker)

**Primary Dependencies**: ExchangeOnlineManagement (EXO V3, app-only / managed
identity), Microsoft Graph (REST or Graph PowerShell) for reads, Azure Functions
runtime, Azure.Data.Tables. IaC in Bicep.

**Storage**: Azure Table Storage (alias ledger + pool state). No message bodies
are ever stored.

**Testing**: Pester (unit + integration) for the PowerShell module and functions.

**Target Platform**: Azure Functions (Linux) with a system-assigned managed
identity; Exchange Online + Azure Table Storage as backing services.

**Project Type**: Serverless backend control plane + IaC (no UI in V1; a thin
client is future work).

**Performance Goals**: Alias issuance < 30s end-to-end (SC-001), served from the
warm pool so the alias is active on first use (SC-002, FR-011/FR-014). Pool
replenishment runs on a timer, ahead of demand.

**Constraints**: No stored secrets (managed identity only); least-privilege RBAC;
≤ 300 proxy addresses per mailbox (spill to additional shared mailboxes); silent
drop for disabled/unknown addresses (no NDR); stateless components.

**Scale/Scope**: Single user, single custom domain, one primary mailbox.
Hundreds to low-thousands of aliases spread across a small set of shared
mailboxes.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

| Principle                                | Status  | Notes                                                                                                                                         |
| ---------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| I. M365-Native Mail Transport            | ✅ PASS | Exchange Online is the sole transport; no SMTP relay; no third party. Delivery via shared-mailbox forwarding; disable via EXO mail-flow rule. |
| II. Stateless, Server-less Control Plane | ✅ PASS | Azure Functions only; Table Storage holds alias metadata only; message bodies never persisted.                                                |
| III. Least-Privilege Managed Identity    | ✅ PASS | System-assigned MI; custom Exchange RBAC role scoped to the cmdlets used; Table Storage data-plane role scoped to the ledger. No secrets.     |
| IV. Spec-First & ADR-Backed              | ✅ PASS | Plan derives from approved spec; cross-cutting infra decision recorded in ADR-0002.                                                           |
| V. Reproducible, Pinned Tooling          | ✅ PASS | mise-pinned tooling, Bicep IaC, pinned module versions, Renovate; spaces for indentation.                                                     |

**Post-design re-check**: ✅ PASS — no new violations introduced by the Phase 1
design; no entries required in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-alias-management/
├── plan.md              # This file
├── research.md          # Phase 0: decisions + rationale
├── data-model.md        # Phase 1: ledger + entities
├── quickstart.md        # Phase 1: end-to-end validation guide
├── contracts/
│   └── control-api.yaml # Phase 1: control-plane HTTP contract (OpenAPI)
└── tasks.md             # Phase 2: created by /speckit.tasks
```

### Source Code (repository root)

```text
src/
└── functions/                 # Azure Functions app (PowerShell)
    ├── host.json
    ├── profile.ps1            # connects to EXO/Graph via managed identity
    ├── requirements.psd1      # pinned module versions
    ├── CreateAlias/           # HTTP: issue an alias for a site (from pool)
    ├── ListAliases/           # HTTP: inventory (ledger + Graph)
    ├── SetAliasState/         # HTTP: disable / enable an alias
    ├── ReplenishPool/         # Timer: warm and top up the pool
    └── modules/
        └── Aliasaurus/        # shared PS module: EXO ops, ledger, alias gen

infra/                         # Bicep: Function App, Storage/Table, MI, RBAC
└── main.bicep

tests/
├── unit/                      # Pester unit tests (alias gen, ledger logic)
└── integration/               # Pester integration tests (EXO/Table, gated)
```

**Structure Decision**: Single serverless backend project. All alias operations
live in one Functions app plus a shared PowerShell module; infrastructure is
Bicep. No frontend/mobile split is needed in V1 (the contract is an HTTP API).

## Complexity Tracking

> No constitution violations. Section intentionally empty.
