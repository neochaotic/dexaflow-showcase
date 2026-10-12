# Your DAGs

`make new-dag NAME=<name>` scaffolds a DAG project here. Deploy it with
`make deploy DAG=my-dags/<name>` (add `DEXAFLOW_TARGET=gke` for GKE).

For DAGs you want to keep, prefer a separate workspace: `make workspace`
(see [LAB.md, Part 2](../LAB.md#part-2-write-and-deploy-dags)).
