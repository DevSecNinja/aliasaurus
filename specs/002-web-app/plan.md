# Implementation Plan: Web App for Alias Management

**Branch**: `002-web-app` | **Date**: 2026-07-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-web-app/spec.md`

## Summary

Add a responsive single-page web UI served **from the existing Function App**,
protected by **App Service Authentication (Easy Auth)** with Entra ID and
restricted to a single configured owner. The SPA is a self-contained
`index.html` (vanilla HTML/CSS/JS, no framework) served by a new `WebApp`
function at the site root; it calls the existing alias API (create, list,
disable, enable). The HTTP route prefix is changed to empty so the UI lives at
`/` and the API at `/aliases`. API functions switch to `authLevel: anonymous`
(Easy Auth gates the platform) and each verifies the caller is the owner via the
Easy Auth client-principal header (defense in depth). A new **speakable** alias
format (word-based) is added for verbal/phone use.

## Technical Context

**Language/Version**: PowerShell 7.4 (Functions); vanilla HTML/CSS/JS for the UI.

**Primary Dependencies**: Existing `Aliasaurus` module; Azure Functions HTTP
triggers; App Service Authentication (Easy Auth) for Entra sign-in. No frontend
framework or build step.

**Storage**: None new; reuses the feature-001 ledger.

**Testing**: Pester (module logic: speakable generator, owner check). UI verified
via quickstart scenarios.

**Target Platform**: Azure Functions (Linux) with Easy Auth; modern mobile +
desktop browsers.

**Project Type**: Serverless backend + a served static SPA (single deployable).

**Performance Goals**: Open-to-copied-alias under 20s on mobile (SC-001); UI
assets are a single small HTML document.

**Constraints**: Single authenticated owner (SC-002); no secrets in the browser
(session cookie via Easy Auth, not function keys); mobile-first responsive
(SC-004); speakable aliases stay non-guessable.

**Scale/Scope**: One owner; a handful of screens in one HTML file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. M365-Native Mail Transport | ✅ PASS | No mail-path change; UI only calls the existing control API. |
| II. Stateless, Server-less Control Plane | ✅ PASS | UI is static content served by a function; no new state; no message bodies. |
| III. Least-Privilege Managed Identity | ✅ PASS | Easy Auth (Entra) gates users; API still uses the MI for Exchange/Storage; browser holds only a session cookie, no keys. |
| IV. Spec-First & ADR-Backed | ✅ PASS | Derives from the approved spec; the auth/hosting choice is recorded in ADR-0003. |
| V. Reproducible, Pinned Tooling | ✅ PASS | No new toolchain; framework-free UI; mise/Renovate unchanged. |

**Post-design re-check**: ✅ PASS — no new violations; Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-web-app/
├── plan.md, research.md, data-model.md, quickstart.md
└── contracts/
    └── ui-api-additions.md   # auth + speakable additions to the 001 contract
```

### Source Code (repository root)

```text
src/functions/
├── host.json                 # routePrefix "" so UI is at / and API at /aliases
├── WebApp/                    # NEW: serves the SPA (GET /)
│   ├── function.json
│   ├── run.ps1
│   └── wwwroot/index.html     # self-contained responsive SPA
├── CreateAlias/               # + speakable option, + owner check, anonymous authLevel
├── ListAliases/               # + owner check, anonymous authLevel
├── SetAliasState/             # + owner check, anonymous authLevel
├── ReplenishPool/             # unchanged
└── modules/Aliasaurus/
    ├── AliasGenerator.ps1     # + New-SpeakableAlias
    └── Auth.ps1               # NEW: Test-RequestOwner / Get-ClientPrincipalName

infra/main.bicep              # + authsettingsV2 (Easy Auth) + OWNER_UPN + auth params
tests/unit/                   # + Speakable + Auth tests
```

**Structure Decision**: Extend the single Functions app; the UI ships inside it
as static content plus one serving function. No separate frontend project.

## Complexity Tracking

> No constitution violations. Section intentionally empty.
