#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: repo-push-fallback.sh [OPTIONS] [BRANCH]

Repository-scoped push helper for Phenotype repos.
Pushes current branch to primary remote (default: upstream), then fallback remote (default: origin).

Options:
  --repo-root <path>            Repository root (default: current git repo)
  --primary-remote <remote>     Primary remote name (default: upstream)
  --fallback-remote <remote>    Fallback remote name (default: origin)
  --skip-primary                Skip primary remote and try fallback only
  --origin-objects-tmp-dir <d>  Override fallback local remote .tmp path
  --dry-run                     Log operations without network writes
  --skip-status                 Skip pre/post git status checks
  --help                        Show this help

Environment:
  PHENOTYPE_REPO_PUSH_LOG_FILE         Optional absolute log file (default: /tmp)
  PHENOTYPE_PUSH_DRY_RUN               Non-empty to force dry-run
  PHENOTYPE_PUSH_SKIP_STATUS            Non-empty to skip status output
USAGE
}

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '[%s] %s\n' "$ts" "$*"
}

error() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '[%s] ERROR: %s\n' "$ts" "$*" >&2
}

fail_with_hint() {
  error "$1"
  log "Hint:"
  log "  - Primary remote failure is expected when the remote branch is not in sync or network is unavailable."
  log "  - For local-airgapped fallback, verify upstream path is writable and objects/.tmp exists."
  return 1
}

run_push() {
  local remote="$1"
  local ref="$2"

  if [[ "$DRY_RUN" == 1 ]]; then
    log "[DRY-RUN] git push ${remote} ${ref}"
    return 0
  fi

  git push "$remote" "$ref"
}

is_local_path_remote() {
  local remote_url="$1"
  case "$remote_url" in
    /*|./*|../*) return 0 ;;
    [A-Za-z]:*) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_local_origin_ready() {
  local remote_url="$1"
  local objects_dir="$remote_url/objects"
  local tmp_dir="${ORIGIN_OBJECTS_TMP_DIR:-$objects_dir/.tmp}"

  if [[ "$SKIP_STATUS" == 1 ]]; then
    return 0
  fi

  if [[ ! -d "$remote_url" ]]; then
    error "Fallback remote path not found: $remote_url"
    return 1
  fi

  if [[ ! -d "$objects_dir" ]]; then
    error "Fallback remote objects path missing: $objects_dir"
    return 1
  fi

  if ! mkdir -p "$tmp_dir"; then
    error "Cannot create fallback temp dir: $tmp_dir"
    return 1
  fi

  if [[ ! -w "$tmp_dir" ]]; then
    error "Fallback temp dir is not writable: $tmp_dir"
    return 1
  fi

  return 0
}

check_remote_writable_hint() {
  local remote_name="$1"
  local remote_url="$2"

  if is_local_path_remote "$remote_url"; then
    if ! ensure_local_origin_ready "$remote_url"; then
      log "Local fallback remote failed writable check: $remote_url"
      return 1
    fi
    log "Local fallback remote writable check passed: $remote_name=$remote_url"
    return 0
  fi

  log "Remote '$remote_name' is non-local; skipping writable pre-check."
  return 0
}

parse_args() {
  while (($#)); do
    case "$1" in
      --repo-root)
        shift
        REPO_ROOT="$1"
        ;;
      --primary-remote)
        shift
        PRIMARY_REMOTE="$1"
        ;;
      --fallback-remote)
        shift
        FALLBACK_REMOTE="$1"
        ;;
      --skip-primary)
        SKIP_PRIMARY=1
        ;;
      --origin-objects-tmp-dir)
        shift
        ORIGIN_OBJECTS_TMP_DIR="$1"
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --skip-status)
        SKIP_STATUS=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --*)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        BRANCH="$1"
        ;;
    esac
    shift
  done
}

REPO_ROOT=""
PRIMARY_REMOTE="upstream"
FALLBACK_REMOTE="origin"
SKIP_PRIMARY=""
BRANCH="${GIT_BRANCH:-}"
ORIGIN_OBJECTS_TMP_DIR=""
DRY_RUN="${PHENOTYPE_PUSH_DRY_RUN:-}"
SKIP_STATUS="${PHENOTYPE_PUSH_SKIP_STATUS:-}"

parse_args "$@"

if [[ -z "$REPO_ROOT" ]]; then
  if ! REPO_ROOT="$(git rev-parse --show-toplevel)"; then
    error "Not inside a git repository. Set --repo-root explicitly."
    exit 1
  fi
fi

cd "$REPO_ROOT"

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

if [[ "$DRY_RUN" == 1 ]]; then
  log "Dry-run mode enabled"
fi

log "Using repo root: $REPO_ROOT"
log "Push branch: $BRANCH"
log "Primary remote: $PRIMARY_REMOTE, fallback remote: $FALLBACK_REMOTE"

if [[ -n "$SKIP_STATUS" ]]; then
  log "Status reporting disabled"
else
  log "Current status"
  git status --short --branch
fi

if [[ -z "$SKIP_PRIMARY" ]]; then
  log "Attempting push to $PRIMARY_REMOTE"
  if run_push "$PRIMARY_REMOTE" "$BRANCH"; then
    log "Primary push succeeded"
    if [[ "$SKIP_STATUS" == "" ]]; then
      git status --short --branch
      git log --oneline -n 5
    fi
    exit 0
  fi
  log "Primary push failed. Proceeding to fallback remote."
fi

if ! git remote get-url "$FALLBACK_REMOTE" >/dev/null 2>&1; then
  fail_with_hint "Fallback remote '$FALLBACK_REMOTE' is not configured."
  exit 1
fi

fallback_url="$(git remote get-url "$FALLBACK_REMOTE")"
if ! check_remote_writable_hint "$FALLBACK_REMOTE" "$fallback_url"; then
  fail_with_hint "Fallback remote writable check failed."
  exit 1
fi

log "Attempting push to $FALLBACK_REMOTE"
if run_push "$FALLBACK_REMOTE" "$BRANCH"; then
  log "Fallback push succeeded"
  if [[ "$SKIP_STATUS" == "" ]]; then
    git status --short --branch
    git log --oneline -n 5
  fi
  exit 0
fi

fail_with_hint "Both primary and fallback push attempts failed."
