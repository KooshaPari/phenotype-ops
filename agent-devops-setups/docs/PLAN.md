# Implementation Plan: Agent DevOps Federation Repo

## Phase 1 — Baseline (done)
- Create repository skeleton and policy schema contract.
- Add policy layers for system, user, harness, repo, task-domain, and extensions.
- Add resolution tooling (`federate_policy.py`) and sync tooling (`sync_policy.sh`, `onboard_repos.sh`).
- Add validation workflow (`.github/workflows/validate-policy.yml`).

## Phase 2 — Pilot (done)
- Generate and sync effective policies for:
  - `thegent`
  - `template-commons`
- Verify payload includes:
  - `policy` merge output
  - `audit.files` source tracing
  - `audit.policy_digest`

## Phase 3 — Full default onboarding wave (done)
- Apply default batch list:
  - `agent-devops-setups`
  - `thegent`
  - `template-commons`
  - `portage`
  - `heliosCLI`
  - `cliproxyapi++`
  - `agentapi-plusplus`
- Sync in write mode to `docs/agent-policy/` for each repo.

## Phase 4 — Adoption (in progress)
- Expand extension catalog as needed:
  - dot-agents bridge
  - codex-gate
  - agentops-ci
- Add per-repo policy overrides for missing harness/task-domain pairs as adoption expands.
- Add schema-backed strict validation in CI and repository policy pre-commit checks.

## Phase 5 — Hardening (next)
- Added optional HMAC signing in `tools/federate_policy.py` (`--sign-key`) and signature verification in `tools/validate_policy_payload.py`.
- Added policy rotation audit utility `tools/audit_policy_rotation.py` (digest drift tracking, snapshot persistence).
- Validate manifest compatibility from active `extensions/manifests/*.json` entries.
- Add optional signature/provenance metadata for policy artifact consumers.
- Add governance rotation report command and retention policy.

## Phase 6 — Matrix scale and operator workflow (done)
- Added `tools/matrix_onboard.sh` for full harness/task-domain cartesian onboarding.
- Updated `onboard_repos.sh` with explicit `--mode write|dry-run` and signing passthrough.
- Added `Makefile` with daily workflow targets for sync, matrix sync, validation, and rotation.
- Added `tools/build_pr_package.py` to generate PR-ready patch + manifest for handoff.

## Cross-Project Reuse Opportunities

- Potential extraction target: shared policy schema and extension manifest catalog as a central `template-commons`-adjacent package.
- Target repos for immediate rollout: `thegent`, `portage`, `heliosCLI`, `cliproxyapi++`, `agentapi-plusplus`.
- Rollout order: seed shared schema package -> onboard repos in dependency order -> enforce CI checks in each repo after one successful sync PR.

## Phase 5 — Rollback
- Remove extension IDs from resolver command(s) to disable behaviors.
- Keep layer files; clear local drift via repo-specific policy default/rebase and rerun sync in dry-run mode before reapply.
