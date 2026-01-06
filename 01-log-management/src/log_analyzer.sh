#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_usage() {
  cat <<'USAGE'
Usage: log_analyzer.sh [--dir DIR] [--pattern PATTERN] [--lines N] [--out FILE]

Options:
  --dir       Directory to scan (default: /var/log)
  --pattern   File pattern to include (default: *.log)
  --lines     Max lines to read from each file (default: 20000)
  --out       Output file (default: REPORT_DIR/analyze_<timestamp>.txt)
  -h, --help  Show this help
USAGE
}

is_tty() { [[ -t 1 ]]; }

setup_colors() {
  if is_tty; then
    COLOR_BLUE="\033[0;34m"
    COLOR_GREEN="\033[0;32m"
    COLOR_RESET="\033[0m"
  else
    COLOR_BLUE=""; COLOR_GREEN=""; COLOR_RESET=""
  fi
}

resolve_path() {
  local path=$1
  if [[ "${path}" == /* ]]; then
    echo "${path}"
  else
    echo "${SCRIPT_DIR}/${path}"
  fi
}

load_env_overrides
setup_colors

DIR="/var/log"
PATTERN="*.log"
LINES=20000
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) shift; DIR=${1:-}; shift ;;
    --pattern) shift; PATTERN=${1:-}; shift ;;
    --lines) shift; LINES=${1:-}; shift ;;
    --out) shift; OUT=${1:-}; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; print_usage; exit 2 ;;
  esac
done

REPORT_DIR="$(resolve_path "${REPORT_DIR}")"
STATE_DIR="$(resolve_path "${STATE_DIR}")"
RUN_LOG="$(resolve_path "${RUN_LOG}")"
ensure_dirs

if [[ -z "${OUT}" ]]; then
  OUT="${REPORT_DIR}/analyze_$(date +%Y%m%d%H%M%S).txt"
else
  OUT="$(resolve_path "${OUT}")"
fi

: > "${OUT}"
echo "Using log directory: ${DIR}" | tee -a "${OUT}"

if [[ ! -d "${DIR}" ]]; then
  echo "Directory not found: ${DIR}" | tee -a "${OUT}" >&2
  exit 3
fi

if ! [[ ${LINES} =~ ^[0-9]+$ ]]; then
  echo "Invalid --lines value: ${LINES}" | tee -a "${OUT}" >&2
  exit 2
fi

# Top 20 largest files
{
  echo "${COLOR_BLUE}Top 20 largest log files:${COLOR_RESET}"
  find "${DIR}" -type f -name "${PATTERN}" -exec du -k {} + 2>/dev/null | sort -nr | head -20
} | tee -a "${OUT}"

largest_file=$(find "${DIR}" -type f -name "${PATTERN}" -exec du -k {} + 2>/dev/null | sort -nr | head -1 | awk '{print $2}')

if [[ -n "${largest_file}" && -f "${largest_file}" ]]; then
  {
    echo ""
    echo "${COLOR_GREEN}Analyzing largest file:${COLOR_RESET} ${largest_file}"
    echo "Top error-like lines:" \
      && head -n "${LINES}" "${largest_file}" | grep -Eio '.*(error|fail|fatal|panic|exception).*' | sed 's/^/  /' | sort | uniq -c | sort -nr | head -20
    echo ""
    echo "Last 50 lines:"
    tail -n 50 "${largest_file}" | sed 's/^/  /'
  } | tee -a "${OUT}"
else
  echo "No log files found matching pattern." | tee -a "${OUT}"
fi

access_log_path=""
candidate_paths=$(find "${DIR}" -type f \( -name "access.log" -o -path "*/nginx/access.log" -o -path "*/apache2/access.log" \) 2>/dev/null | head -1)
if [[ -n "${candidate_paths}" ]]; then
  access_log_path=${candidate_paths}
fi

if [[ -n "${access_log_path}" ]]; then
  {
    echo ""
    echo "${COLOR_BLUE}Access log analysis:${COLOR_RESET} ${access_log_path}"
    echo "Top 20 IP addresses:"
    awk '{print $1}' "${access_log_path}" | sort | uniq -c | sort -nr | head -20 | sed 's/^/  /'
    echo ""
    echo "Top 20 requested paths:"
    awk '{if (NF>=7) print $7}' "${access_log_path}" | sort | uniq -c | sort -nr | head -20 | sed 's/^/  /'
  } | tee -a "${OUT}"
else
  echo "No access logs detected; skipping access log analysis." | tee -a "${OUT}"
fi

exit 0
