# Phase 0 Research: Web App for Alias Management

## Decision 1 — Host the UI inside the Function App

- **Decision**: Serve a self-contained `index.html` from a new `WebApp` HTTP
  function at the site root, and change the Functions HTTP `routePrefix` to `""`
  so the UI is at `/` and the API at `/aliases`.
- **Rationale**: One deployable, no extra hosting service (Principle II), no CORS
  (same origin). The owner chose this over a separate Static Web App.
- **Alternatives**: Azure Static Web App (extra resource + auth wiring); separate
  frontend project/build (unneeded complexity for a few screens).

## Decision 2 — Authentication via Easy Auth (Entra), single owner

- **Decision**: Enable App Service Authentication (Easy Auth) with the Microsoft
  (Entra) provider set to require authentication. Every request is gated at the
  platform before the Functions host. API functions use `authLevel: anonymous`
  (no function keys in the browser); each function also verifies the caller is
  the configured owner by reading the Easy Auth client-principal header
  (`X-MS-CLIENT-PRINCIPAL-NAME`) against `OWNER_UPN` (defense in depth).
- **Rationale**: No secrets in the browser; Entra login works on laptop and
  phone; owner-only access (SC-002). Aligns with Principle III.
- **Alternatives**: Function keys in the SPA (secret exposure — rejected);
  custom auth (reinventing Entra — rejected).
- **Local dev**: when `AZURE_FUNCTIONS_ENVIRONMENT=Development` and no
  client-principal header is present, the owner check is bypassed for local
  testing only.

## Decision 3 — Speakable alias format (word-based)

- **Decision**: Add `New-SpeakableAlias` producing a local part of 3 random words
  from a curated, unambiguous wordlist joined by hyphens plus 2 random digits,
  e.g. `brave-otter-cactus-42@domain`. Words are chosen with a cryptographic RNG.
- **Rationale**: Easy to dictate over the phone (no spelling), while a 3-word +
  2-digit space over a ~256-word list gives ample entropy to stay non-guessable
  and not derived from the site name (FR-002, FR-009, SC-005).
- **Alternatives**: Random base32 (hard to dictate — the motivating problem);
  full Diceware (longer than needed). The random base32 format remains the
  default; speakable is opt-in per request.

## Decision 4 — Framework-free SPA

- **Decision**: A single `index.html` with inline CSS and vanilla JS (fetch to
  `/aliases`), responsive/mobile-first, with a clipboard-copy control.
- **Rationale**: Minimal footprint, no build step, trivially served as static
  content, satisfies Principle V (no new toolchain).
- **Alternatives**: React/Vue + bundler (disproportionate for this scope).

## Cross-cutting

The hosting + Easy Auth decision is recorded in **ADR-0003**.
