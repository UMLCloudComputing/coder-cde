terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    envbuilder = {
      source = "coder/envbuilder"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  config_path = null
}

provider "envbuilder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Handling private repositories
data "coder_external_auth" "github" {
  id = "primary-github"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = data.coder_provisioner.me.arch
  startup_script = <<-EOT
    set -e

    # Configure Global Identity
    git config --global user.name "${local.git_author_name}"
    git config --global user.email "${local.git_author_email}"

    # Set the Coder Credential Helper
    # This tells Git: "When you need a password for GitHub, ask the Coder CLI"
    coder git-auth setup github
  EOT

  dir = "/workspaces/${element(split("/", local.repo_url), length(split("/", local.repo_url)) - 1)}"

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

module "code-server" {
  count  = data.coder_workspace.me.start_count
  source = "registry.coder.com/coder/code-server/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  agent_id = coder_agent.main.id
  order    = 1 
}

# Show the dev server through a link on the Coder dashboard
resource "coder_app" "dev_server" {
  agent_id     = coder_agent.main.id
  slug         = "devserver"
  display_name = "Dev Server"
  url          = "http://localhost:3000" # Coder handles the proxying/TLS for you
  icon         = "https://raw.githubusercontent.com/fortawesome/Font-Awesome/6.x/svgs/solid/globe.svg"
  share        = "owner" # Only the workspace owner can see this link
  order        = 2
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id
  item {
    key   = "workspace image"
    value = local.devcontainer_builder_image
  }
  item {
    key   = "git url"
    value = local.repo_url
  }
  item {
    key   = "cache repo"
    value = "not enabled"
  }
}

locals {
  deployment_name            = "coder-${lower(data.coder_workspace.me.id)}"
  devcontainer_builder_image = "ghcr.io/coder/envbuilder:1.3.0"
  git_author_name            = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email           = data.coder_workspace_owner.me.email
  repo_url                   = "https://github.com/UMLCloudComputing/UMLCloudComputing.github.io.git" # Edit this to clone a different repo into the dev container
  # The envbuilder provider requires a key-value map of environment variables.
  envbuilder_env = {
    "CODER_AGENT_TOKEN" : coder_agent.main.token,
    "CODER_AGENT_URL" : data.coder_workspace.me.access_url
    "ENVBUILDER_GIT_URL" : local.repo_url,
    "ENVBUILDER_GIT_TOKEN" : data.coder_external_auth.github.access_token
    "ENVBUILDER_INIT_SCRIPT" : coder_agent.main.init_script
  }
}

resource "kubernetes_persistent_volume_claim_v1" "workspaces" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
    namespace = "coder"
    labels = {
      "app.kubernetes.io/name"     = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
      "app.kubernetes.io/instance" = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "50Gi"
      }
    }
  storage_class_name = "longhorn"
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim_v1.workspaces
  ]
  wait_for_rollout = false
  metadata {
    name      = local.deployment_name
    namespace = "coder"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
        }
      }
      spec {
        security_context {}

        container {
          name              = "dev"
          image             = local.devcontainer_builder_image
          image_pull_policy = "Always"
          command           = ["/envbuilder", "run"]
          security_context {
            run_as_user=1000
          }
          dynamic "env" {
            for_each = local.envbuilder_env
            content {
              name = env.key
              value = env.value
            }
          }
          env {
            name = "GIT_AUTHOR_NAME"
            value = local.git_author_name
          }
          env {
            name = "GIT_AUTHOR_EMAIL"
            value = local.git_author_email
          }
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "2"
              "memory" = "4Gi"
            }
          }
          volume_mount {
            mount_path = "/workspaces"
            name       = "workspaces"
            read_only  = false
          }
        }

        volume {
          name = "workspaces"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.workspaces.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

