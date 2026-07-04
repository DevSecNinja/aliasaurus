# Phase 1 Data Model: Disposable Per-Site Email Aliases (V1)

Metadata only. No message bodies, headers, or attachments are ever stored
(Constitution Principle II).

## Entity: Alias (ledger record)

Stored in Azure Table Storage table `aliases`.

- **PartitionKey**: intake domain (e.g. `example.com`).
- **RowKey**: the full alias address (e.g. `k7m2q9x4rt5v@example.com`) — unique.

| Field | Type | Notes |
|-------|------|-------|
| `address` | string | The alias SMTP address (mirrors RowKey). |
| `site` | string | Human label for where the alias is used. Not unique; null while the entry is a warm-pool entry. |
| `status` | enum | `pool` \| `active` \| `disabled`. |
| `hostMailbox` | string | UPN of the mailbox currently holding the proxy (intake or graveyard). |
| `createdUtc` | datetime | When the proxy address was created (warming start). |
| `assignedUtc` | datetime? | When issued to a site (pool → active). |
| `disabledUtc` | datetime? | Last time it was disabled. |
| `note` | string? | Optional free-text note. |

### State transitions

```text
(created, warming)                → status = pool      (on intake mailbox, no site)
pool      --issue to site-->        status = active     (site set, assignedUtc set)
active    --disable-->              status = disabled   (proxy moved to graveyard)
disabled  --enable-->               status = active     (proxy moved back to intake)
```

Rules:
- An `active` or `disabled` alias MUST have a non-null `site`.
- `RowKey`/`address` MUST be unique across the table (FR-002, FR-012).
- Only `pool` entries may be selected for issuance (FR-011/FR-014).

## Entity: Site/Context

Not stored as its own row; represented by the `site` string on Alias records.
Multiple aliases may share a `site` value (duplicate creation is allowed).

## Entity: Mailbox (operational, not user-managed)

Derived from Exchange, not stored in the ledger beyond `hostMailbox`.

- **Intake mailbox(es)**: unlicensed shared mailbox holding `pool` and `active`
  proxy addresses; forwards to the user's primary mailbox.
- **Graveyard mailbox(es)**: unlicensed shared mailbox holding `disabled` proxy
  addresses; a mail-flow rule deletes all mail without notifying anyone.
- Each mailbox is bounded by the 300-proxy-address limit; additional mailboxes
  are provisioned when a mailbox nears capacity (FR-013).

## Derived views

- **Inventory** (FR-005, User Story 3): all rows where `status` in
  {`active`,`disabled`}, projected to `address`, `site`, `status`, `createdUtc`.
- **Pool health** (FR-014): count of rows where `status = pool` per intake
  mailbox, compared against the configured low-water mark.
