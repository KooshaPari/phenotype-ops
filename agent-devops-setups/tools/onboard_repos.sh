#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage:
  bash tools/onboard_repos.sh --harness <harness> --task-domain <domain> [--extensions <csv>] [--user <user>] [--repo-list <repo1,repo2>] [--sign-key <key>] [--mode <write|dry-run>]

Examples:
  bash tools/onboard_repos.sh --harness codex --task-domain agentops
  bash tools/onboard_repos.sh --harness claude --task-domain devops --extensions codex-gate --repo-list thegent,portage
USAGE
}

if [[ "$#" -lt 2 ]]; then
  print_usage
  exit 2
fi

HARNESS=""
TASK_DOMAIN="agentops"
USER="core-operator"
EXTENSIONS="codex-gate"
REPO_LIST="agent-devops-setups,thegent,template-commons,portage,heliosCLI,cliproxyapi++,agentapi-plusplus"
SIGN_KEY="${AGENT_POLICY_HMAC_KEY:-}"
MODE="write"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)
      HARNESS="$2"
      shift 2
      ;;
    --task-domain)
      TASK_DOMAIN="$2"
      shift 2
      ;;
    --user)
      USER="$2"
      shift 2
      ;;
    --extensions)
      EXTENSIONS="$2"
      shift 2
      ;;
    --sign-key)
      SIGN_KEY="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --repo-list)
      REPO_LIST="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1"
      print_usage
      exit 2
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_ROOT="$(cd "${ROOT}/.." && pwd)"
POLICY_TOOL="${ROOT}/tools/federate_policy.py"
SYNC_TOOL="${ROOT}/tools/sync_policy.sh"

if [[ -z "${HARNESS}" ]]; then
  echo "harness is required"
  exit 2
fi

if [[ "${MODE}" != "write" && "${MODE}" != "dry-run" ]]; then
  echo "invalid mode: ${MODE}. Use write or dry-run"
  exit 2
fi

IFS="," read -r -a REPOS <<< "${REPO_LIST}"

for repo in "${REPOS[@]}"; do
  repo="${repo// /}"
  repo_dir="${REPOS_ROOT}/${repo}"
  if [[ ! -d "${repo_dir}" ]]; then
    echo "skip missing repo: ${repo}"
    continue
  fi

  payload="/tmp/${repo}-effective-policy.json"
  if [[ -n "${SIGN_KEY}" ]]; then
    /usr/bin/python3 "${POLICY_TOOL}" \
      --repo "${repo}" \
      --harness "${HARNESS}" \
      --user "${USER}" \
      --task-domain "${TASK_DOMAIN}" \
      --extensions "${EXTENSIONS}" \
      --out "${payload}" \
      --strict \
      --sign-key "${SIGN_KEY}" \
      --repo-default default
  else
    /usr/bin/python3 "${POLICY_TOOL}" \
      --repo "${repo}" \
      --harness "${HARNESS}" \
      --user "${USER}" \
      --task-domain "${TASK_DOMAIN}" \
      --extensions "${EXTENSIONS}" \
      --out "${payload}" \
      --strict \
      --repo-default default
  fi

  bash "${SYNC_TOOL}" \
    --repo-root "${repo_dir}" \
    --payload "${payload}" \
    --mode "${MODE}"

  echo "onboarded: ${repo}"
done
