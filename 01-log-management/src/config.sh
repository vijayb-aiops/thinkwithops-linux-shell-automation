#!/usr/bin/env bash
set -euo pipefail

# Default configuration values
LOG_DIRS=("/var/log")
FILE_PATTERN="*.log"
RETENTION_DAYS=7
MIN_FREE_PCT=15
REPORT_DIR="../output/reports"
STATE_DIR="../output/state"
RUN_LOG="../output/run.log"
DRY_RUN_DEFAULT="true"
MAX_DELETE_COUNT=5000

# Allow environment variables to override defaults at runtime
load_env_overrides() {
  if [[ -n "${LOG_DIRS_OVERRIDE:-}" ]]; then
    # shellcheck disable=SC2206
    LOG_DIRS=(${LOG_DIRS_OVERRIDE})
  fi
  FILE_PATTERN=${FILE_PATTERN_OVERRIDE:-${FILE_PATTERN}}
  RETENTION_DAYS=${RETENTION_DAYS_OVERRIDE:-${RETENTION_DAYS}}
  MIN_FREE_PCT=${MIN_FREE_PCT_OVERRIDE:-${MIN_FREE_PCT}}
  REPORT_DIR=${REPORT_DIR_OVERRIDE:-${REPORT_DIR}}
  STATE_DIR=${STATE_DIR_OVERRIDE:-${STATE_DIR}}
  RUN_LOG=${RUN_LOG_OVERRIDE:-${RUN_LOG}}
  DRY_RUN_DEFAULT=${DRY_RUN_DEFAULT_OVERRIDE:-${DRY_RUN_DEFAULT}}
  MAX_DELETE_COUNT=${MAX_DELETE_COUNT_OVERRIDE:-${MAX_DELETE_COUNT}}
}

# Ensure required directories exist
ensure_dirs() {
  mkdir -p "${REPORT_DIR}" "${STATE_DIR}" "$(dirname "${RUN_LOG}")"
}
