#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage:
  bash tools/sync_policy.sh --repo-root /path/to/repo --payload /tmp/policy.json --mode [dry-run|write]
USAGE
}

if [ "$#" -lt 3 ]; then
  print_usage
  exit 2
fi

REPO_ROOT=""
PAYLOAD=""
MODE="dry-run"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --payload)
      PAYLOAD="$2"
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

if [[ -z "${REPO_ROOT}" || -z "${PAYLOAD}" ]]; then
  echo "missing required args"
  print_usage
  exit 2
fi

if [[ ! -f "${PAYLOAD}" ]]; then
  echo "payload file not found: ${PAYLOAD}"
  exit 1
fi

OUT_DIR="${REPO_ROOT}/docs/agent-policy"
mkdir -p "${OUT_DIR}"

if [[ "${MODE}" != "write" && "${MODE}" != "dry-run" ]]; then
  echo "invalid mode: ${MODE}. Use dry-run or write"
  exit 2
fi

if [[ "${MODE}" == "write" ]]; then
  cp "${PAYLOAD}" "${OUT_DIR}/effective-policy.json"
  REPO_ROOT_ENV="${REPO_ROOT}" PAYLOAD_ENV="${PAYLOAD}" /usr/bin/python3 - <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["PAYLOAD_ENV"]).read_text())
sources = payload.get("audit", {}).get("files", [])
Path(f"{os.environ['REPO_ROOT_ENV']}/docs/agent-policy/sources.json").write_text(
    json.dumps(sources, indent=2) + "\n", encoding="utf-8"
)
PY
  echo "sync complete: write"
else
  echo "dry-run: resolved files"
  cat "${PAYLOAD}"
fi
