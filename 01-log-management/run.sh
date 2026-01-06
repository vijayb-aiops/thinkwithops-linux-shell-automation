#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  ./run.sh clean [args...]
  ./run.sh analyze [args...]

Examples:
  ./run.sh clean --help
  ./run.sh analyze --help
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

action=$1
shift || true

case "${action}" in
  -h|--help)
    usage
    exit 0
    ;;
  clean)
    exec "${SCRIPT_DIR}/src/log_cleaner.sh" "$@"
    ;;
  analyze)
    exec "${SCRIPT_DIR}/src/log_analyzer.sh" "$@"
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    usage
    exit 1
    ;;
esac
