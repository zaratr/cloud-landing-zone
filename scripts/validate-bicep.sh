#!/usr/bin/env bash
# Local Bicep validation — the same check the CI workflow runs, but runnable
# from a dev machine with the Azure CLI installed.
#
# Usage:
#   ./scripts/validate-bicep.sh
#
# Requires: az (Azure CLI) with the bicep extension (`az bicep install`).
set -euo pipefail

if ! command -v az &>/dev/null; then
  echo "ERROR: Azure CLI (az) is not installed. Install from https://aka.ms/azure-cli"
  exit 1
fi

echo "Validating Bicep templates..."
failed=0
for f in $(find . -name '*.bicep' -not -path './.git/*'); do
  printf "  %-50s " "$f"
  if az bicep build --file "$f" --stdout >/dev/null 2>&1; then
    echo "OK"
  else
    echo "FAIL"
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then
  echo ""
  echo "All Bicep templates valid."
else
  echo ""
  echo "ERROR: one or more templates failed validation." >&2
  exit 1
fi
