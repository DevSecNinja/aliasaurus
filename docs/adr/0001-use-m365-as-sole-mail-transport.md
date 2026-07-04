# 1. Use Microsoft 365 as the sole mail transport

- Status: accepted
- Date: 2026-07-04
- Deciders: @DevSecNinja

## Context and Problem Statement

Aliasaurus provides Apple "Hide My Email"-style disposable email aliases on a
custom domain: a unique, per-site address that can be tracked, disabled, and
(later) replied from. The central design question is which system actually
receives, stores, filters, and sends the mail behind those aliases.

Purpose-built forwarders such as addy.io and SimpleLogin solve this by acting
as the mail transport themselves: they run SMTP relays, apply spam filtering,
manage sending IP reputation, and (transiently) process message contents. That
transport layer is the source of their nicest features, but also of their
biggest operational and trust costs.

We already operate Microsoft 365 with a custom domain. The question is whether
to route Aliasaurus mail through M365 or to introduce a separate mail transport
(self-hosted or third-party).

## Decision Drivers

- Privacy: minimize the number of parties that can read message contents.
- Availability: avoid owning an additional service whose downtime blocks mail.
- Deliverability: avoid managing sending IP reputation, SPF/DKIM/DMARC, and
  blocklisting for a new sending host.
- Spam handling: reuse mature, managed inbound filtering rather than building it.
- Operational cost: keep the moving parts we run ourselves minimal and
  server-less.
- Standardization: consolidate on M365, already the user's primary platform.

## Considered Options

1. **Microsoft 365 as the sole mail transport.** Inbound aliases and outbound
   sending both go through Exchange Online. Aliasaurus adds only a stateless
   control/automation layer (alias lifecycle, metadata ledger, and later a
   header-rewriting reply relay driven by Microsoft Graph), never a mail relay.
2. **Self-hosted forwarder** (e.g. self-hosted addy.io / SimpleLogin). Full
   control and unlimited aliases, but we own SMTP, spam filtering, IP
   reputation, uptime, and the software has transient access to message bodies.
3. **Third-party hosted forwarder** (managed addy.io / SimpleLogin SaaS).
   Excellent UX and unlimited aliases, but introduces an additional party that
   processes mail and an additional dependency for availability.

## Decision Outcome

Chosen option: **Option 1, Microsoft 365 as the sole mail transport.**

All Aliasaurus mail is received and sent by Exchange Online. Aliasaurus itself
never relays, stores, or filters mail. It contributes only a server-less
control plane:

- Alias lifecycle via Exchange Online PowerShell setters (run from Azure
  Functions / Azure Automation using a managed identity, least-privilege RBAC).
- Read/inspection via Microsoft Graph (for example `proxyAddresses`).
- A metadata ledger (Azure Table Storage) recording alias, site, creation date,
  enabled state, and notes.
- (V2) A reply-from capability implemented as a Graph-driven header rewriter
  that hands the final message back to Exchange Online to send, so M365 remains
  the transport.

This keeps privacy, availability, spam filtering, and IP reputation with
Microsoft, and adds no new party beyond the M365 tenant we already trust.

### Consequences

Good:

- No third party beyond Microsoft can read Aliasaurus mail; Microsoft already
  processes it, so no new trust boundary is introduced.
- No sending IP reputation, SPF/DKIM/DMARC host, or spam engine to operate.
- No additional always-on service to keep available; the control plane is
  stateless and server-less.
- Consolidated on M365, matching the user's standardization goal.

Bad / accepted trade-offs:

- Bound by Exchange Online limits, notably a maximum of **300 proxy addresses
  per recipient object**, mitigated by spreading aliases across additional
  (unlicensed) shared mailboxes.
- Native "send from alias" (`Set-OrganizationConfig -SendFromAliasEnabled
  $true`) surfaces only in Outlook on the web and new Outlook desktop; **Outlook
  for iOS does not expose alias selection in From**. This gap is the sole reason
  the V2 Graph-based reply relay exists.
- Alias metadata cannot live on the mailbox Display Name (a mailbox has one),
  so an external ledger is required.

## More Information

- Related work: this decision defines the V1 (receive + manage) and V2
  (reply-from relay) scope for Aliasaurus.
- Assumption to validate before V2: that Microsoft Graph `sendMail` honors a
  non-primary alias in the `from` field when `SendFromAliasEnabled` is `true`.
