# Feature Specification: Disposable Per-Site Email Aliases (Receive & Manage)

**Feature Branch**: `001-alias-management`

**Created**: 2026-07-04

**Status**: Draft

**Input**: User description: "V1 receive-and-manage: create disposable per-site email aliases, track them in a ledger, and disable them"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a disposable alias for a site (Priority: P1)

When signing up to a website or service, the user creates a brand-new, unique
email address dedicated to that site. Mail sent to that address is delivered to
the user's normal inbox, and the user records which site the address belongs to.

**Why this priority**: This is the core capability and the minimum viable
product. Without on-demand unique addresses that actually receive mail, nothing
else in the feature has value.

**Independent Test**: Create an alias for a named site, send a test message to
it from an external account, and confirm it arrives in the user's inbox and is
attributable to that site. Delivers value on its own (per-site addresses).

**Acceptance Scenarios**:

1. **Given** the user wants to register at "example-shop", **When** they request
   a new alias for that site, **Then** they receive a unique address on their
   own domain that is immediately usable.
2. **Given** an active alias for "example-shop", **When** an external sender
   emails that address, **Then** the message is delivered to the user's primary
   inbox.
3. **Given** the user creates a second alias for the same site, **When** the
   alias is generated, **Then** it is a distinct address from the first.

---

### User Story 2 - Disable an alias that receives spam (Priority: P2)

When an alias starts receiving spam or unwanted mail, the user disables that
single address. Future mail to it stops reaching the inbox, while every other
alias and the primary address keep working.

**Why this priority**: This is the payoff of the whole approach: isolating and
killing a leaked or abused address without collateral damage. It is the primary
reason the user is not using plus addressing or a catch-all.

**Independent Test**: Disable an existing alias, then send a message to it and
confirm it does not reach the inbox, while a message to a different alias still
does.

**Acceptance Scenarios**:

1. **Given** an active alias receiving spam, **When** the user disables it,
   **Then** subsequent mail to that address is no longer delivered to the inbox.
2. **Given** one alias has been disabled, **When** mail is sent to a different,
   still-active alias, **Then** that mail is delivered normally.
3. **Given** a disabled alias, **When** the user chooses to re-enable it,
   **Then** mail to that address is delivered to the inbox again.

---

### User Story 3 - See where every alias is used (Priority: P3)

The user reviews a complete inventory of their aliases showing which site each
belongs to, when it was created, its current status, and any notes. This lets
them audit where they have registered and identify which site leaked an address.

**Why this priority**: The inventory turns a pile of addresses into an auditable
record. It is valuable but depends on aliases existing first, so it follows
creation and disabling.

**Independent Test**: After creating and disabling several aliases, request the
inventory and confirm it lists each alias with its site, status, and creation
date accurately.

**Acceptance Scenarios**:

1. **Given** several aliases have been created, **When** the user views the
   inventory, **Then** each alias is listed with its associated site, creation
   date, and status.
2. **Given** an alias has been disabled, **When** the user views the inventory,
   **Then** that alias is shown as disabled.
3. **Given** the user received an unwanted message, **When** they look up the
   receiving address in the inventory, **Then** they can identify the site the
   address was created for.

---

### Edge Cases

- **Alias capacity reached**: A single mailbox can hold only a finite number of
  aliases. When that limit is approached or reached, the system MUST inform the
  user and MUST NOT silently fail to create an alias.
- **Address collision**: If a generated address happens to already exist, the
  system MUST generate a different one rather than reuse or error out.
- **Mail to a disabled alias**: Such mail MUST NOT reach the inbox and MUST NOT
  generate a bounce or delivery notification that confirms the address exists to
  the sender.
- **Duplicate creation for the same site**: Allowed. Each request yields a
  distinct address; the site is a label, not a uniqueness key.
- **Mail to a never-created address**: MUST NOT be delivered to the inbox (no
  catch-all behavior).
