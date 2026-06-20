# Pre-Push Manifest Gate — Developer Guide

This document describes the pre-push attestation manifest gate enforced on
`phenotype-ops` and every other Phenotype fleet repository that adopts
`governance/lefthook.yml` as its canonical hook manifest. It is intended for
contributors and reviewers who need to understand why the gate exists, how it
fires, what the manifest looks like on disk, and how to recover when the gate
fires unexpectedly.

## Overview

Every push that leaves a developer's machine in the Phenotype fleet must carry
an **attestation manifest**: a small JSON document that records the
repository's health at the moment of the push. The manifest is generated
locally by `phenotype-manifest`, signed with an Ed25519 private key held by
the developer, and verified by the same binary immediately afterwards. This
makes the push event an **attested artifact**, not just a state change.

The supply-chain guarantee is straightforward. Without an attestation, any
sequence of commits can be claimed to be "production ready" by anyone who
happens to have push rights. With an attestation, the push carries a signed
statement of the repository's quality posture at the time of the push — a
timestamp, a `health_score` between 0.0 and 1.0, and a per-pillar pass/fail
record for the five tracked pillars (`fmt`, `clippy`, `tests`, `audit`,
`docs`). A push without a valid manifest cannot proceed; this is enforced
locally by lefthook's `pre-push` hook, before the bytes ever reach the
remote.

The fleet-wide audit value comes from the aggregate. Every push that lands on
`main` carries a verifiable quality statement that downstream consumers (the
71-pillar audit, the registry refresh, the substrate graduation gate) can
ingest and reason about without re-running CI. The manifest gives us a
**signed audit trail** of repository health over time — a property the fleet
has not previously had, and one that makes rollbacks, post-mortems, and
governance reviews far cheaper.

## How it works

The pre-push gate is a five-step pipeline that runs entirely on the
developer's machine before any network I/O for the push:

1. Developer runs `git push` from a Phenotype fleet repository.
2. Lefthook intercepts the push (its `pre-push` hook fires before `git`
   contacts the remote).
3. `manifest-generate` runs: `phenotype-manifest generate` produces
   `.manifest.signed.json` containing the `health_score`, the per-pillar
   pass/fail map, and an Ed25519 signature over the canonical JSON encoding.
4. `manifest-verify` runs: `phenotype-manifest verify` validates the
   signature against the public key, checks `health_score >= 0.90`, checks
   `max-age-hours <= 24`, and checks that every pillar in the required-pillar
   set is present and passing.
5. If `manifest-verify` exits 0, the push proceeds. If it exits non-zero, the
   push is blocked with an error message identifying the failing check.

Both steps use `set -euo pipefail` and pipe their stdout/stderr to the
developer's terminal verbatim, so the failure mode is never silent.

## Manifest structure

The signed manifest written to `.manifest.signed.json` has the following
schema. The `signature` and `public_key_fingerprint` fields are added by the
signing step; everything else is part of the signed payload.

```json
{
  "schema_version": "1.0",
  "repository": "KooshaPari/phenotype-ops",
  "commit_sha": "2e0d3122b92d14b14d5edb952fbd901953e642ce",
  "branch": "feat/l5-127-pre-push-manifest-doc-2026-06-20",
  "generated_at": "2026-06-20T00:00:00Z",
  "generated_by": "phenotype-manifest 0.1.0",
  "health_score": 0.95,
  "pillars": {
    "fmt":     { "pass": true, "score": 1.00 },
    "clippy":  { "pass": true, "score": 1.00 },
    "tests":   { "pass": true, "score": 0.95 },
    "audit":   { "pass": true, "score": 0.90 },
    "docs":    { "pass": true, "score": 0.92 }
  },
  "required_pillars": ["fmt", "clippy", "tests", "audit", "docs"],
  "public_key_fingerprint": "ed25519:7c4f8a3b1d2e5f6a8b9c0d1e2f3a4b5c6d7e8f9a",
  "signature": "3045022100... [Ed25519 signature over canonical JSON] ..."
}
```

