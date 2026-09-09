terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }

    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

locals {
  image = "logicoar/coder-dev:0.1.2"
}

variable "docker_socket" {
  description = "Optional Docker socket URI. Leave empty to use the provider default."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------

provider "coder" {}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

# -----------------------------------------------------------------------------
# Coder data
# -----------------------------------------------------------------------------

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_parameter" "github_ssh_key" {
  name         = "github_ssh_key"
  display_name = "GitHub SSH Key"
  description  = "Identifier of the encrypted GitHub SSH key to use, e.g. v3 or legacy."

  type      = "string"
  form_type = "input"
  default   = ""
  mutable   = true

  validation {
    regex = "^$|^[A-Za-z0-9][A-Za-z0-9._-]*$"
    error = "Use only letters, numbers, dots, underscores and hyphens."
  }
}

resource "coder_env" "github_ssh_key" {
  agent_id = coder_agent.main.id
  name     = "GITHUB_SSH_KEY"
  value    = data.coder_parameter.github_ssh_key.value
}

# -----------------------------------------------------------------------------
# Coder agent
# -----------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # SSH sessions and terminals start here by default.
  dir = "/home/coder/workspace"

  startup_script = templatefile(
    "${path.module}/scripts/startup.sh.tftpl",
    {
      dotfiles_script = file("${path.module}/scripts/bootstrap-dotfiles.sh")
      secrets_script  = file("${path.module}/scripts/bootstrap-secrets.sh")
      ai_tools_script = file("${path.module}/scripts/bootstrap-ai-tools.sh")
    }
  )

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
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }
}

# -----------------------------------------------------------------------------
# Persistent home
# -----------------------------------------------------------------------------

resource "docker_volume" "home" {
  # Workspace ID is intentionally used instead of workspace name.
  #
  # Renaming a workspace must not create a new home volume.
  name = "coder-${data.coder_workspace.me.id}-home"

  # Protect the persistent home from Terraform changes caused by
  # labels or workspace renames.
  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  # Deliberately records the original name only.
  # It may become stale after a rename, which is fine.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

# -----------------------------------------------------------------------------
# Workspace container
# -----------------------------------------------------------------------------

resource "docker_container" "workspace" {
  # start_count is 1 while running and 0 when stopped.
  # The container is therefore disposable while the volume survives.
  count = data.coder_workspace.me.start_count

  image = local.image

  name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"

  # Human-friendly hostname derived from the workspace name.
  hostname = "coder-${lower(data.coder_workspace.me.name)}"

  # Our image already defaults to USER coder, but declaring it here makes
  # the execution contract explicit.
  user = "coder"

  # Start the Coder agent as PID 1 of the workspace container.
  #
  # If Coder itself is exposed as localhost/127.0.0.1 on the host, the
  # container must reach it through Docker's host gateway instead.
  entrypoint = [
    "sh",
    "-c",
    replace(
      coder_agent.main.init_script,
      "/localhost|127\\.0\\.0\\.1/",
      "host.docker.internal"
    )
  ]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }

  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }

  labels {
    label = "coder.image"
    value = local.image
  }
}
