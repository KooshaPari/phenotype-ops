# Product Requirements Document — agent-devops-setups

**Version:** 1.0.0
**Stack:** Python 3.10+, JSON policy files, JSON Schema validation, Bash/Shell tooling
**Repo:** `KooshaPari/agent-devops-setups`
**Primary CLI:** `python tools/federate_policy.py --repo <repo> --harness <harness> --out <file>`

---

## Overview

`agent-devops-setups` is the shared configuration fabric for the Phenotype multi-model agent
toolchain. It solves the problem of agent-level toolchains (Codex, Cursor, Claude Code,
Factory-Droid) each maintaining isolated, diverging override surfaces — `AGENTS.md`, `CLAUDE.md`,
harness flags, and per-repo rule files — with no cross-harness consistency or audit trail.

This repository provides:

- A **six-layer precedence-aware policy model** (system → user → harness → repo → task-domain → extensions) where higher layers override lower layers via deep merge.
- A **Python resolver** (`federate_policy.py`) that produces a single signed JSON payload representing the effective policy for any (repo, harness, user, task-domain, extension) combination.
- A **sync tool** (`sync_policy.sh`) that writes the generated payload into target repositories.
- **Extension manifests** cataloging optional capability packs (agentops CI, codex gating, dot-agents bridge) that inject policy fragments at resolution time.
- **JSON Schema validation** for both policy documents and extension manifests, enforced in CI via the `validate-policy` workflow.
- A **security guard layer** for secret detection, permission escalation checking, and audit log generation.

The system is designed for an agent-driven environment where dozens of concurrent agents operate
across dozens of repositories. Consistent, auditable policy is the primary defence against
uncontrolled agent behaviour (destructive shell commands, unreviewed network access, unauthorized
file writes).

---

## E1: Policy Layer Model and Resolution

### E1.1: Six-Layer Precedence Stack

As a platform operator, I want policy to be composed from six ordered layers (system, user,
harness, repo, task-domain, extensions) so that org-wide defaults are always applied, and
progressively narrower layers can override them without needing to repeat the base.

**Acceptance Criteria:**
- `federate_policy.py` loads layers in the order: `system/base.json`, `system/security-guard.json`, `user/<user>.json`, `harness/<harness>.json`, `repo/<repo>.json`, `task-domain/<domain>.json`, then each extension manifest fragment.
- Deep merge is applied such that nested keys from higher layers overwrite matching keys from lower layers; non-conflicting keys from lower layers are preserved.
- A missing `repo/<repo>.json` falls back to `repo/default.json` rather than failing (unless `--strict` is passed).
- The resolved effective policy is written as a single JSON file at `--out`.

### E1.2: HMAC-Signed Policy Payload

As a security engineer, I want the resolved policy payload to include a SHA-256 digest and
optional HMAC signature so that consumers can detect tampering or substitution before applying
the policy.

**Acceptance Criteria:**
- The output payload includes `audit.policy_digest`: a SHA-256 hash of `{scope, policy, applied_layers}` serialized with sorted keys.
- When `--sign-key` is provided, `audit.policy_signature` is populated with an HMAC-SHA-256 signature of the digest.
- When `--sign-key` is absent, `policy_signature` is an empty string (not omitted).
- `audit.generated_at` is a UTC ISO-8601 timestamp.
- `audit.files` lists all layer file paths actually loaded in resolution order.

### E1.3: Strict and Lenient Resolution Modes

As a CI pipeline, I want to run policy resolution in strict mode so that any missing layer file
fails the build rather than silently falling back.

**Acceptance Criteria:**
- `--strict` flag causes `FileNotFoundError` if any layer file (except extension manifests) is absent.
- Without `--strict`, missing layer files emit a warning and are skipped; resolution continues.
- Missing extensions (in `--extensions`) are recorded in the `audit` block but do not fail resolution.

---

## E2: Extension Manifest System

### E2.1: Extension Manifest Schema and Loading

As a platform operator, I want to define optional capability packs as JSON manifests with a
`fragment` key containing a policy fragment so that extensions can be activated per-invocation
without modifying base policy files.

**Acceptance Criteria:**
- Extension manifests live in `extensions/manifests/<name>.json`.
- Each manifest validates against `schemas/extension-manifest.schema.json`.
- The `fragment` key in a manifest is merged into the policy under `policy.extensions.<name>`.
- Manifests without a `fragment` key are treated as metadata-only and contribute an empty policy fragment.

### E2.2: Registered Extension Catalog

As a developer onboarding to the policy system, I want a curated catalog of available
extensions so that I can discover and activate known capability packs.

**Acceptance Criteria:**
- The following extensions are registered and schema-valid: `agentops-ci`, `codex-gate`, `dot-agents-bridge`.
- `agentops-ci` manifest defines CI-scoped agent behaviour overrides.
- `codex-gate` manifest defines confirmation gates for Codex-specific destructive operations.
- `dot-agents-bridge` manifest defines the adapter fragment for consuming `AGENTS.md` files at runtime.

---

## E3: Policy Sync and Repository Onboarding

### E3.1: Policy Sync to Target Repositories

As a platform operator, I want a sync tool that writes the generated policy payload and any
harness-specific compiled artifacts into target repositories so that all repos always reflect
the current effective policy.

**Acceptance Criteria:**
- `tools/sync_policy.sh` accepts a target repository path and a resolved policy file.
- The sync writes the policy JSON to the target repo under a deterministic path.
- The sync is idempotent: running it twice with the same policy produces no additional changes.
- Sync failures (target repo not writable, validation fails) exit non-zero and print actionable errors.

