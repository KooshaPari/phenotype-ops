# Functional Requirements — agent-devops-setups

FR IDs follow the pattern `FR-{CAT}-{NNN}`.

---

## FR-RES — Policy Resolution (`tools/federate_policy.py`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-RES-001 | `federate_policy.py` SHALL load policy layers in the fixed order: `system/base`, `system/security-guard`, `user/<user>`, `harness/<harness>`, `repo/<repo>`, `task-domain/<domain>`, then extension fragments | E1.1 | Implemented |
| FR-RES-002 | `federate_policy.py` SHALL perform a recursive deep merge of all loaded layers such that higher-precedence layers overwrite scalar values of lower layers while preserving non-conflicting nested keys | E1.1 | Implemented |
| FR-RES-003 | When `repo/<repo>.json` is absent and `--strict` is not set, `federate_policy.py` SHALL fall back to `repo/default.json` before skipping the layer | E1.1 | Implemented |
| FR-RES-004 | `federate_policy.py` SHALL compute a SHA-256 digest of the canonical JSON encoding (sorted keys, no extraneous whitespace) of `{scope, policy, applied_layers}` and store it in `audit.policy_digest` | E1.2 | Implemented |
| FR-RES-005 | When `--sign-key` is provided, `federate_policy.py` SHALL compute `HMAC-SHA256(sign_key, policy_digest)` and store the hex digest in `audit.policy_signature` | E1.2 | Implemented |
| FR-RES-006 | `federate_policy.py` SHALL store a UTC ISO-8601 timestamp in `audit.generated_at` | E1.2 | Implemented |
| FR-RES-007 | `federate_policy.py` SHALL list all layer file paths actually loaded (in resolution order) in `audit.files` | E1.2 | Implemented |
| FR-RES-008 | When `--strict` is passed, `federate_policy.py` SHALL raise `FileNotFoundError` listing all missing layer files if any required layer file is absent | E1.3 | Implemented |
| FR-RES-009 | When `--strict` is not passed, `federate_policy.py` SHALL skip missing layer files, record them in `audit.missing` (if present), and continue resolution | E1.3 | Implemented |
| FR-RES-010 | The output payload SHALL include a `resolver_version` field set to `"agent-devops-setups/federation-v1"` | E1.2 | Implemented |

---

## FR-EXT — Extension Manifest System (`extensions/`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-EXT-001 | Extension manifests SHALL be JSON files located at `extensions/manifests/<name>.json` and SHALL validate against `schemas/extension-manifest.schema.json` | E2.1 | Implemented |
| FR-EXT-002 | The resolver SHALL merge the `fragment` key of each requested extension manifest into the resolved policy under `policy.extensions.<name>` | E2.1 | Implemented |
| FR-EXT-003 | Extension manifests without a `fragment` key SHALL be accepted and SHALL contribute an empty policy fragment (no merge effect) | E2.1 | Implemented |
| FR-EXT-004 | The extension catalog SHALL include `agentops-ci`, `codex-gate`, and `dot-agents-bridge` manifests, each schema-valid | E2.2 | Implemented |
| FR-EXT-005 | `agentops-ci` manifest SHALL define CI-scoped behaviour overrides that restrict destructive operations during automated CI runs | E2.2 | Implemented |
| FR-EXT-006 | `codex-gate` manifest SHALL define confirmation-required gates for Codex operations classified as destructive | E2.2 | Implemented |
| FR-EXT-007 | `dot-agents-bridge` manifest SHALL define a fragment enabling the runtime adapter to consume `AGENTS.md` policy files | E2.2 | Implemented |

---

