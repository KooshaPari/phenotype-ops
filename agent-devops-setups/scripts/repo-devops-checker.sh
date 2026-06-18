#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: repo-devops-checker.sh [OPTIONS]

Run shared Phenotype DevOps checks for a repository.

Options:
  --repo-root <path>   Repository root (default: current git repo)
  --check-ci           Run full task ci pipeline
  --emit-summary       Output compact JSON summary at the end
  --help               Show this help
USAGE
}

REPO_ROOT=""
CHECK_CI=0
EMIT_SUMMARY=0
status="pass"

while (($#)); do
  case "$1" in
    --repo-root)
      shift
      REPO_ROOT="$1"
      ;;
    --check-ci)
      CHECK_CI=1
      ;;
    --emit-summary)
      EMIT_SUMMARY=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
 done

if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT="$(git rev-parse --show-toplevel)"; then
    echo "Not inside a git repository. Set --repo-root explicitly." >&2
    exit 1
  fi
fi

cd "$REPO_ROOT"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

run_check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd"; then
    log "PASS: $label"
  else
    log "FAIL: $label"
    status="fail"
    return 1
  fi
}

log "Running DevOps check suite at $REPO_ROOT"

run_check "git-command" "command -v git >/dev/null"
run_check "git-repo" "test -d .git"
run_check "git-remotes" "git remote | grep -q ."
run_check "git-clean" "git status --short --untracked-files=normal >/dev/null"

if [[ "$CHECK_CI" == 1 ]]; then
  if [[ ! -f Taskfile.yml ]]; then
    log "FAIL: Taskfile.yml missing"
    status="fail"
  else
    run_check "task-ci" "task ci"
  fi
fi

if [[ "$EMIT_SUMMARY" == 1 ]]; then
  printf '{"repo":"%s","status":"%s"}\n' "$(basename "$REPO_ROOT")" "$status"
fi

if [[ "$status" == "pass" ]]; then
  log "DevOps checks passed"
  exit 0
fi

echo "DevOps checks failed" >&2
exit 1
