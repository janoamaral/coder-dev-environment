#!/usr/bin/env bash

set -u

DOTFILES_REPO="https://github.com/janoamaral/dev-dots.git"
DOTFILES_DIR="$HOME/dev-dots"

DOTFILES_PACKAGES=(
    git
    nvim
    opencode
    zsh
    misc
    node
    bin
    ssh
)

log() {
    printf '[dotfiles] %s\n' "$*"
}

warn() {
    printf '[dotfiles] warning: %s\n' "$*" >&2
}

update_repo() {
    local name="$1"
    local repo="$2"
    local dir="$3"

    if [ ! -d "$dir/.git" ]; then
        log "Cloning $name"

        if ! git clone --depth 1 "$repo" "$dir"; then
            warn "Could not clone $name"
            return 1
        fi
    else
        log "Updating $name"

        if ! git -C "$dir" pull --ff-only; then
            warn "Could not fast-forward $name; keeping local state"
            return 1
        fi
    fi

    return 0
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
    "${DOTFILES_PACKAGES[@]}"; then
    warn "Stow failed; existing files were left untouched"
    exit 0
fi

log "Dotfiles ready"

# -----------------------------------------------------------------------------
# Zsh plugins
# -----------------------------------------------------------------------------

ZSH_PLUGIN_DIR="$HOME/.config/zsh/plugins"

mkdir -p "$ZSH_PLUGIN_DIR"

ZSH_PLUGINS=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
    "fzf-tab|https://github.com/Aloxaf/fzf-tab.git"
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

mkdir -p "$ZSH_PLUGIN_DIR"

for plugin in "${ZSH_PLUGINS[@]}"; do
    name="${plugin%%|*}"
    repo="${plugin#*|}"

    update_repo \
        "$name" \
        "$repo" \
        "$ZSH_PLUGIN_DIR/$name"
done

log "Zsh plugins ready"
