# CHANGELOG — phenotype-ops

All notable changes to this project are documented here. Format follows
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Versioning
follows [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — 2026-06-18

### Changed
- **Configra migration note (L5-110, ADR-031).** Per [ADR-031](https://github.com/KooshaPari/repos/blob/main/docs/adr/2026-06-17/ADR-031-configra-absorb.md),
  the canonical Rust config substrate is now `KooshaPari/Configra`
  (formerly `KooshaPari/phenotype-config`). phenotype-ops does not
  currently depend on `phenotype-config` or `Configra` directly; the
  fleet-wide policy is to consume `Configra` via the standard config
  cascade when a new config concern arises. No code changes required
  for phenotype-ops itself.

### Notes
- This repo has no `phenotype-config` Cargo.toml dep (verified 2026-06-18).
- The phenotype-manifest CLI does not consume any config crate.
- Any future config-related work in phenotype-ops should import from
  `Configra` (e.g. `configra = { git = "https://github.com/KooshaPari/Configra" }`)
  not from `phenotype-config` (which is DEPRECATED, archive 2026-07-15).
- See: `findings/2026-06-18-L5-110-configra-absorption.md` for the full
  migration matrix.
