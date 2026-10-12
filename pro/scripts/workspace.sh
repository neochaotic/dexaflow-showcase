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
  # Without a git identity (a fresh Cloud Shell), commit as the workspace itself.
  ident=()
  git -C "${dir}" config user.email >/dev/null 2>&1 \
    || ident=(-c user.name="Dexaflow workspace" -c user.email="workspace@dexaflow.local")
  git -C "${dir}" "${ident[@]+"${ident[@]}"}" commit -q -m "Create Dexaflow DAG workspace" 2>/dev/null \
    || warn "no first commit; DAG versions will read dev"
fi
ok "Workspace ready: ${dir}"
next "cd ${dir}"
