#!/usr/bin/env bash
# Scaffold a new DAG project under my-dags/<name> with `dexaflow init`.
source "$(dirname "$0")/lib.sh"
need dexaflow
name="${1:-}"
[[ "${name}" =~ ^[a-z][a-z0-9_]*$ ]] || die "usage: make new-dag NAME=my_dag (lowercase, digits, underscores)"
dir="${REPO_ROOT}/my-dags/${name}"
[[ ! -e "${dir}" ]] || die "${dir} already exists"
run dexaflow init "${dir}"
log "Edit ${dir#"${REPO_ROOT}"/}/dag.py, then: make deploy DAG=my-dags/${name}"
