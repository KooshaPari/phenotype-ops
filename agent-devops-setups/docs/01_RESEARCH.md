# Tooling comparison notes (initial)

## Scope and objective

Evaluate `dot-agents` and adjacent tooling for layered agent governance across harnesses (`Codex`, `Cursor-agent`, `Claude`, `Factory-Droid`) with policy federation by scope:
`system -> user -> harness -> repo -> task-domain -> extensions`.

## Primary reference set

- [dot-agents overview](https://www.dot-agents.com/)
- [Cursor Rules](https://docs.cursor.com/context/rules-for-ai)
- [Cursor CLI agent](https://docs.cursor.com/en/cli/using)
- Open-source ecosystem guidance around AGENTS.md and MCP interoperability

## Comparison: dot-agents vs repo-centric federation

| Capability | dot-agents | repo-centric federation (`agent-devops-setups`) |
|---|---|---|
| Config unification across tools | Strong via shared `~/.agents/` home and manifest-driven symlink model | Strong via deterministic policy artifacts published to each repo (`docs/agent-policy`) |
| Scope layering | Global → Agent → Project | `system -> user -> harness -> repo -> task-domain -> extensions` with explicit precedence |
| Artifact location | Primarily developer machine config | Version-controlled per-repo artifacts + federated policy source files |
| Tool-specific parity | Multi-tool intent with hooks, but harness-specific behavior can vary by implementation | Explicit harness overlays for each supported tool in `policies/harness/` |
| Drift control | Strong if synced through conventions | Strong with tracked layer files + `policy_digest` + source traces |
| Team rollout | Good for local developer profiles and team sharing | Best for org policy control, CI validation, and repo-level reproducibility |
| Policy auditability | Medium (depends on local tooling cadence) | High (`effective-policy.json`, `sources.json`, file list, hash digest) |

## Complementary / tangential tooling reviewed

- `AGENTS.md` / `CLAUDE.md` conventions
  - Good for local instruction context.
  - Weak at cross-harness federation unless resolved into a single policy surface.
- Cursor `.cursor/rules`
  - Strong for cursor-native scope but Cursor/agent-specific and not sufficient for harness-wide governance.
- MCP tool ecosystems
  - Strong for tool exposure/security.
  - Not sufficient alone for precedence, repository/domain policy merge semantics.
- CI automation / governance workflows
  - Good enforcement layer.
  - Needs deterministic payload inputs from policy federation.

## Adjacent and complementary candidates in org stack

- Factory-specific wrappers: `Factory-Droid`, local hook dispatchers
  - Good for execution adapters, command bootstrap, and local observability.
- Lint/CI policy checks (`.github/workflows`)
  - Good enforcement sink for this repo's outputs.
- OpenAI `AGENTS.md`-style instruction contracts
  - Useful at repo/project instruction layer; now consumed as input to federation, not the sole source of truth.

## Recommendation

Use a two-layer model:
1) `dot-agents`-style local convenience and personal config unification, where desired;
2) `agent-devops-setups` as the org-source-of-truth federation layer for reproducible repo-level policy and cross-harness behavior.

That gives practical parity with dot-agents while preserving deterministic CI-ready artifacts for all target repos.
