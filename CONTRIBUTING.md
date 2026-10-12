# Contributing

- Everything in this repository is in English.
- A new use case is a directory under `use-cases/` with `dag.py`,
  `dexaflow.yaml` and a `README.md` that says what it shows, how to run it and
  what to look at. Prefix it with `NN-gcp-` when it needs Google Cloud.
- Run `make dry-run` before opening a pull request. CI runs it too.
- Never commit credentials, project ids, kubeconfigs or anything under `.out/`.
