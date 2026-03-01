# Coder Cloud Development Environments

Accessible at https://coder.umlcloudcomputing.org

Authenticate with your GitHub Account.

> [!TIP]
> Access the CDEs are only available to UML Cloud Computing Club GitHub organization members
> To gain access, request admission into the organization GitHub first.


Generic and project-specific workspace templates available.

# Technologies 🏗️
- Kubernetes
  - Bitnami PostgreSQL
  - Longhorn 
  - GitHub Actions Runner Controller (self-hosted runners)
- Coder CDE
- Cloudflare Tunnels
- GitHub Actions (CD)

## Development 🔬

- `/templates` contains all files related to terraform templates
- `/talos` contains all Talos machineconfig and talosconfig files
- `/arc` contains all files related to GitHub Actions Runner Controller and scale set files
- `/helm` contains helm values file for all helm packages installed

To add a new template, simply create a new folder in `/templates` with the name of your template. 
Within it, include a README markdown file with the following format:
```md
---
display_name: TEMPLATE-DISPLAY-NAME 
description: TEMPLATE-DESCRIPTION
icon: ICON-PATH-ON-CODER
maintainer_github: UMLCloudComputing
verified: true
tags: [kubernetes, container, ETC]
---

# YOUR TITLE

YOUR DESCRIPTION
```
Similarly, name your template itself `main.tf`. 
For structure guidance, follow the existing template `k8s-pod-custom-repo` as a guide. 
Key details:
- Namespace must be `coder`
- Must not allow for more than 4 CPU cores
- Must not allow for more than 8 GB RAM
- Must not allow for more than 50 GB of storage
