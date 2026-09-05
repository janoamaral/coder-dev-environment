#!/usr/bin/env bash

set -u

DOTFILES_REPO="https://github.com/janoamaral/dev-dots.git"
DOTFILES_DIR="$HOME/dev-dots"

DOTFILES_PACKAGES=(
  git
  nvim
  opencode
  zsh
)

ZSH_PLUGIN_DIR="$HOME/.config/zsh/plugins"

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/workspace"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
  log "Cloning dev-dots"

  if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
    warn "Could not clone dev-dots"
    exit 0
  fi
else
  log "Updating dev-dots"

  if ! git -C "$DOTFILES_DIR" pull --ff-only; then
    warn "Could not fast-forward dev-dots; keeping local state"
  fi
fi

log "Applying Stow packages: ${DOTFILES_PACKAGES[*]}"

if ! stow \
  --dir="$DOTFILES_DIR" \
  --target="$HOME" \
  --restow \
  "${DOTFILES_PACKAGES[@]}"
then
  warn "Stow failed; existing files were left untouched"
  exit 0
fi

log "Dotfiles ready"

# -----------------------------------------------------------------------------
# Zsh plugins
# -----------------------------------------------------------------------------

update_repo \
  "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "$ZSH_PLUGIN_DIR/zsh-autosuggestions"

update_repo \
  "fzf-tab" \
  "https://github.com/Aloxaf/fzf-tab.git" \
  "$ZSH_PLUGIN_DIR/fzf-tab"

update_repo \
  "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"

log "Bootstrap complete"
