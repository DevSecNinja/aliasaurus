<!--
Sync Impact Report
Version change: (none) → 1.0.0
Rationale: Initial ratification of the aliasaurus constitution (first version).
Modified principles: n/a (initial adoption)
Added sections:
  - Core Principles (5): M365-Native Mail Transport; Stateless Server-less Control Plane;
    Least-Privilege Managed Identity; Spec-First & ADR-Backed; Reproducible Pinned Tooling
  - Additional Constraints & Security Requirements
  - Development Workflow & Quality Gates
  - Governance
Removed sections: n/a
Templates status:
  ✅ .specify/templates/plan-template.md (reads constitution dynamically via "Constitution Check" gate)
  ✅ .specify/templates/spec-template.md (no principle-specific mandatory sections needed)
  ✅ .specify/templates/tasks-template.md (task categories compatible)
Follow-up TODOs: none
-->

# aliasaurus Constitution

## Core Principles

### I. M365-Native Mail Transport (NON-NEGOTIABLE)

Microsoft 365 / Exchange Online MUST be the sole transport for all mail that
flows through aliasaurus, both inbound and outbound. aliasaurus MUST NOT run,
host, or relay its own SMTP service, and MUST NOT route mail through any third
party that can read message contents beyond the Microsoft 365 tenant already in
use.

Rationale: keeping Microsoft as the only mail party offloads spam filtering,
deliverability, and sending IP reputation to a mature managed service, adds no
new trust boundary, and avoids operating always-on mail infrastructure. This
principle is the direct expression of ADR-0001.

### II. Stateless, Server-less Control Plane

aliasaurus is a control plane only: alias lifecycle management, a metadata
ledger, and (from V2) header rewriting for reply-from. Every component MUST be
stateless and server-less (Azure Functions / Azure Automation). Components MUST
NOT persist message bodies or attachments; only alias metadata (alias, site,
timestamps, enabled state, notes) may be stored.

Rationale: statelessness minimizes the privacy surface and operational burden,
and reinforces Principle I by ensuring aliasaurus never becomes a mail store.

### III. Least-Privilege Managed Identity (NON-NEGOTIABLE)

All automation MUST authenticate using a managed identity. Long-lived secrets,
passwords, client secrets, or certificates stored by the application are
forbidden. Granted RBAC MUST be scoped to the minimum required (for example a
custom Exchange management role limited to the specific cmdlets used); broad
roles such as Exchange Administrator or Global Administrator MUST NOT be used.

Rationale: no-secret, least-privilege auth limits blast radius and removes
credential-leakage risk from a publicly hosted repository.

### IV. Spec-First & ADR-Backed

No feature implementation begins without an approved specification produced
through the Spec Kit pipeline. Architectural or hard-to-reverse decisions MUST
be recorded as ADRs under `docs/adr/`. The constitution, the active spec, and
the ADRs are the source of truth; code MUST conform to them, not the reverse.

Rationale: intent-first development keeps a public, evolving project coherent
and reviewable, and preserves the reasoning behind constraints.

### V. Reproducible, Pinned Tooling

The toolchain MUST be declared and pinned via mise; dependencies MUST be pinned
and kept current via Renovate. A clean checkout MUST be buildable and runnable
from the declared tooling alone, with no undeclared global installs. Source
files MUST use spaces (not tabs) for indentation.

Rationale: reproducibility and pinned versions keep contributions and CI
deterministic and supply-chain-aware.

## Additional Constraints & Security Requirements

- Exchange Online limits MUST be respected, notably the maximum of 300 proxy
  addresses per recipient object; capacity beyond that is achieved with
  additional (unlicensed) shared mailboxes, not by exceeding the limit.
- The metadata ledger is the authoritative record of the alias-to-site mapping
  and enabled state; alias display names MUST NOT be relied upon for metadata.
- Secrets MUST NOT be committed. `local.settings.json`, `.env`, and equivalents
  stay git-ignored.
- Sending as a non-primary alias depends on
  `Set-OrganizationConfig -SendFromAliasEnabled $true`; this capability MUST be
  validated end-to-end before the V2 reply-from work is planned.

## Development Workflow & Quality Gates

- Follow the Spec Kit flow: constitution → specify → (clarify) → plan → tasks →
  implement. Each artifact is reviewed and committed before the next.
- The plan's Constitution Check gate MUST pass before design and again after
  design; any violation MUST be justified in the plan's Complexity Tracking or
  the plan MUST be revised.
- Changes land via pull request using Conventional Commit titles (the repo
  squash-merges).
- Scope is phased: V1 delivers receive-and-manage (alias creation, ledger, kill
  switch); V2 delivers reply-from. V2 work MUST be a separate spec cycle.

## Governance

This constitution supersedes other practices when they conflict. Amendments are
made by editing this file via pull request, with a Sync Impact Report and a
version bump.

Versioning follows semantic versioning:

- MAJOR: backward-incompatible governance or principle removal/redefinition.
- MINOR: a new principle or section, or materially expanded guidance.
- PATCH: clarifications, wording, or non-semantic refinements.

Compliance is reviewed at each Spec Kit gate (plan Constitution Check) and in
pull-request review. Complexity that violates a principle MUST be explicitly
justified or removed.

**Version**: 1.0.0 | **Ratified**: 2026-07-04 | **Last Amended**: 2026-07-04
