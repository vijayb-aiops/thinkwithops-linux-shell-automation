#!/usr/bin/env bash
# Requires GNU or BusyBox date with -d support for timestamp generation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLEANER="${PROJECT_ROOT}/src/log_cleaner.sh"

require_date_d() {
  if date -d "10 days ago" +%Y%m%d%H%M.%S >/dev/null 2>&1; then
    return 0
  fi
  echo "date -d is required for this test" >&2
  exit 1
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_date_d

TEMP_DIR=$(mktemp -d /tmp/log-cleaner-test-XXXX)
trap 'rm -rf "${TEMP_DIR}"' EXIT

OLD_FILE="${TEMP_DIR}/old.log"
NEW_FILE="${TEMP_DIR}/new.log"

# Create files
: > "${OLD_FILE}"
: > "${NEW_FILE}"

old_ts=$(date -d "10 days ago" +%Y%m%d%H%M.%S)
touch -t "${old_ts}" "${OLD_FILE}"

echo "Running dry-run..."
dry_output=$("${CLEANER}" --dirs "${TEMP_DIR}" --retention 7 --dry-run)

# Old file should be listed but not deleted
printf '%s' "${dry_output}" | grep -q "${OLD_FILE}" || fail "Old file not reported in dry-run"
[[ -f "${OLD_FILE}" ]] || fail "Old file deleted during dry-run"
[[ -f "${NEW_FILE}" ]] || fail "New file missing after dry-run"

echo "Running real cleanup..."
"${CLEANER}" --dirs "${TEMP_DIR}" --retention 7 --run >/dev/null

[[ ! -f "${OLD_FILE}" ]] || fail "Old file was not deleted"
[[ -f "${NEW_FILE}" ]] || fail "New file deleted unexpectedly"

echo "[PASS] log_cleaner basic retention behavior verified"
