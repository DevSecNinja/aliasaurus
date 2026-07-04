# Tasks: Disposable Per-Site Email Aliases (Receive & Manage)

**Input**: Design documents from `specs/001-alias-management/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/control-api.yaml, quickstart.md

**Tests**: Included — the quickstart defines a Pester unit + gated integration suite.

**Organization**: Tasks are grouped by user story (US1–US3) for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (create), US2 (disable/enable), US3 (inventory)

## Path Conventions

Serverless backend (per plan.md): Azure Functions PowerShell app under
`src/functions/`, shared module under `src/functions/modules/Aliasaurus/`,
IaC under `infra/`, tests under `tests/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project skeleton and tooling.

- [x] T001 Create the project structure (`src/functions/`, `src/functions/modules/Aliasaurus/`, `infra/`, `tests/unit/`, `tests/integration/`) per plan.md
- [x] T002 Scaffold the Azure Functions PowerShell app in `src/functions/` (`host.json`, `profile.ps1`, `local.settings.json` template) and pin module versions in `src/functions/requirements.psd1` (ExchangeOnlineManagement, Microsoft.Graph.Authentication, Azure.Data.Tables)
- [x] T003 [P] Configure Pester and PSScriptAnalyzer as mise-managed tools/tasks in `mise.toml`
- [x] T004 [P] Add `renovate.json5` extending `github>DevSecNinja/.github` with `# renovate:` comments for the pinned PowerShell modules

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infrastructure, auth, and shared module capabilities that every user story depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Author `infra/main.bicep` provisioning the Function App (PowerShell, system-assigned managed identity), Storage account, and the `aliases` table
- [x] T006 [P] Add Bicep role assignment granting the managed identity a Storage Table Data Contributor role scoped to the `aliases` table in `infra/main.bicep`
- [x] T007 Author `infra/exchange-prereqs.md` + `scripts/Setup-ExchangePrereqs.ps1` documenting/scripting the Exchange side: custom RBAC management role scoped to `Set-Mailbox`/`Get-Mailbox`/mail-flow cmdlets, `Exchange.ManageAsApp` grant to the MI, intake & graveyard shared mailboxes, intake→primary forwarding, and the graveyard "delete without notifying anyone" mail-flow rule
- [x] T008 Implement managed-identity connection to Exchange Online and Microsoft Graph in `src/functions/profile.ps1` and `src/functions/modules/Aliasaurus/Connect.ps1`
- [x] T009 [P] Implement the ledger data-access layer (Azure.Data.Tables CRUD for Alias records, per data-model.md) in `src/functions/modules/Aliasaurus/Ledger.ps1`
- [x] T010 [P] Implement the non-guessable alias generator (random 12-char base32 local part, uniqueness check) in `src/functions/modules/Aliasaurus/AliasGenerator.ps1`
- [x] T011 [P] Implement configuration loading (custom domain, intake/graveyard mailbox UPNs, pool target size, low-water mark) in `src/functions/modules/Aliasaurus/Config.ps1`
- [x] T012 Add structured logging and error-handling helpers in `src/functions/modules/Aliasaurus/Common.ps1`

**Checkpoint**: Foundation ready — user stories can proceed.

---

## Phase 3: User Story 1 - Create a disposable alias for a site (Priority: P1) 🎯 MVP

**Goal**: Issue an instantly usable, non-guessable per-site alias that delivers to the primary inbox.

**Independent Test**: Create an alias for a site, email it from outside, confirm inbox delivery on first attempt and attribution to the site.

### Tests for User Story 1

- [x] T013 [P] [US1] Pester unit tests for alias generation (uniqueness, non-guessability, no site name leakage) in `tests/unit/AliasGenerator.Tests.ps1`
- [x] T014 [P] [US1] Pester unit tests for pool selection and the `pool → active` ledger transition in `tests/unit/CreateAlias.Tests.ps1`

### Implementation for User Story 1

- [x] T015 [US1] Implement the `ReplenishPool` timer function (add warmed proxy addresses to the intake mailbox, write `pool` ledger rows up to the target size) in `src/functions/ReplenishPool/run.ps1` and `function.json`
- [x] T016 [US1] Implement the `CreateAlias` HTTP function (select a warm alias, set `site`/`assignedUtc`, mark `active`; fall back to on-demand creation when the pool is empty) in `src/functions/CreateAlias/run.ps1` and `function.json`, per `contracts/control-api.yaml` `POST /aliases`
- [x] T017 [US1] Implement capacity handling: spill to the next intake mailbox or return `507` when all intake mailboxes are at the 300-proxy limit (FR-013) in `src/functions/modules/Aliasaurus/Mailbox.ps1`
- [x] T018 [US1] Pester integration test (gated) creating an alias and verifying inbox delivery + attribution in `tests/integration/CreateAlias.Integration.Tests.ps1`