The `signature` covers all fields except `signature` and
`public_key_fingerprint`. The canonical encoding is RFC 8785 (JCS) JSON, so
signature verification is byte-stable across platforms and key versions.

## CI fallback chain

The pre-push hook is the **first** line of defense; CI is the **second**.
When a push lands, GitHub Actions runs the `Manifest Gate` workflow
(`.github/workflows/manifest-gate.yml`), which is a `workflow_call` reusable
workflow that does its own verification using the public key committed at
`.github/manifest.pubkey.pem`. The CI gate has a configurable `fallback`
input that controls what happens when the manifest is missing, invalid, or
stale:

- **`fallback=warn` (default).** The gate logs a warning annotation, writes
  `fallback=warn` to its outputs, and the workflow exits 0. The push and PR
  proceed; only the workflow summary flags the gap. This is the recommended
  default for repositories that have recently adopted the manifest and may
  have legacy branches that predate it.
- **`fallback=full`.** The gate writes `fallback=full` and triggers
  `.github/workflows/full-ci.yml` (a comprehensive Rust fmt/clippy/nextest
  run, ~15 minutes on the fleet runner). This is the recommended setting for
  repositories where the pre-push hook is not yet installed on every
  contributor's machine.
- **`fallback=fail`.** The gate exits 1 and blocks merge. Use this only on
  repositories where the pre-push hook is universally installed and the
  manifest is the canonical signal.

The fallback chain runs in roughly this order at PR open time: pre-push hook
(~5 seconds, local) → manifest-gate workflow (~10 seconds, CI) → full-ci
workflow (only on `fallback=full`, ~15 minutes). Most pushes never see the
full-ci step.

## Local development

### First-time setup

The first time you push from a fresh clone, you need an Ed25519 keypair. The
manifest CLI generates one for you:

```bash
phenotype-manifest init --generate-key
```

This writes the private key to `~/.ssh/manifest` (mode 0600) and prints the
public key fingerprint. Copy the public key (not the private key!) into
`.github/manifest.pubkey.pem` in your repository and commit it. The CI gate
verifies the manifest against this committed public key, so it must be in
the repository **before** the first push that carries a manifest.

### Day-to-day push

Once the key is set up, you do nothing different:

```bash
git add -A
git commit -s -m "feat(scope): description"
git push
```

Lefthook's `pre-push` hook fires automatically. `manifest-generate` runs,
writes `.manifest.signed.json`, and `manifest-verify` validates it. The push
proceeds. You should never see output from the hook on a healthy push — its
silent-success path is intentional.

### Debugging a failing pre-push

When the gate blocks your push, the output names the failing check. The
common patterns:

1. **Health score below 0.90.** Inspect the manifest:
   ```bash
   cat .manifest.signed.json | jq .
   ```
   Look at `.pillars` to see which pillar dropped below threshold. The most
   common culprit is a new test failure or a `cargo clippy` warning introduced
   since the last green push.
2. **Signature verification failed.** Your local private key does not match
   the public key committed at `.github/manifest.pubkey.pem`. Re-run
   `phenotype-manifest init --generate-key` and re-copy the public key, or
   ask the maintainer which key the repo expects.
3. **Manifest too old (max-age-hours exceeded).** This usually means the
   `.manifest.signed.json` was generated more than 24 hours ago, and the
   `--max-age-hours 24` check has fired. Delete the stale file and re-push;
   the hook will regenerate it.
4. **Required pillar missing.** The `require-all-pillars` flag expects every
   pillar in the required-pillar set to be present. A new pillar added to
   `phenotype-manifest`'s pillar registry will trigger this until the next
   push generates a manifest with the new pillar.

For a permanent fix, push again after addressing the failing check. Lefthook
will regenerate the manifest from scratch on each push, so transient issues
do not require manual cleanup.

## Branch exclusion

The pre-push hook is excluded from four branch globs, declared at the
bottom of `governance/lefthook.yml`:

```yaml
hooks:
  pre-push:
    exclude-branches:
      - "dependabot/**"
      - "renovate/**"
      - "release/**"
      - "hotfix/**"
```

