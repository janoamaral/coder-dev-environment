# Coder Development Environment

A reproducible Ubuntu-based development environment designed for use with [Coder](https://coder.com/) workspaces.

The image provides a common development toolchain for Node.js, TypeScript, and Go microservices while keeping project repositories, user configuration, caches, and AI tooling outside the immutable image layer.

The goal is simple: rebuild the workspace without rebuilding your life.

## Goals

This image is designed around the following principles:

* Reproducible base development environment
* Ubuntu LTS as the base operating system
* Shared tooling for Node.js, TypeScript, and Go projects
* Non-root development user
* Persistent `$HOME` when used with Coder
* Fast workspace recreation
* Minimal project-specific configuration in the image
* AI development tooling managed separately from the base image
* Suitable for multi-repository and microservice development

## Included Tooling

The image includes common development tools from the Ubuntu repositories where possible.

### Shell and terminal

* Zsh
* GNU Screen
* Bash completion
* zoxide
* fzf

`screen` is included primarily to support persistent remote terminal sessions when connecting to Coder over SSH.

### Editors and navigation

* Neovim
* ripgrep
* fd
* tree
* less

Ubuntu installs `fd` as `fdfind`; this image exposes `/usr/local/bin/fd` for compatibility with tools expecting the conventional `fd` command.

### Git and repository tooling

* Git
* lazygit
* OpenSSH client
* rsync
* GNU Stow

Stow is intended to manage user dotfiles stored separately from this image.

### Development utilities

* build-essential
* make
* pkg-config
* curl
* wget
* jq
* unzip
* zip
* tar
* xz
* Python 3
* pip
* venv
* procps
* lsof
* iproute2
* ping
* netcat
* GnuPG
* CA certificates

## Language Runtimes

Language runtimes are installed independently from Ubuntu packages and pinned in the Dockerfile.

Currently included:

* Node.js 24.20.0
* Go 1.27.1

The versions in the Dockerfile are the source of truth and should be updated deliberately when the development stack changes.

## AI Development Tooling

AI development tooling is intentionally **not baked into the image**.

The workspace bootstrap layer is expected to install and update these tools to their latest versions whenever a stopped Coder workspace starts:

* OpenAI Codex
* OpenCode
* Ponytail
* CodeGraph
* OpenSpec

Additional AI development tools can be added later without requiring changes to the base image.

This separates two different lifecycle requirements:

* Stable and reproducible system tooling belongs in the Docker image.
* Rapidly evolving AI tooling belongs in workspace initialization.

## User Environment

The image provides a non-root user:

```text
user: coder
home: /home/coder
shell: /usr/bin/zsh
```

The user has passwordless `sudo` access for development purposes.

The following locations are prepared for persistent workspace usage:

```text
/home/coder/workspace
/home/coder/.config
/home/coder/.cache
/home/coder/.local
/home/coder/go
```

The expected project layout is intentionally generic:

```text
/home/coder/workspace/
├── repository-a/
├── repository-b/
├── repository-c/
└── ...
```

Each Coder workspace may therefore contain a different set of repositories while keeping the same paths and tooling.

## Persistent Home Directory

When used with Coder, `/home/coder` should be backed by persistent storage.

This allows the following to survive workspace stop/start cycles:

* Git repositories
* Dotfiles
* Shell history
* Neovim configuration
* AI agent configuration and session state
* `node_modules`
* npm/pnpm caches
* Go module cache
* Go build cache
* User-installed binaries
* General application caches

The container itself should be treated as disposable.

## Dotfiles

Personal configuration is intentionally excluded from the Docker image.

A separate dotfiles repository can be cloned during workspace initialization and applied using GNU Stow.

Example:

```bash
git clone https://github.com/your-user/dotfiles.git ~/dotfiles

cd ~/dotfiles

stow zsh
stow git
stow nvim
stow screen
stow lazygit
```

Oh My Zsh and shell plugins should also be managed from the user/bootstrap layer rather than baked into the image.

## Building

Build the image locally:

```bash
docker build \
  --platform linux/amd64 \
  -t coder-dev:local \
  .
```

This image currently targets:

```text
linux/amd64
```

## Running Locally

Start the image:

```bash
docker run --rm -it coder-dev:local zsh
```

Check the installed tools:

```bash
whoami

node --version
npm --version
go version

git --version
nvim --version
zsh --version
screen --version
fzf --version
zoxide --version
lazygit --version
rg --version
fd --version
```

## Testing Persistent Storage

Create a Docker volume:

```bash
docker volume create coder-dev-home
```

Start the container using that volume:

```bash
docker run -d \
  --name coder-dev-test \
  --hostname coder-dev-test \
  -v coder-dev-home:/home/coder \
  coder-dev:local
```

Create some persistent state:

```bash
docker exec coder-dev-test \
  touch /home/coder/.persistent-test
```

Delete the container:

```bash
docker rm -f coder-dev-test
```

Create it again:

```bash
docker run -d \
  --name coder-dev-test \
  --hostname coder-dev-test \
  -v coder-dev-home:/home/coder \
  coder-dev:local
```

Verify the state survived:

```bash
docker exec coder-dev-test \
  test -f /home/coder/.persistent-test \
  && echo "HOME survived"
```

## Testing Screen Persistence

Create a detached screen session:

```bash
docker exec coder-dev-test \
  screen -DmS dev-session
```

List sessions:

```bash
docker exec coder-dev-test screen -ls
```

Attach to it:

```bash
docker exec -it coder-dev-test \
  screen -r dev-session
```

Detach using:

```text
Ctrl-a d
```

The screen process survives terminal and SSH disconnections while the workspace itself remains running.

Stopping the entire Coder workspace will terminate running processes, including screen sessions. Files and supported agent state stored under the persistent home directory remain available after the next start.

## Publishing to Docker Hub

Authenticate:

```bash
docker login
```

Build and tag a version:

```bash
VERSION=0.1.0
IMAGE=<dockerhub-user>/coder-dev

docker build \
  --platform linux/amd64 \
  -t "$IMAGE:$VERSION" \
  -t "$IMAGE:latest" \
  .
```

Push both tags:

```bash
docker push "$IMAGE:$VERSION"
docker push "$IMAGE:latest"
```

Coder templates should reference an explicit version:

```text
<dockerhub-user>/coder-dev:0.1.0
```

rather than:

```text
<dockerhub-user>/coder-dev:latest
```

Using an explicit version prevents an unrelated image rebuild from silently changing an existing development environment.

## Makefile

The repository includes a Makefile to simplify image builds and publishing.

Example:

```bash
make build VERSION=0.1.0
```

Publish:

```bash
make push VERSION=0.1.0
```

The expected Makefile structure is:

```makefile
IMAGE := <dockerhub-user>/coder-dev
VERSION ?= 0.1.0

build:
	docker build \
		--platform linux/amd64 \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		.

push: build
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest
```

Replace `<dockerhub-user>` with the Docker Hub namespace used for the published image.

## Image Lifecycle

The base image should change relatively infrequently.

Typical reasons for publishing a new image version include:

* Ubuntu LTS upgrades
* Node.js version changes
* Go version changes
* Adding stable system-level development tools
* Updating required system libraries
* Security or compatibility fixes

Changes to Codex, OpenCode, Ponytail, CodeGraph, OpenSpec, dotfiles, repositories, or project-specific configuration should normally **not** require rebuilding this image.

## Planned Coder Integration

The corresponding Coder template is expected to provide:

* Persistent `/home/coder`
* Coder agent configuration
* Workspace secrets
* SSH access
* Dotfiles bootstrap
* Latest AI tooling installation/update
* Dynamic repository selection per workspace
* Workspace lifecycle configuration
* Activity-based autostop

A typical workspace will represent one version or project composed of multiple related repositories.

For example:

```text
Coder workspace
└── /home/coder/workspace
    ├── service-a
    ├── service-b
    ├── frontend
    └── other related repositories
```

The image remains identical regardless of which repositories are selected.