### E3.2: Matrix Onboarding for Multiple Repositories

As a platform operator, I want to onboard a list of repositories in a single command so that
all repos in the Phenotype org receive consistent policy without manual per-repo invocations.

**Acceptance Criteria:**
- `tools/matrix_onboard.sh` reads a list of target repositories (from stdin or a file).
- For each repo, it calls `federate_policy.py` with appropriate arguments then `sync_policy.sh`.
- Progress is reported per-repo (success / skip / fail).
- The script exits non-zero if any individual repo fails; per-repo failures do not abort processing of remaining repos.

### E3.3: Repository DevOps Health Checker

As a platform operator, I want a checker script that validates whether a repository has a
correctly deployed policy payload and is within the expected schema version so that drift
between the canonical policy source and deployed repos is detected automatically.

**Acceptance Criteria:**
- `scripts/repo-devops-checker.sh` inspects a target repository for the presence of the policy payload.
- The checker validates the payload against `schemas/policy-resolution.schema.json`.
- The checker reports the `audit.policy_digest` of the currently deployed payload.
- Exit code 1 if the payload is absent, schema-invalid, or the digest does not match the expected value when provided.

---

## E4: Security Guard Integration

### E4.1: Destructive Action Policy Gates

As a security engineer, I want the system-level policy to declare which destructive shell
operations require user confirmation, so that agents cannot execute irreversible commands
silently regardless of harness.

**Acceptance Criteria:**
- `policies/system/security-guard.json` contains a deny list of shell command patterns
  (e.g., `rm -rf .git`, `git rebase --onto --hard`) that are flagged as forbidden defaults.
- The policy declares `consent_rules.destructive_actions: "ask"` at the system level.
- The harness-specific policies (claude, codex, cursor-agent, factory-droid) may narrow but not
  widen the system security policy.

### E4.2: Network Access Consent Rules

As a security engineer, I want the policy to require explicit consent for network access to
unknown hosts so that agents cannot exfiltrate data or call external APIs without user
awareness.

**Acceptance Criteria:**
- `consent_rules.network_access: "ask_on_unknown_hosts"` is defined in `system/base.json`.
- Harness policies may define an allowlist of known hosts that bypass the consent prompt.
- Extension manifests that enable network access to new hosts must be explicitly listed.

### E4.3: CI Security Guard Workflow

As a CI pipeline, I want the security guard workflow to validate all policy JSON files against
schemas and run secret-pattern detection on every push so that malformed or secret-leaking
policy files are caught before they reach main.

**Acceptance Criteria:**
- `.github/workflows/security-guard.yml` runs on push and PR to main.
- The workflow validates every `policies/**/*.json` and `extensions/**/*.json` against the
  appropriate JSON schema.
- The workflow runs `gitleaks` (or equivalent) secret detection on all changed files.
- The workflow fails and blocks merge on any validation error or detected secret.

---

## E5: Policy Validation and CI Gates

### E5.1: JSON Schema Enforcement

As a contributor, I want all policy and extension manifest files to be validated against
JSON Schema before they are merged so that structural errors are caught early.

**Acceptance Criteria:**
- `schemas/policy-resolution.schema.json` defines the schema for resolved policy payloads.
- `schemas/extension-manifest.schema.json` defines the schema for extension manifests.
- `tools/validate_policy_payload.py` validates a given payload file against the resolution schema.
- `.github/workflows/validate-policy.yml` runs validation on all changed policy files.

### E5.2: Policy Rotation Audit

As a compliance engineer, I want an audit tool that reports when individual policy layer files
were last modified and what changed so that stale or unreviewed policy layers are surfaced.

**Acceptance Criteria:**
- `tools/audit_policy_rotation.py` reads all policy layer files and reports their last-modified timestamps from git history.
- The tool flags any layer file that has not been modified in more than 90 days as "stale".
- Output is a machine-readable JSON report suitable for CI annotation.

---

## E6: Documentation and Developer Experience

### E6.1: Architecture and Scope Map Documentation

As a new contributor, I want architecture documentation that explains the layer model, the
resolution algorithm, and the extension manifest format so that I can write new policy layers
and extension manifests without reading source code.

**Acceptance Criteria:**
- `docs/architecture.md` describes the six-layer model with ASCII flow diagrams.
- `docs/scope-map.md` lists all currently defined scopes (harnesses, task-domains, repos) with brief descriptions.
- Both documents are kept in sync with the policy directory structure (CI check optional).

### E6.2: Contributing Guide

As a developer onboarding to the policy system, I want a contributing guide that specifies
how to add new harnesses, task domains, and extensions so that the process is repeatable and
does not require asking the original author.

**Acceptance Criteria:**
- `CONTRIBUTING.md` contains step-by-step instructions for: adding a new harness policy, adding a new task-domain policy, and registering a new extension manifest.
- Each section includes a minimal example JSON snippet.
- The guide references the JSON schema paths for validation.

---

## Non-Goals

- This repository does not implement a runtime interception layer; it produces configuration artifacts consumed by harness-specific interceptors (see `agentops-policy-federation`).
- It does not store secrets or API keys; it stores policy that references where secrets are obtained.
- It does not implement UI or web dashboards.
- It does not replace per-repo `AGENTS.md` or `CLAUDE.md` files; it supplements them by defining global governance layers.
- It does not enforce policy at the OS level; enforcement is left to each harness adapter.