- **Look-alike / guessing**: An address MUST NOT be derivable from the site name
  alone, so that a spammer cannot reconstruct other addresses or the primary
  address from one leaked alias.
- **Pool depletion**: If the pre-warmed supply is temporarily empty when the user
  requests an alias, the system MUST still fulfil the request (falling back to
  on-demand creation) and MUST NOT leave the user without an alias.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to create a new disposable email address on
  their own domain, associated with a named site or context they provide.
- **FR-002**: Each generated address MUST be unique across the user's aliases and
  MUST NOT be guessable or derivable from the associated site name.
- **FR-003**: Mail sent to an active alias MUST be delivered to the user's
  primary inbox.
- **FR-004**: The system MUST record, for every alias, at minimum: the address,
  the associated site/context, the creation timestamp, the current status
  (active or disabled), and an optional free-text note. This record is the
  authoritative source for the alias-to-site mapping.
- **FR-005**: Users MUST be able to list all of their aliases together with each
  alias's site, status, and creation date.
- **FR-006**: Users MUST be able to disable an individual alias so that
  subsequent mail to it is not delivered to the inbox.
- **FR-007**: Disabling or enabling one alias MUST NOT affect delivery for any
  other alias or for the primary address.
- **FR-008**: Users MUST be able to re-enable a previously disabled alias.
- **FR-009**: When the user receives a message, they MUST be able to determine
  which alias, and therefore which site, it was addressed to.
- **FR-010**: The system MUST NOT deliver mail sent to addresses that were never
  created as aliases (no catch-all).
- **FR-011**: Newly created aliases MUST be usable to receive mail immediately,
  without the user waiting for a provisioning delay.
- **FR-012**: The system MUST prevent creation of an alias whose address already
  exists.
- **FR-013**: When alias capacity is exhausted, the system MUST report this to
  the user rather than failing silently.
- **FR-014**: The system MUST maintain a continuously replenished supply of
  pre-warmed, ready-to-use aliases, so that issuing an alias to the user is
  instantaneous and the issued alias is active on first use.

### Key Entities *(include if feature involves data)*

- **Alias**: A unique disposable email address on the user's domain. Attributes:
  the address, associated site/context, creation timestamp, status (active or
  disabled), optional note. Relates to exactly one target inbox.
- **Site/Context**: A human-meaningful label for where an alias is used (for
  example a website or service name). Not unique; multiple aliases may share a
  label.
- **Ledger**: The authoritative inventory of all aliases and their attributes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can obtain a new, ready-to-use alias for a site in under 30
  seconds from the moment they request it.
- **SC-002**: A test message sent to a freshly created alias is delivered to the
  user's inbox on the first attempt, with no provisioning wait.
- **SC-003**: After disabling an alias, 100% of subsequent messages to that
  address stop reaching the inbox, while messages to other aliases are
  unaffected.
- **SC-004**: From any received message, the user can identify the originating
  site in under 15 seconds using the inventory.
- **SC-005**: The user can produce a complete, accurate list of every alias and
  its status at any time.

## Assumptions

- **Receive-only for V1**: Aliases are used to receive mail only. Sending or
  replying *as* an alias is explicitly out of scope for V1 and is deferred to V2.
- **Pre-warmed availability (confirmed)**: To satisfy immediate usability
  (FR-011, FR-014, SC-002), the system keeps a small supply of ready aliases
  warmed ahead of time so a freshly issued alias is active on first use. This
  was confirmed as in-scope for V1.
- **Single user, single domain**: V1 targets one user's own custom domain and
  their existing primary mailbox. Multi-user/multi-tenant support is out of
  scope.
- **Disable is reversible**: "Disable" is a reversible state, distinct from any
  future permanent-deletion capability, which is not required for V1.
- **Silent handling of blocked mail**: Mail to disabled or non-existent aliases
  is dropped without a bounce, to avoid confirming addresses to senders.
- **Existing inbox reused**: The user's existing primary mailbox is the delivery
  target; V1 does not create new end-user mailboxes for reading mail.
