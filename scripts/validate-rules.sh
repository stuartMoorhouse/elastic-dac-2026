#!/usr/bin/env bash
set -euo pipefail

RULES_DIR="detection-rules/custom-rules"

check_deps() {
  if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not installed." >&2
    exit 1
  fi

  if ! python3 -c "import detection_rules" &>/dev/null 2>&1; then
    echo "Error: elastic-detection-rules Python package is not installed." >&2
    echo "Install it with: pip install elastic-detection-rules" >&2
    exit 1
  fi
}

check_deps

mapfile -t toml_files < <(find "$RULES_DIR" -name "*.toml" 2>/dev/null || true)

if [[ ${#toml_files[@]} -eq 0 ]]; then
  echo "Warning: no .toml files found in $RULES_DIR" >&2
  exit 0
fi

failed=0

for file in "${toml_files[@]}"; do
  if python3 -m detection_rules validate-rule "$file" &>/dev/null 2>&1; then
    echo "PASS: $file"
  else
    echo "FAIL: $file"
    python3 -m detection_rules validate-rule "$file" || true
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "Validation failed — fix the errors above before deploying." >&2
  exit 1
fi

echo "All rules passed validation."
