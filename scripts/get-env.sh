#!/usr/bin/env bash
set -euo pipefail

check_deps() {
  for cmd in terraform jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is required but not installed." >&2
      exit 1
    fi
  done
}

check_deps
mkdir -p shared
terraform -chdir=terraform output -json > shared/env.json
echo "Environment written to shared/env.json"
