# Agent DevOps Setups

This repo is the shared configuration fabric for multi-model agent tooling in the Phenotype
organization: policy federation, harness-specific overlays, task-domain scopes, and extension
runtime hooks for `Codex`, `Cursor-agent`, `Claude`, and `Factory-Droid`.

## Problem this solves

Current agent-level toolchains each support their own local override surfaces (`AGENTS.md`,
`CLAUDE.md`, `Cursor` rules, harness flags, etc.), which leads to drift.
This repository unifies those concerns by:

- Defining precedence-aware policy layers,
- Normalizing extension configuration across harnesses,
- Recording all decisions and merges in auditable artifacts.

## Directory layout

```text
agent-devops-setups/
├── policies/
│   ├── system/         # platform / org-wide defaults
│   ├── user/           # user/operator-level overrides
│   ├── harness/        # Codex / Cursor / Claude / Factory-Droid
│   ├── repo/           # per-repo behavior
│   ├── task-domain/    # per-domain behavior (agentops/ci/devops/...)
│   └── extensions/     # optional capability layers
├── extensions/
│   ├── manifests/      # cataloged extension packages
│   └── hooks/          # helper hook templates and docs
├── schemas/            # JSON schemas for policy and extensions
├── tools/
│   ├── federate_policy.py # resolves merged effective policy
│   └── sync_policy.sh     # write generated payload into repos
├── docs/               # audit notes and architecture docs
└── .github/workflows/  # optional validation/refresh automation
```

## Policy resolution model

Default layer order (low → high precedence):

1. `system` (org-wide defaults)
2. `user` (operator role overrides)
3. `harness` (tooling-specific behavior)
4. `repo` (repository-specific controls)
5. `task-domain` (domain-specific contracts)
6. `extensions` (explicitly selected extension packs)

Higher layers override keys from lower layers.

## Usage

```bash
# Build effective policy for a specific context
python tools/federate_policy.py \
  --repo agent-devops-setups \
  --harness codex \
  --user core-operator \
  --task-domain agentops \
  --extensions codex-gate,agentops-ci \
  --out /tmp/effective-policy.json

# Apply a policy payload into the repository path for local tooling
bash tools/sync_policy.sh \
  --repo-root /Users/kooshapari/CodeProjects/Phenotype/repos/thegent \
  --payload /tmp/effective-policy.json \
  --mode write

# Batch onboarding
bash tools/onboard_repos.sh \
  --harness codex \
  --task-domain agentops \
  --extensions codex-gate,agentops-ci \
  --user core-operator \
  --repo-list thegent,template-commons,portage,heliosCLI,cliproxyapi++,agentapi-plusplus

# Matrix onboarding (harness + task-domain)
bash tools/matrix_onboard.sh \
  --harnesses "codex,cursor-agent,claude,factory-droid" \
  --task-domains "agentops,devops" \
  --repo-list thegent,template-commons,portage,heliosCLI,cliproxyapi++,agentapi-plusplus

# Make targets
make help
make policy-sync        # codex + agentops full list
make policy-matrix      # matrix across harnesses and domains
make policy-matrix-dry  # same matrix in dry-run mode
```

## Expected outputs

- `effective_policy`: merged JSON object with all active policy keys.
- `applied_layers`: exact list of layer files used.
- `audit`: deterministic trace for forensics and review.

## Governance goals

- No silent precedence changes.
- No hidden defaults for critical controls.
- Full traceability from base policy to final resolved policy.
- Additive extension system that can be disabled by removing an extension manifest.

## Related tooling

- `AGENTS.md` and `CLAUDE.md` generation for repo surfaces.
- Harness hook policy (`extensions/hooks`).
- CI policy validation and PR gate gating via `.github/workflows`.

## Shared DevOps Helpers

Repository-level automation scripts live in `scripts/` and are consumed by
Phenotype repos that need consistent publish/checker behavior.

- `scripts/repo-push-fallback.sh`:
  publish helper with a primary remote first and local/remote fallback.
- `scripts/repo-devops-checker.sh`:
  lightweight DevOps gate checks for git health and optional `task ci` execution.

Recommended invocation pattern from a repo checkout:

```bash
# Optional override if repo layout differs from ../agent-devops-setups
export PHENOTYPE_DEVOPS_REPO_ROOT=/absolute/path/to/agent-devops-setups

# Optional per-command overrides
export PHENOTYPE_DEVOPS_PUSH_HELPER=$PHENOTYPE_DEVOPS_REPO_ROOT/scripts/repo-push-fallback.sh
export PHENOTYPE_DEVOPS_CHECKER_HELPER=$PHENOTYPE_DEVOPS_REPO_ROOT/scripts/repo-devops-checker.sh

bash /absolute/path/to/your/repo/scripts/push-heliosapp-with-fallback.sh
bash /absolute/path/to/your/repo/scripts/devops-checker.sh --check-ci --emit-summary
```

Because each repo may wire flags and defaults differently, keep a small local
wrapper script that forwards into these shared scripts with repo-local defaults.

## Validation commands

```bash
# Validate generated policy payload against schemas
python tools/validate_policy_payload.py \
  --payload /tmp/effective-policy.json \
  --policy-schema schemas/policy-resolution.schema.json \
  --manifest-schema schemas/extension-manifest.schema.json \
  --manifest-dir extensions/manifests \
  --strict
```

## Signing and rotation audit

```bash
# Emit signed policy payload
python tools/federate_policy.py \
  --repo thegent \
  --harness codex \
  --user core-operator \
  --task-domain agentops \
  --extensions codex-gate \
  --sign-key "$AGENT_POLICY_HMAC_KEY" \
  --out /tmp/effective-policy.json

# Verify signed payload
python tools/validate_policy_payload.py \
  --payload /tmp/effective-policy.json \
  --sign-key "$AGENT_POLICY_HMAC_KEY" \
  --strict

# Track rotation across repos
python tools/audit_policy_rotation.py \
  --repo-list thegent,template-commons,heliosCLI \
  --repo-root /Users/kooshapari/CodeProjects/Phenotype/repos \
  --state /tmp/policy-rotation-state.json \
  --out /tmp/policy-rotation-report.json

# Build PR package
python tools/build_pr_package.py
```