**Checkpoint**: MVP — aliases can be issued and receive mail instantly.

---

## Phase 4: User Story 2 - Disable an alias that receives spam (Priority: P2)

**Goal**: Individually disable/re-enable an alias with a silent drop and no collateral impact.

**Independent Test**: Disable an alias, confirm its mail is silently dropped (no NDR) while another alias still delivers; re-enable and confirm delivery resumes.

### Tests for User Story 2

- [x] T019 [P] [US2] Pester unit tests for the `active ↔ disabled` transitions and intake↔graveyard proxy-move logic in `tests/unit/SetAliasState.Tests.ps1`

### Implementation for User Story 2

- [x] T020 [US2] Implement the `SetAliasState` HTTP function (disable: move the proxy from intake to graveyard, set `disabled`; enable: reverse) in `src/functions/SetAliasState/run.ps1` and `function.json`, per `contracts/control-api.yaml` `POST /aliases/{address}/disable|enable`
- [x] T021 [US2] Add the proxy-move operations (intake↔graveyard, idempotent) to `src/functions/modules/Aliasaurus/Mailbox.ps1`
- [x] T022 [US2] Pester integration test (gated) verifying disabled alias is silently dropped (no bounce), other aliases unaffected, and re-enable resumes delivery in `tests/integration/SetAliasState.Integration.Tests.ps1`

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 - See where every alias is used (Priority: P3)

**Goal**: Produce an accurate inventory and support address→site attribution.

**Independent Test**: After creating/disabling several aliases, list them and confirm site/status/date accuracy; look up a received address to find its site.

### Tests for User Story 3

- [x] T023 [P] [US3] Pester unit tests for inventory projection and status filtering (pool entries excluded) in `tests/unit/ListAliases.Tests.ps1`

### Implementation for User Story 3

- [x] T024 [US3] Implement the `ListAliases` HTTP function (read the ledger, optional Graph `proxyAddresses` reconciliation, exclude `pool` entries, optional status filter) in `src/functions/ListAliases/run.ps1` and `function.json`, per `contracts/control-api.yaml` `GET /aliases`
- [x] T025 [US3] Add an address→site attribution helper in `src/functions/modules/Aliasaurus/Ledger.ps1`

**Checkpoint**: All user stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T026 [P] Update `README.md` and add `docs/deploy.md` with deploy/run/setup instructions (mise, Bicep, Exchange prereqs)
- [x] T027 [P] Validate `specs/001-alias-management/contracts/control-api.yaml` against the implemented function routes
- [ ] T028 Run the `quickstart.md` validation scenarios (V1-A through V1-F) end to end _(pending: requires a live tenant/Azure deployment)_
- [x] T029 PSScriptAnalyzer + formatting pass across `src/` and `tests/`; verify RBAC scope is least-privilege (no broad admin roles)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; BLOCKS all user stories.
- **User Stories (Phase 3–5)**: depend on Foundational; then orderable by priority (P1 → P2 → P3) or parallel.
- **Polish (Phase 6)**: depends on the desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: only Foundational. Delivers the MVP.
- **US2 (P2)**: only Foundational. Reuses `Mailbox.ps1`/`Ledger.ps1` but is independently testable.
- **US3 (P3)**: only Foundational. Reads ledger written by US1/US2 but testable with seeded data.

### Within Each User Story

- Tests before implementation; module capabilities before functions; core before integration tests.

### Parallel Opportunities

- Setup: T003, T004 in parallel.
- Foundational: T009, T010, T011 in parallel (distinct module files) after T008.
- Unit test tasks marked [P] within each story in parallel.
- After Foundational, US1/US2/US3 can be staffed in parallel.

---

## Parallel Example: User Story 1

```text
# Unit tests together:
Task: "Pester unit tests for alias generation in tests/unit/AliasGenerator.Tests.ps1"
Task: "Pester unit tests for pool selection in tests/unit/CreateAlias.Tests.ps1"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → STOP and validate (V1-A/B) → deploy/demo.

### Incremental Delivery

Foundation → US1 (MVP) → US2 (kill switch) → US3 (inventory), each validated and demoable independently.

---

## Notes

- [P] = different files, no incomplete dependencies.
- Integration tests are gated (require a test tenant, intake + graveyard mailboxes); unit tests run without external services.
- Commit after each task or logical group; keep aliases receive-only (send-from is V2).
