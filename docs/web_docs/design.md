# Design ✍

Coder is deployed on Kubernetes running on the merrimack servers.
It's deployed as a Helm chart with it's configuration values available on the [repository](https://github.com/UMLCloudComputing/coder-cde).

## Dependencies
- Longhorn
  - A distributed in-cluster kubernetes storage provisioner. 
  - Deployed via Helm.
- PostgreSQL
  - An open-source SQL database engine. 
  - Deployed via Helm using a bitnami chart.
- Cloudflared
  - A persistent service that routes incoming external traffic to the Coder service. 
  - Deployed as a manifest. 
  - Necessary for cloudflare tunnels.
- GitHub ARC Runners/ARC Systems
  - Actions Runner Controller 
  - Used to run CD jobs to locally within the same cluster. 
  - Necessary for running a GitOps like flow for terraform template management on Coder.
  - Deployed via Helm.

PostgresSQL requires a secret called `postgres-secret` to exist within the `postgresql` namespace. It contains the admin and user credentials to the datbase. Check the postgresql helm chart values for more info. 

Coder requires a secret called `coder-db-url` to exist within the `coder` namespace. It contains the postgresql database url with the username and password within it. 

# Continuous Development

The repository is configured to leverage CD to automatically reconcile terraform templates within the `/templates` directory to be added to terraform for users to use. 

Edits, additions, or removals of templates on the repository in the `main` branch automatically trigger a GitHub Action to validate and apply the template to Coder on production. 

