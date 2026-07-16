# ADR — phenotype-ops

Repo-local architecture decisions for the Phenotype operations fleet.

---

## ADR-067 — Manifest Attestation CLI (phenotype-manifest)

**Status:** Accepted

**Context:** Every push across the ~100-repo Phenotype fleet requires a valid
`.manifest.signed.json`. Without attestation, CI runs full checks (2-5 min) —
with attestation, CI validates in ~5s.

**Decision:** Ship a Rust CLI (`tools/phenotype-manifest`) that generates,
signs, and verifies manifests covering 5 pillars: Quality, Security,
Performance, Compliance, Documentation.

**Rationale:** Rust provides fast startup (~ms), strong type safety for
manifest schema, and cross-compilation to macOS/Linux without a runtime
dependency. Verifiable pre-push gate reduces CI wall-clock by 20-60x.

**Fleet Cross-References:**
- ADR-040 (Test Coverage Gates per Tier) — manifest enforces coverage thresholds
- ADR-041 (71-Pillar Refresh Cadence) — manifest tracks pillar check versions
- ADR-042 (Security Audit Cadence) — security pillar in manifest schema
- ADR-043 (Registry Refresh Cadence) — manifest freshness ties to registry

---

## ADR-068 — Unified Code Review Surface

**Status:** Accepted

**Context:** Fleet-wide code review requires consistent enforcement of
organizational policies (lefthook, deny.toml, pillar checks) across all
repos. No single review surface existed before.

**Decision:** Build a FastAPI review surface (`review-surface/`) that serves
as the webhook router for unified code review. Consumed by all fleet repos
via org-level webhook.

**Rationale:** FastAPI provides async request handling for concurrent review
webhooks, Pydantic validation for payload schema, and easy deployment via
Docker/GHCR. One surface to maintain instead of per-repo review logic.

**Fleet Cross-References:**
- ADR-028 (Monorepo Hybrid-with-Staging) — review surface handles staging policy
- ADR-046 (Federation mTLS + OIDC) — webhook authentication layer
- ADR-048 (Substrate Graduation Path) — review surface enforces graduation gates
- ADR-049 (App-Substrate Drift Detector) — drift detection hook in review pipeline

---

## ADR-069 — Pillar Check Framework

**Status:** Accepted

**Context:** The 5 pillars (Quality, Security, Performance, Compliance,
Documentation) need executable check definitions that repos can run locally
and CI can enforce automatically.

**Decision:** Define pillar checks as versioned, schema-documented scripts
and configs in `pillars/`. Each pillar has a `run.sh` entry point, a
`schema.json` for output validation, and a `README.md` documenting the
check methodology.

**Rationale:** Versioned pillar definitions let repos pin to specific check
versions (via manifest). Schema-validated output ensures CI can parse and
display results consistently. Repos can run any pillar locally without CI.

**Fleet Cross-References:**
- ADR-024 (71-Pillar Audit Framework) — the 71 pillars that phenotype-ops owns
- ADR-041 (71-Pillar Refresh Cadence) — cadence for pillar check updates
- ADR-039 (pheno-flake Refresh Template) — pillar output format alignment
- ADR-048 (Substrate Graduation Path) — pillar check gates for graduation

---

## ADR-070 — Policy Federation from agent-devops-setups (Absorbed)

**Status:** Accepted

**Context:** The `agent-devops-setups` repo (formerly in `PhenoDevOps`) held
a 6-layer policy federation model, llama-cpp Docker serving, and VitePress
docs site. These were absorbed into `phenotype-ops` per L5-104.5.

**Decision:** Absorb the absorbed assets into `phenotype-ops/agent-devops-setups/`
with minimal restructuring. Keep the 6-layer federation (system, org, repo,
harness, user, override) intact. The `federate_policy.py` tool continues
to produce effective policy per (repo, harness) tuple.

**Rationale:** Consolidating all ops infrastructure into one repo reduces
discovery overhead. The federation model is mature and does not need
redesign — only maintenance and doc updates.

**Fleet Cross-References:**
- ADR-035 (Configra Migration Gates) — policy federation absorbed from Configra's scope
- ADR-031 (Configra Absorb) — predecessor absorption pattern
- ADR-025 (WORKLOG v2.1) — federation policy changes tracked via worklog
- ADR-046 (Federation mTLS + OIDC) — federation layer policy for service auth

---

## Fleet ADR Map

| Local ID | Fleet ADR | Subject |
|----------|-----------|---------|
| ADR-067 | ADR-067 | phenotype-ops Manifest Attestation CLI |
| ADR-068 | ADR-068 | phenotype-ops Unified Code Review Surface |
| ADR-069 | ADR-069 | phenotype-ops Pillar Check Framework |
| ADR-070 | ADR-070 | phenotype-ops Policy Federation (Absorbed) |

For the complete fleet-wide index covering ADR-001..074, see
[`docs/adr/INDEX.md`](../../docs/adr/INDEX.md).
