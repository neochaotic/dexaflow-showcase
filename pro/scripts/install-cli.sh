#!/usr/bin/env bash
# Install the Dexaflow CLI pinned in versions.env into ~/.dexaflow/bin, plus
# the managed Python runtime that `dexaflow compile` uses to parse dag.py.
source "$(dirname "$0")/lib.sh"
need curl

BIN_DIR="${HOME}/.dexaflow/bin"
if [[ -x "${BIN_DIR}/dexaflow" ]] && "${BIN_DIR}/dexaflow" version 2>/dev/null | grep -q "${DEXAFLOW_VERSION}"; then
  log "Dexaflow CLI ${DEXAFLOW_VERSION} already installed in ${BIN_DIR}"
else
  log "Installing Dexaflow CLI ${DEXAFLOW_VERSION} into ${BIN_DIR}"
  mkdir -p "${REPO_ROOT}/.out"
  # The upstream installer also adds ~/.dexaflow/bin to your shell profile, so
  # new terminals find the CLI. It ends with Lite-oriented next steps; keep its
  # output in a log.
  curl -fsSL "https://raw.githubusercontent.com/dexadata/dexaflow/v${DEXAFLOW_VERSION}/install.sh" \
    | DEXAFLOW_VERSION="v${DEXAFLOW_VERSION}" DEXAFLOW_INSTALL_DIR="${BIN_DIR}" \
      DEXAFLOW_NO_SETUP=1 sh >"${REPO_ROOT}/.out/dexaflow-install.log" 2>&1 \
    || { cat "${REPO_ROOT}/.out/dexaflow-install.log" >&2; die "Dexaflow CLI install failed"; }
fi
# `dexaflow setup` prepares the Python runtime that parses dag.py. Its output is
# about Dexaflow Lite, so keep it in a log and show it only on failure.
mkdir -p "${REPO_ROOT}/.out"
log "Preparing the DAG parser runtime (downloads Python 3.11 if this machine has none;"
log "can take a minute or two, log in .out/dexaflow-setup.log)"
# stdin from /dev/null: setup asks questions (workspace folder) and takes the
# defaults when nobody can answer, instead of waiting on a hidden prompt.
# --workspace: the Lite workspace setup creates stays in .out/, not in ~.
"${BIN_DIR}/dexaflow" setup --workspace "${REPO_ROOT}/.out/lite-workspace" </dev/null >"${REPO_ROOT}/.out/dexaflow-setup.log" 2>&1 \
  || { cat "${REPO_ROOT}/.out/dexaflow-setup.log" >&2; die "dexaflow setup failed"; }
log "Done. New terminals find dexaflow on their own; for this one run:"
log "  export PATH=\"\$HOME/.dexaflow/bin:\$PATH\""
