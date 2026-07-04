# Phase 1 Data Model: Web App for Alias Management

The web app introduces **no new stored entities**. It presents and mutates the
existing `Alias` records from feature 001 and relies on the identity provided by
Easy Auth.

## Reused: Alias (view)

As defined in `specs/001-alias-management/data-model.md` — `address`, `site`,
`status`, `createdUtc`, `assignedUtc`, `note`. The UI shows active/disabled
aliases and triggers create/disable/enable.

## Transient: Client principal (not stored)

Provided per-request by Easy Auth; used only for authorization.

| Field | Source | Use |
|-------|--------|-----|
| principal name (UPN) | `X-MS-CLIENT-PRINCIPAL-NAME` header | Compared to `OWNER_UPN`; request allowed only if it matches. |

## New alias-generation option

- **Speakable format**: a request option on alias creation selecting a word-based
  local part instead of the default base32. Affects only how the address string
  is generated; the resulting `Alias` record is otherwise identical.
