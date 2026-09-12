# Coder VPS Ansible Provisioning

This directory provisions a single Ubuntu LTS VPS for the Coder development environment.

The goal is to keep the host small and predictable. Development tools belong in Coder workspaces, not on the VPS itself.

## Architecture

```text
Internet
   |
   | 80 / 443
   v
Caddy (Docker)
   |
   v
Coder (systemd on the host)
   |
   +---- PostgreSQL (Docker)
   |
   +---- /var/run/docker.sock
             |
             v
       Coder workspaces

Cockpit
   |
   +---- 127.0.0.1:9090 only
         accessed through an SSH tunnel
```

Coder runs directly on Ubuntu. PostgreSQL and Caddy run as Docker containers. Coder workspaces use the same Docker daemon installed on the host.

## What gets installed

### Basic host tools

The `common` role installs:

- Git
- curl
- Vim
- `dig` through `dnsutils`
- `ping` through `iputils-ping`
- CA certificates
- GnuPG
- unzip
- jq
- htop
- UFW

`vi` is available through Ubuntu's normal editor alternatives after installing Vim.

Node.js, Go, Neovim, Codex, OpenCode, CodeGraph, Herdr, and other development tools are intentionally not installed on the VPS. They belong inside the Coder workspace image/bootstrap.

### Docker

Docker Engine is installed from Docker's official Ubuntu APT repository.

Installed packages:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Because Docker uses an APT repository, normal Ubuntu package upgrades can update Docker.

### Coder

Coder runs directly on the host as a systemd service.

The playbook uses Coder's official installer with the `stable` release channel. On Ubuntu, that installer downloads and installs Coder's official `.deb` package.

Coder listens only on:

```text
127.0.0.1:3000
```

Caddy is the only public HTTP entry point.

The `coder` system user is added to the `docker` group so Coder can create Docker workspaces.

> Membership in the Docker group gives very powerful access to the host. This is intentional here because this Coder server is explicitly trusted to provision Docker workspaces.

### PostgreSQL

PostgreSQL runs in Docker using the `postgres:17` image by default.

Its port is published only on localhost:

```text
127.0.0.1:5432
```

The database is therefore not directly reachable from the Internet.

Database data is stored in a Docker named volume.

### Caddy

Caddy runs in Docker with host networking and owns public ports 80 and 443.

It automatically obtains and renews the TLS certificate for `coder_domain`, then proxies requests to:

```text
127.0.0.1:3000
```

Before provisioning, the domain DNS record must point to the VPS public IP.

### Cockpit

Cockpit is installed from Ubuntu packages and uses its normal systemd socket activation.

It is changed from the default public listener to:

```text
127.0.0.1:9090
```

There is no firewall rule for port 9090.

Access it from your local machine with an SSH tunnel:

```bash
ssh -L 9090:127.0.0.1:9090 ubuntu@YOUR_SERVER_IP
```

Then open:

```text
https://localhost:9090
```

The browser can show a certificate warning for Cockpit's local certificate. The connection between your computer and the VPS is already protected by SSH.

## Firewall

UFW allows only:

```text
SSH port    TCP
80          TCP
443         TCP
```

The SSH port comes from `ansible_port`, so it also works if the server does not use port 22.

Coder, PostgreSQL, and Cockpit are bound to localhost and do not need public rules.

Docker has special firewall behavior: ports published by Docker can bypass some UFW rules. This setup avoids exposing PostgreSQL by binding it explicitly to `127.0.0.1`. Do not publish future containers on `0.0.0.0` unless they are intentionally public.

## Directory layout

```text
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all/
│       ├── vars.yml
│       └── vault.yml          # created by you and encrypted
├── examples/
│   └── vault.yml.example
├── requirements.yml
├── site.yml
└── roles/
    ├── common/
    ├── firewall/
    ├── docker/
    ├── cockpit/
    ├── coder/
    └── coder_infra/
```

On the VPS, PostgreSQL and Caddy configuration is stored under:

```text
/opt/coder-infra/
├── compose.yml
├── Caddyfile
└── postgres.env
```

Persistent PostgreSQL and Caddy state is stored in Docker named volumes.

## Requirements on your local machine

You need:

- Ansible
- SSH access to the VPS
- a remote user with `sudo` access

Install the collections used by the playbook:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

## Step 1: configure the inventory

Edit:

```text
inventory/hosts.yml
```

Example:

```yaml
all:
  children:
    coder_servers:
      hosts:
        coder-vps:
          ansible_host: "203.0.113.10"
          ansible_user: "ubuntu"
          ansible_port: 22
```

Test SSH/Ansible connectivity before changing the server:

```bash
ansible coder_servers -m ping
```

## Step 2: configure the domain

Edit:

```text
group_vars/all/vars.yml
```

At minimum, change:

```yaml
coder_domain: "coder.example.com"
caddy_acme_email: "admin@example.com"
```

Create an `A` record, and an `AAAA` record if you use IPv6, pointing that hostname to the VPS.

Make sure DNS is working before expecting Caddy to obtain a certificate. TLS is clever, but it remains tragically unable to repair DNS by force of personality.

## Step 3: create the encrypted secrets file

Create the real Vault file from the example:

```bash
cp examples/vault.yml.example group_vars/all/vault.yml
```

Edit it and replace the password:

```yaml
vault_postgres_password: "use-a-long-random-password-here"
```

Encrypt the file:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

The encrypted `vault.yml` can be committed to Git.

Do not commit the password used to unlock Ansible Vault.

