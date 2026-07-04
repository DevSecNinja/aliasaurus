# Quickstart & Validation: Web App for Alias Management

Extends `docs/deploy.md`. See `plan.md`, `research.md`, and
`contracts/ui-api-additions.md`.

## Prerequisites (in addition to feature 001)

- An Entra app registration for Easy Auth (redirect URI
  `https://<app>.azurewebsites.net/.auth/login/aad/callback`).
- `OWNER_UPN` set to your sign-in address; `AUTH_CLIENT_ID` set to the Entra app.

## One-time setup

1. Deploy `infra/main.bicep` (now enables Easy Auth via `authsettingsV2` and sets
   `OWNER_UPN`). Provide `authClientId`.
2. Deploy the Functions app (includes the `WebApp` function and `wwwroot`).

## Validation scenarios

### W-A — Owner-only access (SC-002)

1. Open `/` signed out → redirected to Entra sign-in.
2. Sign in as the owner → the app loads.
3. Sign in as a different identity → requests return 403 / access denied.

### W-B — Create and copy on mobile (US1 / SC-001)

1. On a phone, enter a site and submit → a new alias appears with a copy button.
2. Tap copy → the address is on the clipboard.

### W-C — Manage aliases (US2 / SC-003)

1. Open the list → aliases show site, address, status, created date.
2. Search by site → filtered results.
3. Disable an alias (confirm) → shows disabled; re-enable → shows active.

### W-D — Speakable alias (US3 / SC-005)

1. Choose "speakable" and create → address is word-based (e.g.
   `brave-otter-cactus-42@domain`).
2. Read it aloud to another person; they re-enter it correctly without spelling.

### W-E — Responsive (SC-004)

1. All actions complete on a phone-sized viewport without horizontal scrolling.

## Automated tests

- **Unit (Pester)**: `New-SpeakableAlias` (word-based, unique, non-guessable) and
  the owner-check helper (allows owner, denies others, dev bypass).
