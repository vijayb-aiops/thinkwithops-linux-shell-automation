#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"

print_usage() {
  cat <<'USAGE'
Usage:
  ./run.sh clean [args...]
  ./run.sh analyze [args...]
USAGE
}

if [[ $# -lt 1 ]]; then
  print_usage
  exit 1
fi

action=$1
shift || true

case "${action}" in
  clean)
    exec "${PROJECT_ROOT}/src/log_cleaner.sh" "$@" ;;
  analyze)
    exec "${PROJECT_ROOT}/src/log_analyzer.sh" "$@" ;;
  *)
    echo "Unknown action: ${action}" >&2
    print_usage
    exit 1 ;;
esac
