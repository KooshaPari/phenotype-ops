# Rainbow Branch Model — Phenotype Fleet

The Rainbow Branch Model is a layered promotion strategy that maps code
maturity to a color tier. Every change flows up through six concentric
layers — `dev`, `alpha`, `beta`, `rc`, `stable`, and finally `sunset` — with
each layer raising the bar on review rigor, CI gating, and deployment
guardrails. The model is implemented as a stack of GitHub repository
rulesets (see [`governance/SETUP-RULESETS.sh`](SETUP-RULESETS.sh)) that
enforce the same gating everywhere a Phenotype repo runs. The same color
lexicon shows up in fleet-wide status reports and in CI workflow names so
operators can read a branch name and immediately know its maturity and
required process.

## Why six layers

A six-layer model sits at the sweet spot between two failure modes. With
too few layers (for example, the trunk-only `main + release/**` model) the
bar for every commit is the same as the bar for a hotfix to production, so
contributors get blocked by production-grade checks on routine work and
the team loses the signal between "drafted" and "shipped". With too many
layers (eight or more) the model collapses under its own weight: every
promotion requires a PR review, the pipeline stalls, and contributors
shortcut the process by pushing directly to whatever branch will accept
their push. Six layers gives each transition a distinct meaning — drafts,
integration, soak, release-candidate, production, archive — and each
layer carries its own enforcement profile so the cost of promotion scales
with the cost of regression.

The Phenotype fleet picked six because the existing tooling already
naturally falls into three pairs:

- **draft vs integration**: `dev/**` and `alpha/**` differ by reviewer
  count (1 vs 2) and whether linear history is enforced.
- **soak vs candidate**: `beta/**` and `rc/**` differ by which CI gates
  block the merge and whether a deployment is required.
- **production vs archive**: `stable/**` (main, stable, rc) and
  `sunset/**` differ by whether CODEOWNERS approval and an admin
  signature are required.

Each pair can be tuned independently, and the operator reading a CI run
log can locate the failure to a specific transition without ambiguity.

## Layered diagram

The six layers stacked from most permissive (top) to most strict (bottom):

```
   +------------+    +-----------+    +----------+    +--------+
   |    dev     |    |   alpha   |    |   beta   |    |   rc   |
   |  dev/**    | -> | alpha/**  | -> | beta/**  | -> | rc/**  |
   +-----+------+    +-----+-----+    +----+-----+    +----+---+
         |                |               |               |
         |  1 approval    |  2 approvals  |  2 approvals  |  3 approvals
         |  manifest-gate |  manifest-    |  manifest-    |  all CI gates
         |                |  gate + linear|  gate + full- |  + sbom-attest
         |                |  history      |  ci-fallback  |
         |                |               |  + linear     |  tag + smoke
         |                |               |  + deploy to  |
         |                |               |  beta env     |
   +-----+----------------+----------------+---------------+--------+
   |
   v
   +--------------+    +----------+
   |   stable     |    |  sunset  |
   | main,        | -> | sunset/  |
   | stable/**,   |    | <era>/** |
   | rc/**        |    |          |
   +------+-------+    +----------+
          |
          |  3 approvals + admin bypass
          |  all CI + sbom-attest + CODEOWNERS
          |  deploy to production + admin signature
          |
          |  (write-protect after 30 d)
          v
       archive
```

Each upward arrow is a pull request; each downward arrow is a deprecation
into the sunset layer.

## Layer reference

| Layer  | Branch glob                            | Required approvals    | CI gate                                                                              | Manual steps                          | Sunset after       | Owner              |
|--------|----------------------------------------|-----------------------|--------------------------------------------------------------------------------------|---------------------------------------|--------------------|--------------------|
| dev    | `dev/**`                               | 1                     | `phenotype-manifest-gate`                                                            | none                                  | n/a                | contributors       |
| alpha  | `alpha/**`                             | 2                     | `phenotype-manifest-gate`                                                            | none                                  | n/a                | maintainers        |
| beta   | `beta/**`                              | 2                     | `phenotype-manifest-gate` + `phenotype-full-ci-fallback`                              | deploy to `beta` environment         | n/a                | release captain    |
| rc     | `rc/**`                                | 3                     | all gates (manifest + full-ci-fallback + sbom-attestation)                           | tag + smoke test                      | n/a                | release captain    |
| stable | `main`, `stable/**`, `rc/**`           | 3 + admin bypass      | all gates + `phenotype-sbom-attestation` + CODEOWNERS                                | deploy to `production` + admin sig    | 90 d               | fleet admins       |
| sunset | `sunset/2024-Q4/**`, `sunset/<era>/**` | 0 (write-protect)     | none                                                                                 | read-only after 30 d                  | 365 d post-deprec  | governance circle  |

## Branch naming convention

Every branch in the fleet follows a `<layer>/<owner>/<slug>` pattern so the
layer is identifiable at a glance. Examples:

- `dev/alice/fix-typo-in-readme` — draft work by contributor alice.
- `alpha/bob/refactor-config-loader` — integration work by maintainer bob.
- `beta/carol/release-2026-q3` — soak branch owned by release captain carol.
- `rc/dave/release-2026-q3-rc1` — release candidate for the q3 release.
- `main` — production head; the only stable branch without a `<layer>/`
  prefix because it is the canonical trunk.
