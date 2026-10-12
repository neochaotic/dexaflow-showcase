#!/usr/bin/env bash
# Shared helpers. Sourced by every script in pro/scripts and pro/platform/gke.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../versions.env
source "${REPO_ROOT}/versions.env"

log()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mWARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

# run prints a command before running it, so every script shows exactly what
# it does to the cluster and to Google Cloud.
run() {
  printf '\033[2m$ %s\033[0m\n' "$*" >&2
  "$@"
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. See docs/prerequisites.md."
}

# use_case_dirs prints every DAG project (a directory holding dexaflow.yaml)
# under use-cases/, or only the ones under the use case passed as $1.
use_case_dirs() {
  local filter="${1:-all}" root="${REPO_ROOT}/use-cases"
  if [[ "${filter}" != "all" ]]; then
    root="${root}/${filter}"
    [[ -d "${root}" ]] || die "unknown use case '${filter}' (see use-cases/)"
  fi
  dag_dirs "${root}"
}

# dag_dirs prints every DAG project under the given paths.
dag_dirs() {
  local path
  for path in "$@"; do
    [[ -e "${path}" ]] || die "no such path: ${path}"
    find "${path}" -name dexaflow.yaml -not -path '*/.out/*' -exec dirname {} \;
  done | sort
}

# dag_id reads the dag_id field of a dexaflow.yaml.
dag_id() {
  awk -F': *' '/^dag_id:/ {print $2; exit}' "$1/dexaflow.yaml"
}
