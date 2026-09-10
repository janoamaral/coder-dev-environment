#!/usr/bin/env bash

set -u
set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev-dots}"

GITHUB_KEY_ID="${GITHUB_SSH_KEY:-}"

SECRETS_DIR="$DOTFILES_DIR/secrets"

SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/github"
SSH_KEY_ID_FILE="$SSH_DIR/.github-key-id"
SSH_CONFIG="$SSH_DIR/config"

PBKDF2_ITERATIONS=200000

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log() {
    printf '[secrets] %s\n' "$*"
}

warn() {
    printf '[secrets] warning: %s\n' "$*" >&2
}

# -----------------------------------------------------------------------------
# SSH configuration
# -----------------------------------------------------------------------------

configure_ssh() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    if grep -qF "# BEGIN CODER GITHUB SSH" "$SSH_CONFIG"; then
        return 0
    fi

    cat >>"$SSH_CONFIG" <<'EOF'

# BEGIN CODER GITHUB SSH
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github
  IdentitiesOnly yes
# END CODER GITHUB SSH
EOF

    log "GitHub SSH configuration added"
}

# -----------------------------------------------------------------------------
# GitHub SSH key
# -----------------------------------------------------------------------------

install_github_key() {
    local encrypted_key
    local temp_key
    local current_key_id=""

    if [ -z "$GITHUB_KEY_ID" ]; then
        warn "No GitHub SSH key selected for this workspace"
        return 0
    fi

    # Defense in depth. Terraform validates this too.
    if [[ ! "$GITHUB_KEY_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        warn "Invalid GitHub SSH key identifier: $GITHUB_KEY_ID"
        return 0
    fi

    if [ -z "${SSH_KEY_DECRYPT_PASSWORD:-}" ]; then
        warn "SSH_KEY_DECRYPT_PASSWORD is not available"
        return 0
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        warn "openssl is required to decrypt SSH keys"
        return 0
    fi

    if ! command -v ssh-keygen >/dev/null 2>&1; then
        warn "ssh-keygen is required to validate SSH keys"
        return 0
    fi

    encrypted_key="$SECRETS_DIR/github-${GITHUB_KEY_ID}.key.enc"

    if [ ! -f "$encrypted_key" ]; then
        warn "Encrypted SSH key not found: $encrypted_key"
        return 0
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    if [ -f "$SSH_KEY_ID_FILE" ]; then
        current_key_id="$(cat "$SSH_KEY_ID_FILE" 2>/dev/null || true)"
    fi

    temp_key="$(mktemp "$SSH_DIR/.github.XXXXXX")"

    if ! openssl enc \
        -d \
        -aes-256-cbc \
        -pbkdf2 \
        -iter "$PBKDF2_ITERATIONS" \
        -in "$encrypted_key" \
        -out "$temp_key" \
        -pass env:SSH_KEY_DECRYPT_PASSWORD; then
        rm -f "$temp_key"

        # Don't accidentally keep using a different workspace identity.
        if [ -n "$current_key_id" ] && [ "$current_key_id" != "$GITHUB_KEY_ID" ]; then
            rm -f "$SSH_KEY" "$SSH_KEY_ID_FILE"
        fi

        warn "Could not decrypt GitHub SSH key: $GITHUB_KEY_ID"
        return 0
    fi

    chmod 600 "$temp_key"

    # Verify that what we decrypted really is a valid SSH private key.
    if ! ssh-keygen -y -f "$temp_key" >/dev/null 2>&1; then
        rm -f "$temp_key"

        if [ -n "$current_key_id" ] && [ "$current_key_id" != "$GITHUB_KEY_ID" ]; then
            rm -f "$SSH_KEY" "$SSH_KEY_ID_FILE"
        fi

        warn "Decrypted content is not a valid SSH private key"
        return 0
    fi

    # Atomic replacement. ~/.ssh/github is never partially written.
    mv -f "$temp_key" "$SSH_KEY"
    chmod 600 "$SSH_KEY"

    printf '%s\n' "$GITHUB_KEY_ID" >"$SSH_KEY_ID_FILE"
    chmod 600 "$SSH_KEY_ID_FILE"

    log "GitHub SSH key ready: $GITHUB_KEY_ID"
}

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------

main() {
    umask 077

    configure_ssh
    install_github_key

    log "Configuring Git to use workspace SSH identity"

    git config --global \
        core.sshCommand \
        "ssh -F $HOME/.ssh/config"

    log "Secrets bootstrap complete"
}

main "$@"
