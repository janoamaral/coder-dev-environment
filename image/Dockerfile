# syntax=docker/dockerfile:1

FROM ubuntu:26.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Base environment
# ---------------------------------------------------------------------------

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    EDITOR=nvim \
    VISUAL=nvim

# ---------------------------------------------------------------------------
# Stable tooling from Ubuntu repositories
# ---------------------------------------------------------------------------

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        fd-find \
        fzf \
        git \
        gnupg \
        iproute2 \
        iputils-ping \
        jq \
        lazygit \
        less \
        lsof \
        make \
        man-db \
        netcat-openbsd \
        neovim \
        openssh-client \
        pkg-config \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        rsync \
        screen \
        stow \
        sudo \
        tar \
        tree \
        unzip \
        wget \
        xz-utils \
        zip \
        zoxide \
        zsh \
        eza \
        bat \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu ships fd as "fdfind". Most tooling expects "fd".
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ---------------------------------------------------------------------------
# Node.js
#
# Intentionally pinned.
# Replace these two values with the versions used by the project.
# ---------------------------------------------------------------------------

ENV NODE_VERSION=24.20.0 \
    NODE_SHA256=2f2c0da162318f0de47665410c7c8c2ed3d36c8f3105de4bbc61176c70a7cbf2

RUN curl -fsSLO \
        "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && echo \
        "${NODE_SHA256}  node-v${NODE_VERSION}-linux-x64.tar.xz" \
        | sha256sum -c - \
    && tar \
        -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" \
        -C /usr/local \
        --strip-components=1 \
    && rm "node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && node --version \
    && npm --version

# ---------------------------------------------------------------------------
# Go
#
# Intentionally pinned.
# ---------------------------------------------------------------------------

ENV GO_VERSION=1.27.1 \
    GO_SHA256=63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445

RUN curl -fsSLO \
        "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && echo \
        "${GO_SHA256}  go${GO_VERSION}.linux-amd64.tar.gz" \
        | sha256sum -c - \
    && rm -rf /usr/local/go \
    && tar \
        -C /usr/local \
        -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz"

ENV PATH="/usr/local/go/bin:${PATH}"

RUN go version

# ---------------------------------------------------------------------------
# Coder workspace user
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Coder workspace user
# ---------------------------------------------------------------------------

ARG USER=coder
ARG UID=1001
ARG GID=1001

RUN groupadd --gid "${GID}" "${USER}" \
    && useradd \
        --uid "${UID}" \
        --gid "${GID}" \
        --create-home \
        --shell /usr/bin/zsh \
        "${USER}" \
    && usermod -aG sudo "${USER}" \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" \
        > "/etc/sudoers.d/${USER}" \
    && chmod 0440 "/etc/sudoers.d/${USER}"

# ---------------------------------------------------------------------------
# Persistent/user-local tooling layout
#
# AI tools installed on workspace start will live here rather than /usr/local.
# This keeps them writable by the workspace user and persistent with $HOME.
# ---------------------------------------------------------------------------

ENV HOME=/home/coder \
    NPM_CONFIG_PREFIX=/home/coder/.local \
    GOPATH=/home/coder/go

ENV PATH="/home/coder/.local/bin:/home/coder/go/bin:${PATH}"

RUN mkdir -p \
        /home/coder/workspace \
        /home/coder/.local/bin \
        /home/coder/.config \
        /home/coder/.cache \
        /home/coder/go \
    && chown -R coder:coder /home/coder

USER coder

WORKDIR /home/coder/workspace

# Coder will override this with coder_agent.main.init_script.
# This default only makes the image convenient to test outside Coder.
CMD ["sleep", "infinity"]
