#!/usr/bin/env bash
# governance/SETUP-RULESETS.sh
# Idempotent GitHub repository rulesets setup for the Phenotype fleet.
# Implements the Rainbow Branch Model — see governance/RAINBOW-MODEL.md.
#
# Usage:
#   bash governance/SETUP-RULESETS.sh                # apply to current repo
#   bash governance/SETUP-RULESETS.sh --dry-run      # preview payloads only
#   bash governance/SETUP-RULESETS.sh --repo OWNER/NAME
#
# Idempotent: re-running on an already-configured repo prints
# "ALREADY EXISTS: <name>" for each existing ruleset and exits 0.
#
# DEFERRED: live apply requires admin token + human review.
#           Run --dry-run to preview; live apply is human-gated.

set -euo pipefail

DRY_RUN=false
REPO_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage: bash governance/SETUP-RULESETS.sh [--dry-run] [--repo OWNER/NAME]

Options:
  --dry-run         Print payloads that would be POSTed; do not call gh api
  --repo OWNER/NAME Override target repo (default: current via gh repo view)
  -h, --help        Show this help
EOF
}

# ----- Argument parsing -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "ERROR: --repo requires OWNER/NAME argument" >&2; exit 1; }
      REPO_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ----- Preflight -----
command -v gh >/dev/null 2>&1 \
  || { echo "ERROR: gh CLI not found (install: https://cli.github.com)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 \
  || { echo "ERROR: jq not found (install: brew install jq)" >&2; exit 1; }
gh auth status >/dev/null 2>&1 \
  || { echo "ERROR: gh CLI not authenticated (run: gh auth login)" >&2; exit 1; }

# ----- Resolve target repo -----
if [[ -n "$REPO_OVERRIDE" ]]; then
  REPO="$REPO_OVERRIDE"
else
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi
if [[ -z "$REPO" || "$REPO" == "null" ]]; then
  echo "ERROR: could not determine repo (pass --repo OWNER/NAME)" >&2
  exit 1
fi

echo "Target repo: $REPO"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Mode: DRY-RUN (no API calls will be made)"
fi

# ----- Payload builders (compact JSON, formatted via jq in dry-run) -----

payload_dev() {
  cat <<'JSON'
{"name":"dev-branches","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["refs/heads/dev/**"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":true}},{"type":"non_fast_forward"}],"bypass_actors":[]}
JSON
}

payload_alpha() {
  cat <<'JSON'
{"name":"alpha-branches","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["refs/heads/alpha/**"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":2,"dismiss_stale_reviews_on_push":true,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":true}},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"phenotype-manifest-gate"}]}},{"type":"required_linear_history"}],"bypass_actors":[]}
JSON
}

payload_beta() {
  cat <<'JSON'
{"name":"beta-branches","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["refs/heads/beta/**"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":2,"dismiss_stale_reviews_on_push":true,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":true}},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"phenotype-manifest-gate"},{"context":"phenotype-full-ci-fallback"}]}},{"type":"required_linear_history"},{"type":"required_deployments","parameters":{"required_deployment_environments":["beta"]}}],"bypass_actors":[]}
JSON
}

payload_stable() {
  cat <<'JSON'
{"name":"stable-branches","target":"branch","enforcement":"active","conditions":{"ref_name":{"include":["refs/heads/(main|stable/**|rc/**)"],"exclude":[]}},"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":3,"dismiss_stale_reviews_on_push":true,"require_code_owner_review":true,"require_last_push_approval":true,"required_review_thread_resolution":true}},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"phenotype-manifest-gate"},{"context":"phenotype-full-ci-fallback"},{"context":"phenotype-sbom-attestation"}]}},{"type":"required_linear_history"},{"type":"required_deployments","parameters":{"required_deployment_environments":["production"]}},{"type":"codeowners"}],"bypass_actors":[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}]}
JSON
}

# ----- Apply (or preview) a single ruleset -----
# Args: name payload
apply_ruleset() {
  local name="$1" payload="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "----- DRY-RUN: POST repos/$REPO/rulesets (name=$name) -----"
    echo "Payload:"
    echo "$payload" | jq .
    return 0
  fi

  # Capture full response (headers + body) into a single string.
  local response
  response=$(gh api "repos/$REPO/rulesets" \
    --method POST --input - --include \
    <<< "$payload" 2>&1 || true)

  local http_code
  http_code=$(echo "$response" | head -1 | awk '{print $2}')

  if [[ "$http_code" == "201" ]]; then
    local rule_id
    rule_id=$(echo "$response" | awk '/^\{/{found=1} found' | jq -r '.id // "?"' 2>/dev/null) || rule_id="?"
    echo "APPLIED: $name (id=$rule_id) — https://github.com/$REPO/rules/$rule_id"
    return 0
  fi

  if [[ "$http_code" == "422" ]]; then
    echo "ALREADY EXISTS: $name"
    return 0
  fi

  echo "ERROR applying $name (HTTP $http_code):" >&2
  echo "PAYLOAD:" >&2; echo "$payload" >&2
  echo "RESPONSE:" >&2; echo "$response" >&2
  return 1
}

# ----- Apply all 4 rulesets -----
APPLIED=0
TOTAL=4

apply_ruleset "dev-branches"    "$(payload_dev)"   && APPLIED=$((APPLIED + 1)) || true
apply_ruleset "alpha-branches"  "$(payload_alpha)" && APPLIED=$((APPLIED + 1)) || true
apply_ruleset "beta-branches"   "$(payload_beta)"  && APPLIED=$((APPLIED + 1)) || true
apply_ruleset "stable-branches" "$(payload_stable)" && APPLIED=$((APPLIED + 1)) || true

echo ""
echo "Applied $APPLIED/$TOTAL rulesets to $REPO"

# In dry-run, exit 0 always. In live mode, exit non-zero if not all applied.
if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi
if [[ "$APPLIED" -ne "$TOTAL" ]]; then
  exit 1
fi
exit 0