# Hook templates and integration entrypoints

This folder stores cross-harness hook contract examples. For now we keep lightweight
templates so automation layers can call them as they are enabled through policy extensions.

- `agentops-pre-task.sh` (planned): pre-task policy check
- `agentops-post-task.sh` (planned): post-task merge/audit step
- `governance-sync.sh` (planned): mirror effective policy into repo docs

Hook execution is intentionally minimal in this scaffold and can be wired to toolchain jobs
as needed.
