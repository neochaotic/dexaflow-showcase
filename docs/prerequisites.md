# Prerequisites

| Tool | Needed for | Install |
|---|---|---|
| `dexaflow` CLI | everything | `curl -fsSL https://raw.githubusercontent.com/dexadata/dexaflow/main/install.sh \| DEXAFLOW_VERSION=v0.5.3 sh` |
| `helm` 3.16+ | dry run, local, GKE | <https://helm.sh/docs/intro/install/> |
| Docker | local, GKE (builds DAG images) | <https://docs.docker.com/get-docker/> |
| `k3d` 5.x | local | <https://k3d.io/#installation> |
| `kubectl` | local, GKE | <https://kubernetes.io/docs/tasks/tools/> |
| `gcloud` | GKE | <https://cloud.google.com/sdk/docs/install> |
| `kubeconform` | optional, dry run schema check | <https://github.com/yannh/kubeconform> |

Pin the CLI to the version in `versions.env`: the CLI picks the DAG base image
that matches its own version.

The installer also prepares Dexaflow Lite (a local Python and a workspace in
`~/dexaflow`). For Pro you only need the binaries: `DEXAFLOW_NO_SETUP=1` skips
that step.

Run `make doctor` to check what is missing.
