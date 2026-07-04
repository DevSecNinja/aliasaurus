# Contract additions for the Web App (extends 001 control-api.yaml)

The web app reuses the feature-001 control API with these changes.

## Authentication (all endpoints)

- All endpoints are gated by App Service Authentication (Easy Auth, Entra).
  Unauthenticated requests are challenged by the platform.
- API functions run at `authLevel: anonymous` (no function keys).
- Each request must carry the Easy Auth client principal; the server allows the
  request only when `X-MS-CLIENT-PRINCIPAL-NAME` equals the configured owner.
  Non-owner authenticated identities receive **403**.

## Routing

- HTTP `routePrefix` is `""`.
  - `GET /` → the web UI (`WebApp` function, serves `index.html`).
  - `GET /aliases`, `POST /aliases`, `POST /aliases/{address}/{action}` → as in
    the 001 contract (now without the `/api` prefix).

## `POST /aliases` — new optional field

```json
{
  "site": "example-shop",
  "note": "optional",
  "format": "base32 | speakable"   // optional; default "base32"
}
```

- `format: "speakable"` returns an alias whose local part is word-based and easy
  to dictate (e.g. `brave-otter-cactus-42@example.com`), still unique and
  non-guessable.
- Response shape is unchanged (`Alias`).

## Errors

- **401** — not authenticated (platform challenge).
- **403** — authenticated but not the owner.
- Other status codes unchanged from the 001 contract (201, 404, 503, 507).