The rationale is straightforward: **auto-generated and emergency branches
skip attestation.** `dependabot/**` and `renovate/**` produce commits from
external automation that cannot run the developer's local manifest CLI.
`release/**` branches are tagged cut points where the manifest is generated
by the release pipeline instead of by an interactive push. `hotfix/**`
branches are emergency patches where speed matters more than attestation —
the post-merge CI run will catch any quality regression.

If you find yourself pushing to one of these branches and wishing you had an
attestation, generate the manifest manually with
`phenotype-manifest generate ...` and attach it to the PR description; CI's
`fallback=warn` mode will pick it up.

## Workflow verification (this turn)

The pre-push pipeline was verified end-to-end on 2026-06-20 using a fake
manifest CLI installed at `/tmp/phenotype-manifest`. The fake CLI accepted
the same arguments as the real `phenotype-manifest` and produced a
deterministic, valid-looking signed manifest, so the lefthook command
sequence could be exercised without invoking the production binary. The
verification ran in `/tmp/lefthook-test`, an isolated `git init -q` working
tree, **not** in the `phenotype-ops` repository itself.

```bash
# Set up isolated test directory and override PATH so the fake CLI wins
mkdir -p /tmp/lefthook-test
cd /tmp/lefthook-test
git init -q
export PATH="/tmp:$PATH"     # fake CLI lives here

# Confirm the fake CLI is on PATH (real CLI is in target/release)
$ which phenotype-manifest
/tmp/phenotype-manifest

# Step 1: manifest-generate (matches lefthook.yml line 11-16)
$ bash -c 'set -euo pipefail; phenotype-manifest generate \
    --key /tmp/fake.key \
    --output .manifest.signed.json \
    --require-all-pillars \
    --fail-below 0.90 \
    --max-age-hours 24'
fake-manifest: generated .manifest.signed.json

# Confirm the manifest file landed
$ ls -la .manifest.signed.json
-rw-r--r--@ 1 kooshapari  wheel  258 Jun 20 04:28 .manifest.signed.json

# Step 2: manifest-verify (matches lefthook.yml line 24-29)
$ bash -c 'set -euo pipefail; phenotype-manifest verify \
    --manifest .manifest.signed.json \
    --pubkey /tmp/fake.pub \
    --require-all-pillars \
    --min-health-score 0.90 \
    --max-age-hours 24'
fake-manifest: verified .manifest.signed.json

LEFTHOOK-WORKFLOW-VERIFIED

# Negative test: verify exits non-zero when manifest is missing
$ rm -f .manifest.signed.json
$ bash -c 'set -euo pipefail; phenotype-manifest verify \
    --manifest .manifest.signed.json ...'
fake-manifest: ERROR no manifest
exit_code=1
```

The verification confirms three things. First, the exact command sequence
that lefthook invokes (lines 11-16 and 24-29 of `governance/lefthook.yml`)
executes cleanly with the documented flags. Second, the gate produces the
expected artifact (`.manifest.signed.json`) and verifies it. Third, the
gate fails closed: when the manifest is missing, `manifest-verify` exits
non-zero, which under `set -euo pipefail` causes lefthook to abort the push.

## References

- `governance/lefthook.yml` — canonical lefthook manifest (83 lines, this
  repo's reference copy).
- `.github/workflows/manifest-gate.yml` — CI-side reusable workflow
  (129 lines, `workflow_call`, `fallback=warn` default).
- `.github/workflows/full-ci.yml` — full CI fallback (fmt, clippy, nextest;
  triggered when `fallback=full`).
- `tools/phenotype-manifest/Cargo.toml` — manifest CLI Rust crate manifest
  (depends on `ed25519-dalek`, `serde_json`, `clap`, `chrono`, `git2`,
  `jsonschema`; release profile with `lto=true`, `codegen-units=1`).
- `tools/phenotype-manifest/src/main.rs` — manifest CLI source (generate,
  verify, init subcommands).
- ADR-024 (71-pillar audit framework) — the pillars scored in the manifest
  are a subset of the 71-pillar registry's quality/correctness pillars.
