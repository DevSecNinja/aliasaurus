# 3. Serve the web UI from the Function App with Entra Easy Auth

- Status: accepted
- Date: 2026-07-04
- Deciders: @DevSecNinja

## Context and Problem Statement

Feature 002 adds a web UI so the owner can create and manage aliases from a
laptop and phone, instead of calling the raw API. The UI is internet-facing but
for a single user. We must decide where it is hosted and how it is authenticated,
without introducing secrets into the browser or a new always-on service
(Constitution Principles II and III).

## Decision Drivers

- Single owner; internet-facing; must work on mobile and desktop.
- No secrets in the browser (no function keys shipped to the client).
- Minimize new infrastructure and moving parts (server-less, stateless).
- Reuse the existing Entra tenant for sign-in.

## Considered Options

1. **Serve the SPA from the existing Function App, gated by App Service
   Authentication (Easy Auth) with Entra.** One deployable, same origin, platform
   handles sign-in; API runs anonymous behind Easy Auth with an owner check.
2. **Azure Static Web App** with built-in auth calling the Functions API. Clean
   auth, but adds a resource and cross-origin wiring.
3. **Function keys in the SPA.** Simple, but ships a shared secret to the browser
   — rejected on security grounds.

## Decision Outcome

Chosen option: **Option 1** (owner's stated preference). The SPA (`index.html`)
is served by a `WebApp` function at the site root (HTTP `routePrefix` set to
`""`). App Service Authentication (Easy Auth) with the Entra provider requires
sign-in for every request. API functions use `authLevel: anonymous` and each
verifies `X-MS-CLIENT-PRINCIPAL-NAME` equals the configured `OWNER_UPN`, denying
other identities with 403 (defense in depth).

### Consequences

Good:

- One deployable, same origin (no CORS), no new hosting service.
- No secrets in the browser; only an Easy Auth session cookie.
- Entra sign-in works across devices; owner-only enforced at platform and app.

Bad / accepted trade-offs:

- Requires an Entra app registration and Easy Auth configuration as a deploy
  prerequisite.
- The Functions app now serves static content and API from one origin; the route
  prefix change (`""`) must be kept consistent.

## More Information

- Implements `specs/002-web-app/plan.md` (Decisions 1-2).
- Related: ADR-0001 (M365 transport), ADR-0002 (server-less MI control plane).
