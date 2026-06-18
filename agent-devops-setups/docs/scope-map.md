# Scope Map

## Scope hierarchy and precedence

```text
system -> user -> harness -> repo -> task-domain -> extensions
```

## File ownership and priority

| Scope | Layer directory | Example key | Priority |
|---|---|---|---|
| System | `policies/system/` | `base.json`, `security-guard.json` | 0 |
| User | `policies/user/` | `core-operator.json` | 1 |
| Harness | `policies/harness/` | `codex.json`, `claude.json`, `cursor-agent.json`, `factory-droid.json` | 2 |
| Repo | `policies/repo/` | `thegent.json`, `template-commons.json` | 3 |
| Task-domain | `policies/task-domain/` | `agentops.json`, `devops.json` | 4 |
| Extensions | `extensions/manifests/` | `codex-gate.json`, `agentops-ci.json`, `dot-agents-bridge.json` | 5 |

## Optional fallback behavior

- Repo-specific layer fallback: if `policies/repo/<repo>.json` is missing and `--repo-default` is provided, resolver uses `policies/repo/<repo-default>.json`.
- In non-strict mode, missing layers for non-fallback scopes are skipped with trace output in source listing.
- In strict mode, all required non-fallback layers must exist.

## Federation outputs

- `docs/agent-policy/effective-policy.json`: merged policy payload for target repository.
- `docs/agent-policy/sources.json`: ordered list of policy layers and manifests that contributed.
- `audit.policy_digest` in payload for integrity/reproducibility checks.

## Recommended run order for new repo onboarding

1. Pick repo ID and harness ID.
2. Add `policies/repo/<repo>.json` (optional initially; fallback supported).
3. Generate and sync:

```bash
python3 tools/federate_policy.py \
  --repo <repo> \
  --harness <harness> \
  --user <user> \
  --task-domain <domain> \
  --extensions <exts> \
  --out /tmp/effective-policy.json
```

4. Sync into repo:

```bash
bash tools/sync_policy.sh \
  --repo-root /path/to/<repo> \
  --payload /tmp/effective-policy.json \
  --mode write
```

5. Verify `docs/agent-policy/{effective-policy.json,sources.json}` and required checks in target repo.
