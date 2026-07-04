# 2. Server-less Azure Functions control plane with managed identity

- Status: accepted
- Date: 2026-07-04
- Deciders: @DevSecNinja

## Context and Problem Statement

ADR-0001 established that Microsoft 365 / Exchange Online is the sole mail
transport and that aliasaurus contributes only a control plane. That control
plane must perform privileged Exchange Online operations (add proxy addresses,
move them between mailboxes, manage forwarding and mail-flow rules) and maintain
an alias metadata ledger, on a recurring and on-demand basis.

We need to decide where this control plane runs and how it authenticates to
Exchange Online, Microsoft Graph, and its ledger store, while honoring the
constitution's principles of a stateless, server-less design (II) and
least-privilege, secret-free authentication (III).

## Decision Drivers

- No stored secrets (Principle III): passwords, client secrets, and application
  certificates managed by us are disallowed.
- Least privilege: the identity must be scopable to only the operations needed.
- Server-less and stateless (Principle II): no always-on servers to operate; no
  message contents persisted.
- Fits both event/HTTP-driven work (issue/disable/enable/list) and scheduled work
  (pre-warm pool replenishment).
- Publicly hosted repository: minimize anything that could leak credentials.

## Considered Options

1. **Azure Functions with a system-assigned managed identity.** HTTP triggers for
   the control API, a timer trigger for pool replenishment; connect to Exchange
   Online via `Connect-ExchangeOnline -ManagedIdentity` and to Graph and Table
   Storage with the same identity.
2. **Azure Automation runbooks with a managed identity.** Similar auth model;
   strong for scheduled PowerShell and mature Exchange module handling, but a
   weaker fit for a low-latency HTTP control API.
3. **A container/VM service (e.g. Container Apps) running a small API.** Full
   control, but reintroduces an always-on component and more to operate, working
   against Principle II.
4. **App registration with a client secret or certificate.** Common pattern, but
   requires storing and rotating a secret/cert, violating Principle III.

## Decision Outcome

Chosen option: **Option 1, Azure Functions with a system-assigned managed
identity.**

The control plane is an Azure Functions (PowerShell) app: HTTP-triggered
functions for issue/list/disable/enable and a timer-triggered function for
pre-warm pool replenishment. Authentication to Exchange Online uses
`Connect-ExchangeOnline -ManagedIdentity`; Microsoft Graph reads and Azure Table
Storage access use the same managed identity. The identity is granted a **custom
Exchange management role scoped to only the cmdlets used** (via
`Exchange.ManageAsApp`) and a **Table Storage data role scoped to the ledger
table** — never a broad admin role.

### Consequences

Good:

- No secrets exist to store, rotate, or leak from a public repository.
- Server-less and stateless; nothing always-on to operate; no message contents
  stored (only alias metadata in the ledger).
- One model covers both HTTP and scheduled workloads.
- RBAC can be tightened to the minimum surface area.

Bad / accepted trade-offs:

- The Exchange Online PowerShell module has meaningful connection/cold-start
  overhead on Consumption plans; mitigate with a Premium/always-ready plan or by
  concentrating Exchange work in the timer function. If cold start proves
  problematic for interactive operations, Azure Automation (Option 2) is the
  documented fallback for the Exchange-heavy paths.
- Requires assigning the `Exchange.ManageAsApp` permission and a custom RBAC role
  to the managed identity as a setup prerequisite.

## More Information

- Implements the control plane described in
  `specs/001-alias-management/plan.md` and `research.md` (Decision 5).
- Related: ADR-0001 (Microsoft 365 as the sole mail transport).
