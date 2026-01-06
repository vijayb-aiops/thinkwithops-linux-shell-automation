#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

on_error() {
  local exit_code=$?
  echo "[ERROR] log_cleaner failed with exit code ${exit_code}" >&2
  exit 5
}
trap on_error ERR

# Resolve relative paths against the project root
resolve_path() {
  local path=$1
  if [[ "${path}" == /* ]]; then
    echo "${path}"
  else
    echo "${SCRIPT_DIR}/${path}"
  fi
}

is_tty() {
  [[ -t 1 ]]
}

setup_colors() {
  if is_tty; then
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_RED="\033[0;31m"
    COLOR_RESET="\033[0m"
  else
    COLOR_GREEN=""; COLOR_YELLOW=""; COLOR_RED=""; COLOR_RESET=""
  fi
}

print_usage() {
  cat <<'USAGE'
Usage: log_cleaner.sh [--dry-run|--run] [--dirs "dir1 dir2"] [--retention DAYS] [--pattern PATTERN] [--report]

Options:
  --dry-run        Preview deletions (default)
  --run            Perform deletions
  --dirs           Space-separated list of directories to manage (default from config)
  --retention      Days to keep (default from config)
  --pattern        File name pattern to match (default from config)
  --report         Write a report file to REPORT_DIR
  -h, --help       Show this help
USAGE
}

safe_dir() {
  local dir=$1
  if [[ -z "${dir}" || "${dir}" == "/" ]]; then
    return 1
  fi
  [[ -d "${dir}" ]]
}

load_env_overrides
setup_colors

# Defaults
DRY_RUN=${DRY_RUN_DEFAULT}
REPORT_FLAG="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="true"; shift ;;
    --run)
      DRY_RUN="false"; shift ;;
    --dirs)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --dirs" >&2; print_usage; exit 2; }
      # shellcheck disable=SC2206
      LOG_DIRS=($1)
      shift ;;
    --retention)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --retention" >&2; print_usage; exit 2; }
      RETENTION_DAYS=$1
      shift ;;
    --pattern)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --pattern" >&2; print_usage; exit 2; }
      FILE_PATTERN=$1
      shift ;;
    --report)
      REPORT_FLAG="true"; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 2 ;;
  esac
done

# Resolve paths relative to project root
REPORT_DIR="$(resolve_path "${REPORT_DIR}")"
STATE_DIR="$(resolve_path "${STATE_DIR}")"
RUN_LOG="$(resolve_path "${RUN_LOG}")"

ensure_dirs

first_dir=${LOG_DIRS[0]:-}
if [[ -z "${first_dir}" ]]; then
  echo "${COLOR_RED}[FAIL] No log directories configured${COLOR_RESET}" >&2
  exit 2
fi

if ! safe_dir "${first_dir}"; then
  echo "${COLOR_RED}[FAIL] Unsafe or missing directory: ${first_dir}${COLOR_RESET}" >&2
  exit 3
fi

# Validate all directories
for dir in "${LOG_DIRS[@]}"; do
  if ! safe_dir "${dir}"; then
    echo "${COLOR_RED}[FAIL] Unsafe or missing directory: ${dir}${COLOR_RESET}" >&2
    exit 3
  fi
  if [[ ! -d "${dir}" ]]; then
    echo "${COLOR_RED}[FAIL] Directory not found: ${dir}${COLOR_RESET}" >&2
    exit 3
  fi
  echo "${COLOR_GREEN}[OK] Managing directory: ${dir}${COLOR_RESET}"
done

if ! [[ ${RETENTION_DAYS} =~ ^[0-9]+$ ]]; then
  echo "${COLOR_RED}[FAIL] RETENTION_DAYS must be numeric${COLOR_RESET}" >&2
  exit 2
fi

if ! [[ ${MIN_FREE_PCT} =~ ^[0-9]+$ ]]; then
  echo "${COLOR_RED}[FAIL] MIN_FREE_PCT must be numeric${COLOR_RESET}" >&2
  exit 2
fi

if ! [[ ${MAX_DELETE_COUNT} =~ ^[0-9]+$ ]]; then
  echo "${COLOR_RED}[FAIL] MAX_DELETE_COUNT must be numeric${COLOR_RESET}" >&2
  exit 2
fi

# Disk usage before and free space check
echo "${COLOR_YELLOW}Disk usage before:${COLOR_RESET}"
df -h "${first_dir}"
usage_line=$(df -P "${first_dir}" | awk 'NR==2{print $5}')
used_pct=${usage_line%\%}
free_pct=$((100 - used_pct))
if (( free_pct < MIN_FREE_PCT )); then
  echo "${COLOR_RED}[WARN] Free space ${free_pct}% below threshold ${MIN_FREE_PCT}%${COLOR_RESET}"
else
  echo "${COLOR_GREEN}Free space ${free_pct}% meets threshold ${MIN_FREE_PCT}%${COLOR_RESET}"
fi

count=0
size_bytes=0
mapfile -t candidates < <(
  for dir in "${LOG_DIRS[@]}"; do
    find "${dir}" -type f -name "${FILE_PATTERN}" -mtime +"${RETENTION_DAYS}" -print0
  done | tr '\0' '\n' | sed '/^$/d'
)

for file in "${candidates[@]}"; do
  if [[ -z "${file}" ]]; then
    continue
  fi
  if [[ ! -f "${file}" ]]; then
    continue
  fi
  count=$((count + 1))
  file_size=$(du -b "${file}" 2>/dev/null | awk '{print $1}')
  if [[ -z "${file_size}" ]]; then
    file_size=$(du -k "${file}" 2>/dev/null | awk '{print $1 * 1024}')
  fi
  size_bytes=$((size_bytes + ${file_size:-0}))
done

human_size() {
  local bytes=$1
  local kib=$((1024))
  local mib=$((1024 * 1024))
  local gib=$((1024 * 1024 * 1024))
  if (( bytes >= gib )); then
    printf '%.2f GiB' "$(awk -v b=${bytes} 'BEGIN {printf b/1073741824}')"
  elif (( bytes >= mib )); then
    printf '%.2f MiB' "$(awk -v b=${bytes} 'BEGIN {printf b/1048576}')"
  elif (( bytes >= kib )); then
    printf '%.2f KiB' "$(awk -v b=${bytes} 'BEGIN {printf b/1024}')"
  else
    printf '%d B' "${bytes}"
  fi
}

summary_size=$(human_size "${size_bytes}")

echo "${COLOR_YELLOW}Matched files:${COLOR_RESET} ${count}"
echo "${COLOR_YELLOW}Total size:${COLOR_RESET} ${summary_size}"

report_lines=()
report_lines+=("Log Cleaner Report - $(date -u +%Y-%m-%dT%H:%M:%SZ)")
report_lines+=("Directories: ${LOG_DIRS[*]}")
report_lines+=("Pattern: ${FILE_PATTERN}")
report_lines+=("Retention: ${RETENTION_DAYS} days")
report_lines+=("Dry run: ${DRY_RUN}")
report_lines+=("Matched files: ${count}")
report_lines+=("Total size: ${summary_size}")

if (( count == 0 )); then
  echo "${COLOR_GREEN}No files matched criteria.${COLOR_RESET}"
else
  echo "${COLOR_YELLOW}Listing matched files:${COLOR_RESET}"
  for file in "${candidates[@]}"; do
    [[ -z "${file}" ]] && continue
    echo "  ${file}"
  done
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "${COLOR_YELLOW}Dry run enabled. No files will be deleted.${COLOR_RESET}"
  if [[ "${REPORT_FLAG}" == "true" ]]; then
    report_file="${REPORT_DIR}/clean_report_$(date +%Y%m%d%H%M%S).txt"
    printf '%s\n' "${report_lines[@]}" > "${report_file}"
    if (( count > 0 )); then
      printf '\nMatched files:\n' >> "${report_file}"
      printf '%s\n' "${candidates[@]}" >> "${report_file}"
    fi
    echo "Report written to ${report_file}"
  fi
  echo "${COLOR_YELLOW}Disk usage after (no changes made):${COLOR_RESET}"
  df -h "${first_dir}"
  exit 0
fi

if (( count > MAX_DELETE_COUNT )); then
  echo "${COLOR_RED}[FAIL] Matched ${count} files exceeds safety cap ${MAX_DELETE_COUNT}. Aborting.${COLOR_RESET}" >&2
  exit 4
fi

if (( count == 0 )); then
  echo "${COLOR_GREEN}Nothing to delete.${COLOR_RESET}"
  exit 0
fi

for file in "${candidates[@]}"; do
  [[ -z "${file}" ]] && continue
  if [[ ! -f "${file}" ]]; then
    continue
  fi
  printf '%s\tDELETE\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${file}" >> "${RUN_LOG}"
  rm -f -- "${file}"
done

if [[ "${REPORT_FLAG}" == "true" ]]; then
  report_file="${REPORT_DIR}/clean_report_$(date +%Y%m%d%H%M%S).txt"
  printf '%s\n' "${report_lines[@]}" > "${report_file}"
  printf '\nDeleted files:\n' >> "${report_file}"
  printf '%s\n' "${candidates[@]}" >> "${report_file}"
  echo "Report written to ${report_file}"
fi

# Disk usage after
echo "${COLOR_YELLOW}Disk usage after:${COLOR_RESET}"
df -h "${first_dir}"

echo "${COLOR_GREEN}Deletion completed successfully.${COLOR_RESET}"
exit 0
