# phenotype-pin

Securely pin GitHub Actions to commit SHAs in workflow files.

## Why

The 2026-06-19 fleet-wide SHA-pin sweep corrupted ~50 workflow files. Root cause:
a previous auto-pin tool concatenated the GitHub API 404 response to a SHA when
the lookup failed, producing patterns like:

```yaml
# CORRUPTED
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11@{"message":"Not Found","documentation_url":"https://docs.github.com/rest/git/refs#get-a-reference"}

# ALSO CORRUPTED (over-escaping of Go template syntax)
go-version: $123matrix.go-version125
```

This tool **never** silently appends API responses to SHAs — it fails loudly (exit
code 2) when a SHA can't be resolved, preserving the input file untouched.

## Usage

```bash
# Detect corruption only (no modifications)
phenotype-pin.py --check-only .github/workflows/*.yml

# Detect + fix
phenotype-pin.py --fix .github/workflows/*.yml

# Sweep all fleet repos (prints cd instructions for each)
phenotype-pin.py --fleet
```

## Exit codes

| Code | Meaning                                              |
|------|------------------------------------------------------|
| 0    | Success: no corruption, or all corruption fixed      |
| 1    | Generic failure                                       |
| 2    | SHA lookup failed (tool refuses to corrupt)           |
| 3    | Corruption detected but not auto-fixed (run `--fix`) |
| 4    | Post-write validation failed                          |

## Canonical SHAs

The `KNOWN_VERSIONS` table maps `(owner/repo, version)` → SHA, sourced from
`phenotype-tooling/templates/reusable-quality-gate.yml` (last verified 2026-06-19).
When a workflow file uses an action not in this table, the tool:

1. Strips any trailing `@{"message":...}` API-error suffix (safe).
2. Leaves the existing SHA in place (refuses to fabricate).
3. Logs the line as `actions_fixed: owner/repo@<sha-stripped>`.

To extend the known SHA table, edit `KNOWN_VERSIONS` and PR.

## Detected corruption patterns

| Pattern | Repair |
|---------|--------|
| `@<40 hex chars>@{"message":"Not Found"...}` | Strip the `@{...}` suffix |
| `@<40 hex chars>@<40 hex chars>` (two SHAs concatenated) | Drop the older (left) SHA, keep the newer (right) |
| `$<digit 2-3><var><digit 2-3>` where var is alphanumeric+`.`+`-` | Replace with `${{ var }}` |
| Action without version comment (`uses: foo/bar@SHA` with no `# vX`) | Report only (don't auto-modify) |

### Why three patterns?

The original fleet sweep (2026-06-19) introduced two patterns. A follow-up
discovery (2026-06-20 11:04 PDT) found that `portage/release.yml` and
`portage/ci.yml` had a *third* pattern: two SHAs back-to-back, e.g.

```yaml
# CORRUPTED (double-SHA concatenation)
uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5@11bd71901bbe5b1630ceea73d27597364c9af683
#                  ^^^^^^^^^^ old SHA ^^^^^^^^^^^^  ^^^^^^^^^^ new (canonical) SHA ^^^^^^^^^^^^
```

This was missed by both the original sweep and the initial `phenotype-pin`
detection regex. The fix drops the older SHA and keeps the newer one. See
`findings/2026-06-20-fleet-sha-corruption-sweep.md` § "Double-SHA follow-up".

## Validation

After a `--fix` run, validate the result with:

```bash
actionlint .github/workflows/*.yml
```
