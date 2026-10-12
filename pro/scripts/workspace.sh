#!/usr/bin/env bash
# Create a DAG workspace: a separate folder (and git repository) for your own
# DAGs, whose Makefile deploys through this clone's platform scripts.
source "$(dirname "$0")/lib.sh"
dir="${1:-$(dirname "${REPO_ROOT}")/dexaflow-workspace}"
[[ ! -e "${dir}/Makefile" ]] || die "${dir} already has a Makefile; it is already a workspace"
mkdir -p "${dir}"
dir="$(cd "${dir}" && pwd)"
log "Creating the DAG workspace ${dir}"
cp -R "${REPO_ROOT}/pro/workspace-template/." "${dir}/"
sed -i.bak "s|__SHOWCASE__|${REPO_ROOT}|" "${dir}/Makefile" && rm -f "${dir}/Makefile.bak"
if command -v git >/dev/null 2>&1 && [[ ! -d "${dir}/.git" ]]; then
  git -C "${dir}" init -q
  # A first commit gives deployed DAGs a real version label instead of "dev".
  git -C "${dir}" add -A
  git -C "${dir}" commit -q -m "Create Dexaflow DAG workspace" 2>/dev/null \
    || warn "no first commit (set git user.name and user.email); DAG versions will read dev"
fi
log "Done. Next: cd ${dir} && make new NAME=my_first_dag"