- `stable/2026-q3` — production release line for q3 (release captain owns).
- `sunset/2024-q4/legacy-payments` — archived branch from the 2024-q4 era.

The `<owner>` slot makes accountability searchable in `git log` and the
GitHub UI; the `<slug>` slot carries the human-readable description. CI
workflows use the layer prefix to choose the right gate set (manifest-gate
vs full-ci-fallback vs sbom-attestation).

## Promotion path

A change moves through the layers in this order:

- **dev → alpha**: open a PR targeting any `alpha/*` branch; requires 1
  approving review and a green `phenotype-manifest-gate`; auto-merge on
  green; non-fast-forward blocks force-pushes but allows squash merges.
- **alpha → beta**: open a PR targeting any `beta/*` branch; requires 2
  approving reviews, a green `phenotype-manifest-gate`, and linear history
  (no merge commits).
- **beta → rc**: open a PR targeting any `rc/*` branch; requires 2
  approving reviews, all CI gates, and a successful deployment to the
  `beta` environment.
- **rc → stable**: open a PR targeting `main`, `stable/*`, or the same
  `rc/*`; requires 3 approving reviews, CODEOWNERS approval, all CI gates
  (manifest + full-ci-fallback + sbom-attestation), and an admin signature;
  deploys to `production`.
- **stable → sunset**: when a stable branch is retired, the maintainer
  renames it to `sunset/<era>/<original-name>` and the governance circle
  write-protects it.

Each step is gated by both human approval and machine verification; manual
deploy/smoke steps are only required at `beta` (deploy), `rc` (tag + smoke),
and `stable` (deploy + admin signature).

## Bypass and rollback

- Admins (RepositoryRole `actor_id: 5`) bypass the `stable-branches`
  ruleset via the `bypass_actors` configuration. Use this only for emergency
  rollback; the SBOM attestation still gates the merge.
- For `rc → stable` emergencies, the admin signature acts as a one-shot
  override; record the rationale in the PR description and link the
  incident ticket.
- Rollback procedure: revert the merge commit on `main`, force-push is
  blocked by the ruleset, so create a revert PR instead and follow the
  normal promotion path back through the layers.

## Sunset policy

When a layer is retired — for example, when `beta` is deprecated because
`rc` absorbs its role — every affected branch is moved to the
`sunset/<era>/**` glob, write-protected (admin still has bypass), and
retained on disk for 90 days before hard delete. The retention period gives
downstream consumers a window to fetch final artifacts. The governance
circle owns the deletion checklist and runs it bi-weekly. Branches that
are write-protected for more than 30 days become read-only as an additional
safeguard against accidental edits during the cool-down window.

## Enforcement summary

The four rulesets, mapped to the layers they enforce:

| Ruleset              | Branch pattern                   | Rule set                                                                                                |
|----------------------|----------------------------------|---------------------------------------------------------------------------------------------------------|
| `dev-branches`       | `refs/heads/dev/**`              | 1 PR approval + review-thread resolution + non-fast-forward                                            |
| `alpha-branches`     | `refs/heads/alpha/**`            | 2 PR approvals + `phenotype-manifest-gate` + linear history                                             |
| `beta-branches`      | `refs/heads/beta/**`             | 2 PR approvals + all status checks + linear history + required deployment to `beta` env                |
| `stable-branches`    | `refs/heads/(main\|stable/**\|rc/**)` | 3 PR approvals + CODEOWNERS + all status checks + linear history + required deployment to `production` + admin bypass actor |

## Setup

Apply all four rulesets in one shot:

```bash
bash governance/SETUP-RULESETS.sh                 # apply to current repo
bash governance/SETUP-RULESETS.sh --dry-run       # preview payloads only
bash governance/SETUP-RULESETS.sh --repo OWNER/NAME
```

The script is idempotent — re-running on an already-configured repo prints
`ALREADY EXISTS: <name>` for each existing ruleset and exits 0. Live apply
is deferred to a human-gated step that requires an admin-scoped token; the
default `gh auth` session on most workstations does not carry the
`delete_repo` scope needed for full repo administration, so apply goes
through a privileged CI runner or the GitHub UI.

## References

- [`governance/SETUP-RULESETS.sh`](SETUP-RULESETS.sh) — idempotent `gh api`
  script that applies the four rulesets described above.
- [`governance/AGENTS.base.md`](AGENTS.base.md) — base AGENTS template for
  Phenotype repos; references the Rainbow model under "Branch strategy".
- [`governance/CLAUDE.base.md`](CLAUDE.base.md) — base CLAUDE template.
- [`governance/lefthook.yml`](lefthook.yml) — pre-commit and pre-push hooks.
- `docs/adr/2026-06-15/ADR-023-agent-effort-governance.md` — agent-effort
  governance that motivates the dev/alpha separation (contributors vs
  maintainers).
- `docs/adr/2026-06-19/ADR-050-t12-monorepo-state-deletion-complete.md` —
  precedent for write-protecting sunset branches before delete.
- `docs/adr/2026-06-20/ADR-050-router-rebuild.md` — router-rebuild ADR
  that consumed the Rainbow model in practice (rc → stable promotion).
- `docs/adr/2026-06-20/ADR-051-bifrost-as-library.md` — bifrost-as-library
  ADR, also a Rainbow-model consumer.
- GitHub REST API reference for repository rulesets:
  <https://docs.github.com/en/rest/repos/repos#create-a-repository-ruleset>.