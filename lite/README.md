# Dexaflow Lite (coming later)

Dexaflow Lite runs the same engine on a single host, without Kubernetes:

```bash
dexaflow lite use-cases/01-hello-pipeline   # http://localhost:8088
```

This folder will hold the Lite walkthroughs for the same use cases. The DAGs
stay in [`../use-cases`](../use-cases): Lite and Pro read the same `dag.py` and
`dexaflow.yaml`.
