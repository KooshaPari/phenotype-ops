# Known Issues

## Consolidation inputs

### Migrated legacy session index

---
audience: [developers, agents, pms]
---

# Sessions

This directory contains session-led work bundles for active and historical waves.

## Structure

Each session should live under:

`docs/sessions/<YYYYMMDD-descriptive-name>/`

and should normally contain:

- `00_SESSION_OVERVIEW.md`
- `01_RESEARCH.md`
- `02_SPECIFICATIONS.md`
- `03_DAG_WBS.md`
- `04_IMPLEMENTATION_STRATEGY.md`
- `05_KNOWN_ISSUES.md`
- `06_TESTING_STRATEGY.md`

## Rules

- Keep transient execution evidence inside the session bundle.
- Promote only durable repo-wide guidance into canonical docs.
- Update the active session bundle continuously so later waves can resume cleanly.


## Repository session-state notes
- Legacy worklog/session index fragments were present and consolidated here to avoid canonical drift.
- Canonical session docs were created in `docs/sessions/20260328-root-docsites-worklog-consolidation` as part of this cleanup wave.