## FR-SYNC — Policy Sync and Onboarding (`tools/sync_policy.sh`, `tools/matrix_onboard.sh`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-SYNC-001 | `sync_policy.sh` SHALL accept a target repository path and a resolved policy file path and write the policy to the target repo under a deterministic sub-path | E3.1 | Implemented |
| FR-SYNC-002 | `sync_policy.sh` SHALL be idempotent: executing it twice with the same inputs SHALL produce no additional changes to the target repository | E3.1 | Implemented |
| FR-SYNC-003 | `sync_policy.sh` SHALL exit non-zero and print an actionable error message when the target repository is not writable or the resolved payload fails schema validation | E3.1 | Implemented |
| FR-SYNC-004 | `matrix_onboard.sh` SHALL process each repository in the provided list, invoking `federate_policy.py` then `sync_policy.sh` for each | E3.2 | Implemented |
| FR-SYNC-005 | `matrix_onboard.sh` SHALL report per-repo status (success / skip / fail) to stdout and SHALL exit non-zero if any repo fails, without aborting processing of subsequent repos | E3.2 | Implemented |

---

## FR-CHK — Repository Health Checker (`scripts/repo-devops-checker.sh`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-CHK-001 | `repo-devops-checker.sh` SHALL inspect a target repository for the presence of the deployed policy payload file | E3.3 | Implemented |
| FR-CHK-002 | `repo-devops-checker.sh` SHALL validate the deployed payload against `schemas/policy-resolution.schema.json` | E3.3 | Implemented |
| FR-CHK-003 | `repo-devops-checker.sh` SHALL print the `audit.policy_digest` of the deployed payload to stdout | E3.3 | Implemented |
| FR-CHK-004 | `repo-devops-checker.sh` SHALL exit 1 if the payload file is absent, if schema validation fails, or if the digest does not match an expected value when one is provided as an argument | E3.3 | Implemented |

---

## FR-SEC — Security Guard Policy (`policies/system/security-guard.json`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-SEC-001 | `policies/system/security-guard.json` SHALL define a `tool_contracts.shell.forbidden_default` list containing shell command patterns that are unconditionally denied without explicit user consent | E4.1 | Implemented |
| FR-SEC-002 | `policies/system/base.json` SHALL set `consent_rules.destructive_actions` to `"ask"` | E4.1 | Implemented |
| FR-SEC-003 | `policies/system/base.json` SHALL set `consent_rules.network_access` to `"ask_on_unknown_hosts"` | E4.2 | Implemented |
| FR-SEC-004 | Individual harness policy files SHALL NOT set `consent_rules.destructive_actions` to a value that is less restrictive than the system-level setting | E4.1 | Implemented |
| FR-SEC-005 | The CI security guard workflow SHALL validate all `policies/**/*.json` and `extensions/**/*.json` files against their respective schemas on every push and pull request to main | E4.3 | Implemented |
| FR-SEC-006 | The CI security guard workflow SHALL run secret-pattern detection on all changed files and SHALL fail the build on any detected secret | E4.3 | Implemented |

---

## FR-VAL — Schema Validation (`schemas/`, `tools/validate_policy_payload.py`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-VAL-001 | `schemas/policy-resolution.schema.json` SHALL define the required structure for resolved policy payloads, including `resolver_version`, `scope`, `policy`, `applied_layers`, and `audit` | E5.1 | Implemented |
| FR-VAL-002 | `schemas/extension-manifest.schema.json` SHALL define the required structure for extension manifests | E5.1 | Implemented |
| FR-VAL-003 | `tools/validate_policy_payload.py` SHALL accept a payload file path, validate it against `schemas/policy-resolution.schema.json`, and exit non-zero with a descriptive error on validation failure | E5.1 | Implemented |
| FR-VAL-004 | `.github/workflows/validate-policy.yml` SHALL run `validate_policy_payload.py` on all changed `policies/` files on every push and pull request | E5.1 | Implemented |

---

## FR-AUD — Policy Audit Tooling (`tools/audit_policy_rotation.py`)

| ID | SHALL Statement | Traces To | Status |
|----|-----------------|-----------|--------|
| FR-AUD-001 | `audit_policy_rotation.py` SHALL enumerate all policy layer files in `policies/` and report their last-modified git commit timestamp | E5.2 | Implemented |
| FR-AUD-002 | `audit_policy_rotation.py` SHALL flag any policy layer file not modified within the past 90 days as "stale" | E5.2 | Implemented |
| FR-AUD-003 | `audit_policy_rotation.py` SHALL output a machine-readable JSON report listing each file, its last-modified timestamp, staleness flag, and last-modifying commit hash | E5.2 | Implemented |
