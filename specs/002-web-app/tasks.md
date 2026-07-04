# Tasks: Web App for Alias Management

**Input**: Design documents from `specs/002-web-app/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-api-additions.md, quickstart.md

**Tests**: Included for module logic (speakable generator, owner check).

**Organization**: By user story — US1 (create & copy), US2 (manage), US3 (speakable).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [ ] T001 Create `src/functions/WebApp/` and `src/functions/WebApp/wwwroot/` for the served SPA

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T002 Set HTTP `routePrefix` to `""` in `src/functions/host.json` (UI at `/`, API at `/aliases`)
- [ ] T003 Add `src/functions/modules/Aliasaurus/Auth.ps1` with `Get-ClientPrincipalName` and `Test-RequestOwner` (reads `X-MS-CLIENT-PRINCIPAL-NAME`, compares to `OWNER_UPN`, dev bypass when `AZURE_FUNCTIONS_ENVIRONMENT=Development`); export from the module
- [ ] T004 Add `OwnerUpn` to `Get-AliasaurusConfig` (env `OWNER_UPN`) and to `local.settings.json.example`
- [ ] T005 Add `New-SpeakableAlias` (3 words from a curated unambiguous wordlist + 2 digits, crypto RNG, uniqueness check) to `AliasGenerator.ps1`; export it
- [ ] T006 Switch `CreateAlias`, `ListAliases`, `SetAliasState` to `authLevel: anonymous` and enforce `Test-RequestOwner` (403 for non-owner) in each `run.ps1`

**Checkpoint**: API is owner-gated and framework ready; UI can be added.

## Phase 3: User Story 1 - Create and copy an alias from any device (Priority: P1) 🎯 MVP

**Goal**: Owner creates an alias and copies it, on phone or desktop.

**Independent Test**: Sign in, create an alias for a site, confirm it shows with a working copy control.

- [ ] T007 [P] [US1] Pester unit tests for `New-SpeakableAlias` (word-based, unique, non-guessable) in `tests/unit/SpeakableAlias.Tests.ps1`
- [ ] T008 [US1] Extend `CreateAlias/run.ps1` to accept `format` (`base32` default | `speakable`) and use `New-SpeakableAlias` for on-demand/pool labeling accordingly
- [ ] T009 [US1] Implement the `WebApp` function (`function.json`, `run.ps1`) serving `wwwroot/index.html` at `GET /`
- [ ] T010 [US1] Build the create + copy UI in `src/functions/WebApp/wwwroot/index.html` (site input, submit, result with clipboard copy; responsive)

**Checkpoint**: MVP — create and copy from any device.

## Phase 4: User Story 2 - Manage aliases from the UI (Priority: P2)

**Goal**: List, search, disable/enable from the UI.

**Independent Test**: With aliases present, list, search, disable (confirm), re-enable.

- [ ] T011 [US2] Add the inventory view to `index.html`: list (site, address, status, created), search/filter, and disable/enable actions with a confirm step, calling `/aliases` and `/aliases/{address}/{action}`

**Checkpoint**: Full management from the UI.

## Phase 5: User Story 3 - Speakable alias for verbal use (Priority: P3)

**Goal**: Owner can request a dictation-friendly alias.

**Independent Test**: Choose speakable, create, verify word-based address.

- [ ] T012 [US3] Add a "speakable" toggle to the create UI that sends `format: "speakable"` and displays the word-based address

## Phase 6: Infra & Polish

- [ ] T013 Enable Easy Auth in `infra/main.bicep` (`authsettingsV2` Entra provider, require auth) with an `authClientId` param, and add `OWNER_UPN` app setting
- [ ] T014 [P] Pester unit tests for `Test-RequestOwner` (allows owner, denies others, dev bypass) in `tests/unit/Auth.Tests.ps1`
- [ ] T015 [P] Update `README.md` / `docs/deploy.md` with web-app usage, Easy Auth setup, and required vars (`OWNER_UPN`, `authClientId`)
- [ ] T016 Validate: Pester, PSScriptAnalyzer, dprint/yamlfmt/yamllint, actionlint/zizmor; run quickstart scenarios W-A..W-E

---

## Dependencies & Execution Order

- Setup (T001) → Foundational (T002-T006) → US1 (T007-T010) → US2 (T011) → US3 (T012) → Infra & Polish (T013-T016).
- US1/US2/US3 all build on the foundational auth + routing + generator work.

## Parallel Opportunities

- T007 and T014 (unit tests) are independent [P].
- T015 (docs) is independent [P] once behavior is settled.

## Implementation Strategy

MVP = Setup + Foundational + US1 (owner-gated create & copy). Then US2 (manage),
US3 (speakable), then infra/auth wiring and validation.
