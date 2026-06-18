# Architecture

## Federation model

The effective policy is computed from immutable layer fragments:

```text
system -> user -> harness -> repo -> task-domain -> extensions
```

The model is additive and declarative. A harness never mutates system policy; it only contributes a
higher-precedence overlay. This avoids merge conflicts and keeps governance intent explicit.

## Resolution algorithm

1. Build ordered layer list from CLI input.
2. Normalize required layer IDs:
   - `system` and `extensions` default to `base` when not explicitly provided.
3. Parse each JSON layer file if present.
4. Deep-merge dictionaries; lists are replaced by the highest-precedence list.
5. Emit:
   - `effective_policy`
   - `applied_layers` (ordered provenance list)
   - `policy_digest` for integrity tracking.

## Extension system

Extensions are declared using JSON manifests under `extensions/manifests`.
Each manifest can inject:

- policy fragments (`fragment` key),
- hook contracts (`hooks`),
- task/domain-specific constraints (`constraints`),
- external integrations (`integrations`).

Extensions can be selected per command using `--extensions`, and they are evaluated last.

## Sync targets

`tools/sync_policy.sh` is intentionally generic:

- write resolved policy to target repository `docs/agent-policy/effective.json`,
- create `docs/agent-policy/sources.json` with applied layers,
- fail if required policy keys are missing in dry-run mode.

The sync step is safe to run repeatedly because outputs are deterministic.
