<!-- markdownlint-disable MD041 -->
## Summary

<!-- Brief description of the change (1–3 sentences). -->

## Linked Issues / ADRs

<!-- Link any related issues, ADRs, or upstream PRs. -->
- Closes #
- Related: ADR-###

## Pillars Touched

<!-- Mark all that apply. -->
- [ ] Quality
- [ ] Security
- [ ] Performance
- [ ] Compliance
- [ ] Docs
- [ ] Pillar definitions (`/pillars/`)
- [ ] Reusable workflows (`/.github/workflows/`)
- [ ] Manifest CLI (`/tools/phenotype-manifest/`)
- [ ] Review surface (`/review-surface/`)
- [ ] Governance (`/governance/`)
- [ ] Agent DevOps Setups (`/agent-devops-setups/`)

## Verification

<!-- Describe how this was tested. -->
- [ ] `just fmt` passes
- [ ] `just clippy` passes
- [ ] `just test` passes
- [ ] `cargo check` (for Rust changes) passes
- [ ] `manifest-verify` (if manifest schema changed) passes
- [ ] Local pre-commit hooks (`lefthook run pre-commit`) pass

## Manifest Impact

<!-- Does this change affect the phenotype-manifest CLI, schema, or signing key? -->
- [ ] No manifest impact
- [ ] Manifest schema changed (version bump required)
- [ ] Public keys or trust roots changed
- [ ] Pillar definitions added/removed/renamed

## Breaking Changes

<!-- If yes, link the migration guide. -->
- [ ] No breaking changes
- [ ] Breaking change — see migration notes

## Checklist

- [ ] Commit message follows `type(scope): subject` (Conventional Commits)
- [ ] `CHANGELOG.md` updated (if user-facing)
- [ ] No secrets, tokens, or `.env` material committed
- [ ] Self-reviewed against `CODEOWNERS` ownership boundaries
