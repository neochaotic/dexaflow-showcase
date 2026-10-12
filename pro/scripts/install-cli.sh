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
  curl -fsSL "https://raw.githubusercontent.com/dexadata/dexaflow/v${DEXAFLOW_VERSION}/install.sh" \
    | DEXAFLOW_VERSION="v${DEXAFLOW_VERSION}" DEXAFLOW_INSTALL_DIR="${BIN_DIR}" \
      DEXAFLOW_NO_SETUP=1 DEXAFLOW_NO_PATH=1 sh
fi
run "${BIN_DIR}/dexaflow" setup
log "Done. Add it to this shell with: export PATH=\"\$HOME/.dexaflow/bin:\$PATH\""
