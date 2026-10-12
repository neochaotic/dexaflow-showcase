#!/usr/bin/env bash
# Scaffold a new DAG project with `dexaflow init`, under my-dags/<name> or
# under DAGS_DIR (set by a workspace Makefile).
source "$(dirname "$0")/lib.sh"
need dexaflow
name="${1:-}"
[[ "${name}" =~ ^[a-z][a-z0-9_]*$ ]] || die "usage: make new-dag NAME=my_dag (lowercase, digits, underscores)"
dir="${DAGS_DIR:-${REPO_ROOT}/my-dags}/${name}"
[[ ! -e "${dir}" ]] || die "${dir} already exists"
run dexaflow init "${dir}"
ok "Created ${dir}"
next "edit its dag.py, then: make deploy DAG=$(basename "$(dirname "${dir}")")/${name}"
