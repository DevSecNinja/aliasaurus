# Feature Specification: Web App for Alias Management

**Feature Branch**: `002-web-app`

**Created**: 2026-07-04

**Status**: Draft

**Input**: User description: "Web UI served from the Function App, Entra Easy Auth for a single user, to create/list/disable/enable aliases from laptop and phone"

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Create and copy an alias from any device (Priority: P1)

The owner opens the web app on a laptop or phone, types the site they are signing
up to, and instantly gets a new alias with a one-tap "copy" control to paste into
the signup form.

**Why this priority**: This is the primary daily action and the reason for a UI.
Without fast create-and-copy on mobile, the tool stays a developer-only API.

**Independent Test**: On both a phone and a desktop browser, sign in, create an
alias for a site, and confirm the address appears with a working copy control.

**Acceptance Scenarios**:

1. **Given** the signed-in owner on a phone, **When** they enter "example-shop"
   and submit, **Then** a new alias is shown with a one-tap copy button.
2. **Given** a freshly created alias, **When** the owner taps copy, **Then** the
   full address is placed on the clipboard.
3. **Given** an unauthenticated visitor, **When** they open any page, **Then**
   they are required to sign in and cannot create or view aliases.

---

### User Story 2 - Manage aliases from the UI (Priority: P2)

The owner reviews their aliases in a searchable list showing site, address,
status, and creation date, and can disable or re-enable any alias with a tap.

**Why this priority**: Turns the inventory and kill-switch into something usable
without the raw API; central to the anti-spam workflow.

**Independent Test**: With several aliases present, open the list, filter/search,
disable one, confirm it shows disabled, then re-enable it.

**Acceptance Scenarios**:

1. **Given** existing aliases, **When** the owner opens the list, **Then** each
   alias shows its site, address, status, and creation date.
2. **Given** the list, **When** the owner searches by site, **Then** only
   matching aliases are shown.
3. **Given** an active alias, **When** the owner disables it (and confirms),
   **Then** it shows as disabled; re-enabling restores it to active.

---

### User Story 3 - Get a speakable alias for verbal use (Priority: P3)

When the owner will have to give the address out loud (e.g. over the phone to a
call center), they can request a **speakable** alias that is easy to dictate
without spelling, while still being non-guessable.

**Why this priority**: Solves a real friction point (random base32 is painful to
read aloud) but is secondary to core create/manage flows.

**Independent Test**: Request a speakable alias and confirm the local part is
composed of pronounceable, unambiguous tokens rather than a random character
string, and that it is still unique and not derived from the site name.

**Acceptance Scenarios**:

1. **Given** the create screen, **When** the owner chooses "speakable", **Then**
   the generated alias is easy to read aloud (e.g. word-based) and unique.
2. **Given** a speakable alias, **When** it is inspected, **Then** it does not
   contain the site name and cannot be guessed from it.

---

### Edge Cases

- **Sign-in required everywhere**: every route and data call requires the owner's
  authenticated session; there is no anonymous read path.
- **Not the owner**: a signed-in identity that is not the configured owner is
  denied access.
- **Offline / API error**: the UI shows a clear error and does not lose the
  entered site value.
- **Small screens**: all actions (create, copy, list, disable/enable) are usable
  on a phone-sized viewport.
- **Copy unsupported**: if clipboard access is unavailable, the address is still
  selectable for manual copy.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The system MUST provide a web interface usable on current mobile
  and desktop browsers, with a responsive layout.
- **FR-002**: Access MUST be restricted to the authenticated owner; all pages and
  data operations require sign-in, and non-owner identities are denied.
- **FR-003**: The owner MUST be able to create an alias by entering a site (and
  optional note) and receive the resulting address in the UI.
- **FR-004**: The create result MUST offer a one-action copy of the full address.
- **FR-005**: The owner MUST be able to view a list of aliases showing site,
  address, status, and creation date.
- **FR-006**: The owner MUST be able to search/filter the list by site or status.
- **FR-007**: The owner MUST be able to disable and re-enable an alias from the
  UI, with a confirmation step before disabling.
- **FR-008**: The UI MUST reflect the current alias state after each action
  (created, disabled, enabled).
- **FR-009**: The owner MUST be able to request a **speakable** alias that is easy
  to dictate aloud, remains unique, and is not derivable from the site name.
- **FR-010**: The UI MUST surface errors (e.g. capacity reached, pool depleted,
  network failure) in plain language without losing the owner's input.

### Key Entities _(include if feature involves data)_

- **Alias (view)**: as defined in feature 001 (address, site, status, created);
  the web app presents and mutates these; it introduces no new stored entity.
- **Owner identity**: the single authorized user; not stored by the app beyond
  configuration of who the owner is.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: On a phone, the owner can go from opening the app to a copied alias
  in under 20 seconds.
- **SC-002**: 100% of pages and data operations are inaccessible without owner
  authentication.
- **SC-003**: The owner can disable an alias from the UI in 3 taps or fewer.
- **SC-004**: The full create, list, disable, and enable flows are completable on
  a phone-sized screen without horizontal scrolling.
- **SC-005**: A speakable alias can be read aloud and re-entered correctly by a
  listener without spelling, in a first-try dictation test.

## Assumptions

- **UI over the existing API**: the web app is a client of the feature-001
  control API; it adds no new mail or alias-storage behavior.
- **Single owner**: exactly one authorized user; multi-user sharing is out of
  scope.
- **Speakable format (informed default)**: implemented as a short combination of
  words from a curated wordlist plus a few digits (e.g. `brave-otter-partridge-7`),
  chosen for enough entropy to stay non-guessable. Exact scheme is a decision to
  confirm (see completion notes).
- **Receive-only** still holds: the web app does not add send-from; that remains
  V-next.
- **Same custom domain and mailboxes** as feature 001.
