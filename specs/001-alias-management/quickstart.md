# Quickstart & Validation: Disposable Per-Site Email Aliases (V1)

This guide proves the V1 feature works end to end. It is a validation runbook,
not implementation code. See [plan.md](./plan.md), [research.md](./research.md),
[data-model.md](./data-model.md), and [contracts/control-api.yaml](./contracts/control-api.yaml).

## Prerequisites

- A Microsoft 365 tenant with a verified custom domain and a primary mailbox.
- An Azure subscription for the Functions app and Table Storage.
- Two unlicensed shared mailboxes: an **intake** mailbox and a **graveyard**
  mailbox (created ahead of time so they are warm).
- Tooling provisioned via mise (`mise install`).
- No secrets: the Function app uses a system-assigned managed identity.

## One-time setup

1. **Deploy infrastructure** (`infra/main.bicep`): Function App (PowerShell),
   Storage account with the `aliases` table, and the system-assigned managed
   identity.
2. **Grant least-privilege access to the managed identity**:
   - A custom Exchange management role scoped to the cmdlets used
     (`Set-Mailbox`, `Get-Mailbox`, and the mail-flow rule cmdlets), assigned via
     `Exchange.ManageAsApp` to the MI. No broad admin role.
   - A Table Storage data role scoped to the `aliases` table.
3. **Configure mail routing**:
   - Set the intake mailbox to forward to the primary mailbox.
   - Create the graveyard mail-flow rule: recipient is the graveyard mailbox →
     action **Delete the message without notifying anyone**.
4. **Set configuration**: intake/graveyard mailbox UPNs, custom domain, pool
   target size, and low-water mark.

## Validation scenarios

### V1-A — Instant issuance (User Story 1 / FR-011, FR-014, SC-001, SC-002)

1. Ensure the pool is warm: trigger `ReplenishPool`; confirm `pool` rows exist.
2. `POST /aliases {"site":"example-shop"}` → expect `201` with an `active` alias.
3. From an external account, email that alias.
4. **Expected**: message arrives in the primary inbox on the first attempt with
   no provisioning wait; the receiving alias is visible in the To header.

### V1-B — Uniqueness & non-guessability (FR-002)

1. Issue two aliases for `"example-shop"`.
2. **Expected**: two distinct addresses; neither contains the raw site name; the
   local parts are random.

### V1-C — Disable is a silent drop (User Story 2 / FR-006, FR-007, SC-003)

1. `POST /aliases/{address}/disable` for an active alias.
2. Email the disabled alias from an external account, and email a different
   still-active alias.
3. **Expected**: no message to the disabled alias reaches the inbox and **no
   bounce/NDR** is returned to the sender; the message to the other alias is
   delivered normally.

### V1-D — Re-enable (FR-008)

1. `POST /aliases/{address}/enable` for the disabled alias.
2. Email it again.
3. **Expected**: delivery to the inbox resumes.

### V1-E — Inventory & attribution (User Story 3 / FR-005, FR-009, SC-004, SC-005)

1. `GET /aliases`.
2. **Expected**: every active/disabled alias is listed with site, status, and
   creation date (pool entries are not shown); a received message's address can
   be looked up to identify its site.

### V1-F — Capacity handling (FR-013, pool-depletion edge case)

1. Simulate an intake mailbox near the 300-proxy limit.
2. **Expected**: issuance either spills to another intake mailbox or reports
   capacity exhaustion (`507`); it never fails silently. With an empty pool,
   issuance falls back to on-demand creation.

## Automated tests

- **Unit (Pester)**: alias generation (non-guessable, unique), ledger state
  transitions, pool low-water logic.
- **Integration (Pester, gated)**: create/disable/enable against a test intake
  and graveyard mailbox; verify silent drop and forwarding.