## Step 4: run the playbook

From this directory:

```bash
ansible-playbook site.yml --ask-vault-pass
```

On the first run, Ansible will roughly do this:

```text
Ubuntu packages
      |
      v
UFW
      |
      v
Docker Engine
      |
      +---- Cockpit on localhost
      |
      +---- install/configure Coder
      |
      +---- PostgreSQL container
      |
      +---- Caddy container
      |
      v
restart Coder after infrastructure is ready
```

The Coder restart is handled at the end of the play through an Ansible handler. This means PostgreSQL and Caddy are created before the final Coder restart.

## Step 5: open Coder

Open the configured domain:

```text
https://coder.example.com
```

On a new Coder installation, use the web UI to create the first administrator account.

## Verification commands

### Coder

```bash
sudo systemctl status coder
```

Follow its logs:

```bash
sudo journalctl -u coder -f
```

### Docker

```bash
sudo docker ps
```

The infrastructure containers should include:

```text
coder-postgres
coder-caddy
```

### PostgreSQL

```bash
sudo docker exec coder-postgres \
  pg_isready -U coder -d coder
```

Expected result:

```text
accepting connections
```

### Caddy

```bash
sudo docker logs coder-caddy
```

### Verify Coder can access Docker

```bash
id coder
sudo -u coder docker ps
```

### Check listening ports

```bash
sudo ss -lntp
```

The important listeners should be approximately:

```text
*:22              SSH, or your custom SSH port
*:80              Caddy
*:443             Caddy
127.0.0.1:3000    Coder
127.0.0.1:5432    PostgreSQL
127.0.0.1:9090    Cockpit
```

IPv6 listeners can also appear.

## Updating the server

### Ubuntu packages

The playbook runs an APT upgrade by default:

```yaml
apt_upgrade_packages: true
```

You can also use normal Ubuntu maintenance:

```bash
sudo apt update
sudo apt upgrade
```

### Docker Engine

Docker is installed from Docker's official APT repository, so normal APT upgrades can update it.

### Cockpit

Cockpit comes from Ubuntu packages, so normal APT upgrades update it.

### Coder

Coder's official Ubuntu installer installs a `.deb`, but it does not configure a Coder APT repository that tracks future releases.

With this default:

```yaml
coder_update_on_provision: true
```

re-running the Ansible playbook runs the official stable installer again and updates Coder when necessary.

If you do not want Coder checked on every Ansible run, set:

```yaml
coder_update_on_provision: false
```

Coder will then only be installed if it is missing.

### PostgreSQL and Caddy

The playbook uses major image tags:

```yaml
postgres_image: "postgres:17"
caddy_image: "caddy:2"
```

Ansible only pulls them automatically when the image is missing. This prevents an unrelated provisioning run from unexpectedly upgrading running infrastructure.

To deliberately update the current image tags:

```bash
cd /opt/coder-infra
sudo docker compose pull
sudo docker compose up -d
```

Do not change the PostgreSQL major version as if it were a normal container update. Major database upgrades need their own migration procedure.

## Important configuration files

### Coder

Generated by Ansible:

```text
/etc/coder.d/coder.env
```

It contains values similar to:

```text
CODER_ACCESS_URL=https://coder.example.com
CODER_HTTP_ADDRESS=127.0.0.1:3000
CODER_TLS_ENABLE=false
CODER_PG_CONNECTION_URL=postgresql://...
```

Caddy owns HTTPS, so Coder does not need to manage certificates itself.

### Caddy

Generated at:

```text
/opt/coder-infra/Caddyfile
```

Its basic job is intentionally boring:

```text
coder.example.com -> 127.0.0.1:3000
```

Boring infrastructure is usually the good kind.

## Wildcard workspace applications

This first version only configures the main Coder domain.

Coder can also use a wildcard domain such as:

```text
*.coder.example.com
```

This is useful for workspace applications and dashboard port forwarding.

Wildcard TLS with Caddy requires DNS-based ACME validation and a Caddy build containing the plugin for the DNS provider that hosts your domain. That is intentionally not guessed by this playbook.

Add it later after choosing the DNS provider integration.

## Design boundaries

This repository now has several different layers. They should stay separate:

```text
Ansible
  -> provisions the VPS

Docker Compose
  -> runs PostgreSQL and Caddy

Coder service
  -> manages workspace lifecycle

Coder template
  -> creates Docker workspace containers

Workspace bootstrap
  -> configures dotfiles, secrets, repositories, and AI tools
```

The Ansible playbook should not install project runtimes or clone client repositories onto the VPS.

## Known follow-up work

These are intentionally left for later:

- wildcard Coder application domains;
- automated PostgreSQL backups;
- explicit PostgreSQL/Caddy image update policy;
- automatic Coder upgrade scheduling;
- stricter SSH hardening;
- monitoring and alerts;
- automatic reboot handling after kernel updates;
- optimization of workspace startup update checks.

The current version is intended to produce a usable, understandable single-server installation first. Complexity can be added when it earns its keep.

## Official references

- Coder install: https://coder.com/docs/install
- Coder configuration: https://coder.com/docs/admin/setup
- Coder + Caddy: https://coder.com/docs/tutorials/reverse-proxy-caddy
- Docker on Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Cockpit: https://cockpit-project.org/running.html
- Cockpit listen address: https://docs.cockpit-project.org/cockpit-guide/latest/guide/listen.html
- PostgreSQL Docker image: https://hub.docker.com/_/postgres
