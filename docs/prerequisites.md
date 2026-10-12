# Prerequisites

| Tool | Needed for | Install |
|---|---|---|
| `dexaflow` CLI | everything | `make cli` (installs the version pinned in `versions.env` into `~/.dexaflow/bin`) |
| `helm` 3.16+ | dry run, local, GKE | <https://helm.sh/docs/intro/install/> |
| Docker | local, GKE (builds DAG images) | <https://docs.docker.com/get-docker/> |
| `k3d` 5.x | local | <https://k3d.io/#installation> |
| `kubectl` | local, GKE | <https://kubernetes.io/docs/tasks/tools/> |
| `gcloud` with `gke-gcloud-auth-plugin` and `bq` | GKE | <https://cloud.google.com/sdk/docs/install> |
| `make` | everything | preinstalled on macOS (Xcode command line tools) and most Linux |
| `kubeconform` | optional, dry run schema check | <https://github.com/yannh/kubeconform> |

`make cli` pins the CLI to the version in `versions.env` (the CLI picks the DAG
base image that matches its own version) and prepares the Python runtime that
`dexaflow compile` uses. Add `~/.dexaflow/bin` to your `PATH` afterwards.

Run `make doctor` to check what is missing.
