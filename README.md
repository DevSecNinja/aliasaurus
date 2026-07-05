# aliasaurus 🦕

> [!WARNING]
> **Proof of Concept.** This project is an exploratory proof of concept and is
> **not in production use** — the author is not running it. Expect rough edges,
> breaking changes, and unimplemented pieces. Use at your own risk.

Self-service, disposable per-site email aliases on your own domain, backed
entirely by **Microsoft 365** — an M365-native alternative to Apple's
"Hide My Email".

Each site you sign up to gets its own unique address. If one starts receiving
spam, you know exactly who leaked it, and you can disable that single address
without affecting anything else.

## Why M365-native?

Microsoft 365 stays the sole mail transport, so spam filtering, deliverability,
and sending IP reputation are all handled by Microsoft. aliasaurus adds only a
stateless, server-less control plane — never its own mail relay, and no extra
party that can read your mail. See
[docs/adr/0001-use-m365-as-sole-mail-transport.md](docs/adr/0001-use-m365-as-sole-mail-transport.md).

## Using it

Once deployed, browse to the Function App URL (e.g.
`https://aliasaurus-func.azurewebsites.net/`). You'll sign in with Entra
(Easy Auth), then create per-site aliases, copy them, and disable/enable them —
from laptop or phone. Choose "speakable" for an address that's easy to dictate
over the phone (e.g. `brave-otter-cactus-42@yourdomain`).

## Roadmap

- **V1 — receive & manage:** automated alias creation (Exchange Online
  PowerShell via Azure Functions / Automation with a managed identity), a
  metadata ledger (alias → site, created, enabled, notes), and a per-alias
  kill switch. Inspection via Microsoft Graph.
- **V2 — reply-from:** a Graph-driven header-rewriting reply relay so you can
  reply _as_ an alias from any client, including Outlook for iOS.

## Development

This project uses [mise](https://mise.jdx.dev/) for tooling and
[GitHub Spec Kit](https://github.com/github/spec-kit) for spec-driven
development.

```sh
mise install            # provision pinned tools (uv, ...)
```

Spec-driven workflow (via Copilot slash commands): `/speckit.constitution` →
`/speckit.specify` → `/speckit.plan` → `/speckit.tasks` → `/speckit.implement`.
