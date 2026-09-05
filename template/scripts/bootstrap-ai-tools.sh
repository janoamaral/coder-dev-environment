#!/usr/bin/env bash

set -u
set -o pipefail

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.local}"

export PATH="$HOME/.local/bin:$PATH"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log() {
  printf '[ai-tools] %s\n' "$*"
}

warn() {
  printf '[ai-tools] warning: %s\n' "$*" >&2
}

# -----------------------------------------------------------------------------
# Codex
# -----------------------------------------------------------------------------

install_codex() {
  log "Installing/updating Codex"

  if ! curl -fsSL https://chatgpt.com/codex/install.sh \
    | CODEX_INSTALL_DIR="$HOME/.local/bin" sh
  then
    warn "Could not install/update Codex"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# OpenCode
# -----------------------------------------------------------------------------

install_opencode() {
  log "Installing/updating OpenCode"

  if ! npm install \
    --global \
    --no-fund \
    --no-audit \
    opencode-ai@latest
  then
    warn "Could not install/update OpenCode"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# OpenSpec
# -----------------------------------------------------------------------------

install_openspec() {
  log "Installing/updating OpenSpec"

  if ! npm install \
    --global \
    --no-fund \
    --no-audit \
    @fission-ai/openspec@latest
  then
    warn "Could not install/update OpenSpec"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# CodeGraph
# -----------------------------------------------------------------------------

install_codegraph() {
  log "Installing/updating CodeGraph"

  if ! curl -fsSL \
    https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh \
    | CODEGRAPH_BIN_DIR="$HOME/.local/bin" sh
  then
    warn "Could not install/update CodeGraph"
    return 1
  fi

  return 0
}

configure_codegraph() {
  if ! command -v codegraph >/dev/null 2>&1; then
    warn "CodeGraph is not available; skipping agent integration"
    return 1
  fi

  if ! command -v codex >/dev/null 2>&1; then
    warn "Codex is not available; skipping CodeGraph Codex integration"
    return 1
  fi

  log "Configuring CodeGraph for Codex"

  if ! codegraph install \
    --target=codex \
    --location=global \
    --yes
  then
    warn "Could not configure CodeGraph for Codex"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

verify_tool() {
  local name="$1"
  local command="$2"

  if ! command -v "$command" >/dev/null 2>&1; then
    warn "$name is not available on PATH"
    return 1
  fi

  local version

  if version="$("$command" --version 2>&1)"; then
    log "$name ready: $version"
  else
    warn "$name is installed but version check failed"
    return 1
  fi

  return 0
}

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------

main() {
  log "Starting AI tooling bootstrap"

  mkdir -p "$HOME/.local/bin"

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl is required; cannot install Codex or CodeGraph"
  else
    install_codex || true
    install_codegraph || true
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm is required; cannot install OpenCode or OpenSpec"
  else
    install_opencode || true
    install_openspec || true
  fi

  # OpenCode's CodeGraph MCP configuration lives declaratively in dev-dots.
  # Only Codex needs to be configured here.
  configure_codegraph || true

  log "Verifying AI tools"

  verify_tool "Codex" "codex" || true
  verify_tool "OpenCode" "opencode" || true
  verify_tool "OpenSpec" "openspec" || true
  verify_tool "CodeGraph" "codegraph" || true

  log "AI tooling bootstrap complete"
}

main "$@"
