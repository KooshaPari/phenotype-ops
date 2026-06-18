#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage:
  bash tools/matrix_onboard.sh \
    [--harnesses <h1,h2>] \
    [--task-domains <d1,d2>] \
    [--extensions <ext1,ext2>] \
    [--domain-maps "<domain>:<ext1>|<ext2>,<domain>:<ext3>"] \
    [--user <user>] \
    [--repo-list <repo1,repo2>] \
    [--sign-key <key>] \
    [--mode <write|dry-run>]

Examples:
  bash tools/matrix_onboard.sh --harnesses "codex,cursor-agent,claude,factory-droid" --task-domains "agentops,devops"
  bash tools/matrix_onboard.sh --harnesses codex --task-domains agentops,devops --repo-list thegent,portage
USAGE
}

if [[ "$#" -lt 1 ]]; then
  print_usage
  exit 2
fi

HARNESSES="codex,cursor-agent,claude,factory-droid"
TASK_DOMAINS="agentops,devops"
USER="core-operator"
EXTENSIONS="codex-gate"
REPO_LIST="agent-devops-setups,thegent,template-commons,portage,heliosCLI,cliproxyapi++,agentapi-plusplus"
SIGN_KEY="${AGENT_POLICY_HMAC_KEY:-}"
MODE="write"
DOMAIN_EXT_MAP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harnesses)
      HARNESSES="$2"
      shift 2
      ;;
    --task-domains)
      TASK_DOMAINS="$2"
      shift 2
      ;;
    --extensions)
      EXTENSIONS="$2"
      shift 2
      ;;
    --domain-maps)
      DOMAIN_EXT_MAP="$2"
      shift 2
      ;;
    --user)
      USER="$2"
      shift 2
      ;;
    --repo-list)
      REPO_LIST="$2"
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
    *)
      echo "unknown argument: $1"
      print_usage
      exit 2
      ;;
  esac
done

if [[ "${MODE}" != "write" && "${MODE}" != "dry-run" ]]; then
  echo "invalid mode: ${MODE}. Use write or dry-run"
  exit 2
fi

get_domain_extensions() {
  local domain="$1"
  local default_ext="$2"
  local map="$3"
  local mapped=""

  if [[ -z "${map}" ]]; then
    echo "${default_ext}"
    return 0
  fi

  IFS=',' read -r -a entries <<< "${map}"
  for entry in "${entries[@]}"; do
    entry="${entry// /}"
    [[ -z "${entry}" ]] && continue
    map_key="${entry%%:*}"
    map_val="${entry#*:}"
    if [[ "${map_key}" == "${domain}" ]]; then
      mapped="${map_val}"
      break
    fi
  done

  if [[ -n "${mapped}" ]]; then
    echo "${mapped}"
  else
    echo "${default_ext}"
  fi
}

IFS=',' read -r -a HARNESS_ARR <<< "${HARNESSES}"
IFS=',' read -r -a DOMAIN_ARR <<< "${TASK_DOMAINS}"

for harness in "${HARNESS_ARR[@]}"; do
  harness="${harness// /}"
  [[ -z "${harness}" ]] && continue

  for domain in "${DOMAIN_ARR[@]}"; do
    domain="${domain// /}"
    [[ -z "${domain}" ]] && continue

    active_exts="$(get_domain_extensions "${domain}" "${EXTENSIONS}" "${DOMAIN_EXT_MAP}")"
    echo "matrix start: harness=${harness} task_domain=${domain} extensions=${active_exts}"

    bash "$(dirname "$0")/onboard_repos.sh" \
      --harness "${harness}" \
      --task-domain "${domain}" \
      --user "${USER}" \
      --extensions "${active_exts}" \
      --repo-list "${REPO_LIST}" \
      ${SIGN_KEY:+--sign-key "${SIGN_KEY}"} \
      --mode "${MODE}"
  done
done

echo "matrix complete"
