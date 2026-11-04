#!/usr/bin/env bash
#
# Sets up an org (brand new or existing) to run Golden Helmet League:
#   1. Installs Nebula Logger (Unlocked Package, no namespace) if it isn't
#      already installed
#   2. Deploys force-app, running all local tests
#   3. Assigns the Commissioner permission set to the CLI's logged-in user,
#      plus any extra usernames passed in
#
# Safe to re-run: Nebula is skipped if already installed, and re-assigning
# a permission set someone already has is a no-op.
#
# Usage:
#   scripts/setup-org.sh <org-alias> [username ...]
#   npm run setup-org -- <org-alias> [username ...]

set -euo pipefail

# Nebula Logger v4.19.5, Unlocked Package (no namespace). To upgrade, swap in
# the new 04t... id from https://github.com/jongpie/NebulaLogger and update
# the README's install links to match.
NEBULA_PACKAGE_ID="04tg7000000IzRdAAK"
NEBULA_PACKAGE_NAME="Nebula Logger - Unlocked Package"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <org-alias> [username ...]" >&2
  exit 1
fi

ORG="$1"
shift
EXTRA_USERS=("$@")

if ! command -v sf >/dev/null 2>&1; then
  echo "The Salesforce CLI (sf) isn't installed: https://developer.salesforce.com/tools/salesforcecli" >&2
  exit 1
fi

# Run from the repo root so --source-dir force-app resolves wherever this is called from.
cd "$(dirname "$0")/.."

echo "==> [1/3] Checking for Nebula Logger in '$ORG'..."
if sf package installed list --target-org "$ORG" --json | grep -q "\"$NEBULA_PACKAGE_NAME\""; then
  echo "    Already installed, skipping."
else
  echo "    Not found, installing $NEBULA_PACKAGE_ID (this can take a few minutes)..."
  sf package install \
    --package "$NEBULA_PACKAGE_ID" \
    --security-type AdminsOnly \
    --no-prompt \
    --wait 30 \
    --target-org "$ORG"
fi

echo "==> [2/3] Deploying force-app to '$ORG' and running local tests..."
sf project deploy start \
  --source-dir force-app \
  --test-level RunLocalTests \
  --wait 60 \
  --target-org "$ORG"

echo "==> [3/3] Assigning the Commissioner permission set..."
# Re-assigning a permission set someone already has comes back as a
# "Duplicate PermissionSetAssignment" failure, so treat that as already done
# and only fail on anything else.
assign_commissioner() {
  local output failures duplicates
  if output=$(sf org assign permset --name Commissioner "$@" --target-org "$ORG" --json); then
    echo "    Assigned."
    return
  fi
  failures=$(grep -c '"message"' <<<"$output" || true)
  duplicates=$(grep -c 'Duplicate PermissionSetAssignment' <<<"$output" || true)
  if [[ $failures -gt 0 && $failures -eq $duplicates ]]; then
    echo "    Already assigned."
  else
    echo "$output" >&2
    exit 1
  fi
}

assign_commissioner

# Separate call: --on-behalf-of replaces the logged-in user rather than adding to it.
if [[ ${#EXTRA_USERS[@]} -gt 0 ]]; then
  ON_BEHALF_OF=()
  for user in "${EXTRA_USERS[@]}"; do
    ON_BEHALF_OF+=(--on-behalf-of "$user")
  done
  assign_commissioner "${ON_BEHALF_OF[@]}"
fi

echo
echo "Done. Next, follow the rest of the README's Initial Set up (custom settings, connected app, Experience site)."
