#!/usr/bin/env bash
# A `dexaflow compile --builder` that builds DAG images on Cloud Build instead
# of the local Docker daemon. dexaflow calls it like docker, from the repo root:
#   cloudbuild-builder.sh build --platform linux/amd64 -t IMAGE -f DOCKERFILE CONTEXT
#   cloudbuild-builder.sh push IMAGE
# `build` builds and pushes in one Cloud Build job, so `push` has nothing to do.
# Reads GCP_PROJECT and GKE_REGION (target.sh exports them from .out/gke.env).
set -euo pipefail

cmd="${1:-}"; shift || true
case "${cmd}" in
  push) exit 0 ;;
  build) ;;
  *) echo "cloudbuild-builder: unsupported command '${cmd}'" >&2; exit 2 ;;
esac

platform=linux/amd64 tag="" file="" ctx=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) platform="$2"; shift 2 ;;
    -t) tag="$2"; shift 2 ;;
    -f) file="$2"; shift 2 ;;
    *) ctx="$1"; shift ;;
  esac
done
[[ -n "${tag}" && -n "${file}" && -n "${ctx}" ]] \
  || { echo "cloudbuild-builder: expected build -t IMAGE -f DOCKERFILE CONTEXT" >&2; exit 2; }

# Upload a clean copy of the DAG folder: the generated Dockerfile is gitignored,
# and gcloud skips gitignored files when it uploads a folder inside a repo.
work="$(mktemp -d "${TMPDIR:-/tmp}/dexaflow-build.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
cp -R "${ctx}/." "${work}/"
cp "${file}" "${work}/Dockerfile.dexaflow"
printf '.gcloudignore\ncloudbuild.yaml\n__pycache__/\n' > "${work}/.gcloudignore"
cat > "${work}/cloudbuild.yaml" <<YAML
steps:
- name: gcr.io/cloud-builders/docker
  args: [build, --platform, "${platform}", -t, "${tag}", -f, Dockerfile.dexaflow, .]
images: ["${tag}"]
YAML

gcloud builds submit "${work}" --config "${work}/cloudbuild.yaml" \
  --project "${GCP_PROJECT:?}" --region "${GKE_REGION:-us-central1}" --quiet
