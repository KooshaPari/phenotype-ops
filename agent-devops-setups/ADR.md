# Architecture Decision Records — agent-devops-setups

---

## ADR-001 — Six-Layer Precedence Policy Model

**Date:** 2025-09-01
**Status:** Accepted

### Context
Each agent harness (Claude Code, Codex, Cursor-agent, Factory-Droid) maintains its own local
override files with no cross-harness consistency. Policy drift leads to agents operating under
different rules on the same codebase.

### Decision
Implement a six-layer policy model with explicit precedence (lowest → highest):
1. `system` — platform-wide immutable rules
2. `user` — user-level preferences
3. `harness` — harness-specific defaults
4. `repo` — per-repository overrides
5. `branch` — per-branch overrides
6. `task` — per-task inline overrides

Higher layers override lower layers on a key-by-key basis; no full replacement.

### Consequences
- A single federated policy file can be generated per (harness, repo) pair.
- Drift is eliminated by construction: all harnesses derive from the same policy tree.
- Adding a new layer requires a schema version bump and migration of existing policy files.

---

## ADR-002 — JSON Schema Validation for All Policy Files

**Date:** 2025-09-10
**Status:** Accepted

### Context
Policy files are edited by agents and humans. Invalid policy files cause silent misbehaviour
in agent toolchains. A validation gate is required.

### Decision
All policy files conform to JSON Schema definitions in `schemas/`. The `federate_policy.py`
tool validates inputs before processing and rejects invalid files with field-level errors.

### Consequences
- Policy authors get immediate feedback on schema violations.
- CI validates all policy files on every PR.
- Schema changes require updating `schemas/` and bumping the policy schema version.

---

## ADR-003 — Harness-Specific Overlay Files

**Date:** 2025-09-15
**Status:** Accepted

### Context
Each agent harness has idiosyncratic configuration surfaces (AGENTS.md, CLAUDE.md, .cursor/rules,
etc.) that must be populated from the federated policy. A single output format cannot serve all.

### Decision
Define harness-specific overlay templates in `extensions/<harness>/`. The `federate_policy.py`
tool renders the federated policy through the appropriate template to produce the harness config.

### Consequences
- Adding support for a new harness requires only a new overlay template.
- Rendered harness configs are committed to target repos; `agent-devops-setups` is the source
  of truth, not the rendered files.

---

## ADR-004 — Git-Based Audit Trail for Policy Changes

**Date:** 2025-10-01
**Status:** Accepted

### Context
Security auditors and incident responders need to know what policy was active at any point in
time for any (harness, repo) pair.

### Decision
All policy changes are committed to this repository with conventional commit messages
(`policy: update <layer>/<key>`). The git log is the audit trail. No external audit log
service is required.

### Consequences
- `git log --follow policies/<layer>/` shows the full change history for any policy layer.
- Rollback is `git revert`; no special tooling required.
- For regulated environments requiring immutable audit logs, a git signing policy (GPG/SSH) is
  recommended on this repository.
