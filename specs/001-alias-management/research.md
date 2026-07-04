# Phase 0 Research: Disposable Per-Site Email Aliases (V1)

All decisions keep Microsoft 365 / Exchange Online as the sole mail transport
(Constitution Principle I) and avoid persisting message contents (Principle II).

## Decision 1 — Alias representation: proxy addresses on a shared mailbox

- **Decision**: Each alias is a secondary SMTP (proxy) address added to a
  dedicated, unlicensed **intake shared mailbox** via
  `Set-Mailbox -EmailAddresses @{add="<random>@domain"}`. Local parts are random
  and non-guessable (see Decision 6).
- **Rationale**: Proxy addresses are the native Exchange alias mechanism; a
  shared mailbox needs no license; all alias mail converges to one place we
  control; changes are scriptable and readable via Graph (`proxyAddresses`).
- **Alternatives considered**:
  - _Plus addressing_ — guessable (a spammer strips `+tag`); fails FR-002.
  - _Catch-all_ — no per-address control and invites dictionary spam; rejected.
  - _One mailbox/contact/distribution group per alias_ — heavy, and Graph cannot
    create mail-enabled security groups/distribution lists; excessive overhead.

## Decision 2 — Delivery to the primary inbox: mailbox forwarding

- **Decision**: The intake mailbox forwards all mail to the user's primary
  mailbox (`Set-Mailbox -ForwardingAddress <primary> -DeliverToMailboxAndForward
  $false`), so alias mail arrives in the normal inbox. The receiving alias is
  visible in the message's To/Delivered-To header and mapped to a site via the
  ledger (FR-009).
- **Rationale**: Single inbox experience with no per-message compute; transport
  stays entirely within Exchange Online.
- **Alternatives**: User opens the intake mailbox as a separate account (extra
  step); Graph-driven per-message forwarding (unnecessary compute for V1).

## Decision 3 — Disable semantics: silent drop via a graveyard mailbox

- **Decision**: Disabling an alias **moves** its proxy address from the intake
  mailbox to a **graveyard shared mailbox** that has an org mail-flow rule (or
  mailbox rule) using the **"Delete the message without notifying anyone"**
  action. Mail to disabled aliases is accepted and silently deleted (no NDR).
  Re-enabling moves the proxy back to the intake mailbox (FR-006, FR-007, FR-008).
- **Rationale**: Satisfies the spec's silent-drop / no-bounce requirement without
  confirming address existence, isolates each alias, and scales without
  per-alias rules. Verified: the "Delete the message without notifying anyone"
  mail-flow action exists in Exchange Online.
- **Alternatives**:
  - _Remove the proxy address_ — makes the address unknown, producing an NDR;
    violates the spec's silent-drop assumption.
  - _Per-alias transport/inbox rules_ — hit Exchange rule count/size limits and
    do not scale to hundreds of aliases.
- **Trade-offs / open items**: The 300-proxy cap also applies to the graveyard
  mailbox (add more as needed). Proxy moves are subject to directory propagation,
  so a disable may take minutes to fully take effect; acceptable because disable
  is not latency-critical.

## Decision 4 — Instant issuance: a pre-warmed pool

- **Decision**: A timer-triggered function maintains a pool of **pre-created,
  aged, unassigned** proxy addresses on the intake mailbox. Issuing an alias to a
  site selects a warmed address and labels it in the ledger — no waiting. If the
  pool is empty, fall back to on-demand creation (accepting possible delay) and
  flag it (FR-011, FR-014, pool-depletion edge case).
- **Rationale**: Exchange proxy-address propagation can take up to 24h; warming
  ahead guarantees the alias is active on first use (SC-002).
- **Alternatives**: Pure on-demand creation (fails instant-usability); very large
  static pre-allocation (wastes the 300 cap).
- **Parameters**: target pool size and low-water mark are configuration.

## Decision 5 — Auth & hosting: Azure Functions + managed identity

- **Decision**: Azure Functions (PowerShell worker). HTTP-triggered functions for
  create/list/disable/enable; a timer trigger for pool replenishment. Connect to
  Exchange Online with `Connect-ExchangeOnline -ManagedIdentity`, and read Graph
  with the same identity. The MI is granted a **custom Exchange management role**
  scoped to only the cmdlets used (e.g. `Set-Mailbox`, `Get-Mailbox`), never a
  broad admin role, plus a scoped Table Storage data role.
- **Rationale**: No stored secrets (Principle III); server-less (Principle II).
  Verified: EXO PowerShell supports managed-identity auth.
- **Alternatives**: Azure Automation runbooks (viable; noted as fallback given
  EXO module cold-start cost); app registration with a client secret/cert
  (rejected — stored secret).
- **Trade-off**: The EXO module has meaningful cold-start/connection overhead;
  mitigate with a Premium/always-ready plan or move EXO-heavy work to a timer.

## Decision 6 — Non-guessable local parts

- **Decision**: Generate local parts as a random 12-character lowercase base32
  string (optionally with a short human hint prefix that is NOT the raw site
  name), e.g. `k7m2q9x4rt5v@domain`. Site association lives only in the ledger.
- **Rationale**: Prevents reconstructing other aliases or the primary address
  from a single leaked alias (FR-002, look-alike edge case).
- **Alternatives**: Site-name-derived addresses (guessable; rejected).

## Decision 7 — Ledger storage: Azure Table Storage

- **Decision**: Azure Table Storage table `aliases`, `PartitionKey` = intake
  domain, `RowKey` = alias address. See data-model.md.
- **Rationale**: Cheap, server-less, key-value lookups by alias; sufficient for
  single-user scale. Holds metadata only, never message contents.
- **Alternatives**: Cosmos DB (overkill/cost); a mailbox folder as a store
  (fragile).

## Cross-cutting

The server-less Functions + managed-identity control-plane choice is a
cross-cutting architectural decision recorded in **ADR-0002**.
