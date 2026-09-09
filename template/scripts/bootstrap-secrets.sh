#!/usr/bin/env bash

# bootstrap-secrets.sh
#
# Materializes the workspace-specific GitHub SSH private key from the encrypted
# copy stored in dev-dots.
#
# Expected inputs:
#   SSH_KEY_DECRYPT_PASSWORD  Password used to decrypt the key.
#
# Key selector, in priority order:
#   1. First positional argument
#   2. GITHUB_SSH_KEY
#   3. github_ssh_key
#
# Example:
#   GITHUB_SSH_KEY=000 ./bootstrap-secrets.sh
#
# Encrypted key convention:
#   ~/dev-dots/secrets/github-<selector>.key.enc
#
# Materialized key:
#   ~/.ssh/github

set -u
set -o pipefail

log() {
  printf '[bootstrap-secrets] %s\n' "$*"
}

warn() {
  printf '[bootstrap-secrets] WARNING: %s\n' "$*" >&2
}

fail() {
  printf '[bootstrap-secrets] ERROR: %s\n' "$*" >&2
  exit 1
}

KEY_SELECTOR="${1:-${GITHUB_SSH_KEY:-${github_ssh_key:-}}}"
DECRYPT_PASSWORD="${SSH_KEY_DECRYPT_PASSWORD:-}"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev-dots}"
SECRETS_DIR="${SECRETS_DIR:-$DOTFILES_DIR/secrets}"
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

TARGET_KEY="$SSH_DIR/github"
SSH_CONFIG="$SSH_DIR/config"

if [[ -z "$KEY_SELECTOR" ]]; then
  fail "GitHub SSH key selector is empty. Set GITHUB_SSH_KEY or pass the selector as the first argument."
fi

# Selector is an identifier, never an arbitrary path.
if [[ ! "$KEY_SELECTOR" =~ ^[A-Za-z0-9_-]+$ ]]; then
  fail "Invalid GitHub SSH key selector: '$KEY_SELECTOR'"
fi

if [[ -z "$DECRYPT_PASSWORD" ]]; then
  fail "SSH_KEY_DECRYPT_PASSWORD is not set."
fi

ENCRYPTED_KEY="$SECRETS_DIR/github-${KEY_SELECTOR}.key.enc"

if [[ ! -f "$ENCRYPTED_KEY" ]]; then
  fail "Encrypted SSH key not found: $ENCRYPTED_KEY"
fi

command -v openssl >/dev/null 2>&1 || fail "openssl is not installed."
command -v ssh-keygen >/dev/null 2>&1 || fail "ssh-keygen is not installed."

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Ensure temporary files are created with private permissions from birth.
umask 077

TMP_KEY="$(mktemp "$SSH_DIR/.github.XXXXXX")"

cleanup() {
  rm -f "$TMP_KEY"
}
trap cleanup EXIT INT TERM

log "Decrypting GitHub SSH key '$KEY_SELECTOR'..."

if ! printf '%s' "$DECRYPT_PASSWORD" | openssl enc \
  -d \
  -aes-256-cbc \
  -pbkdf2 \
  -iter 200000 \
  -pass stdin \
  -in "$ENCRYPTED_KEY" \
  -out "$TMP_KEY"
then
  fail "Failed to decrypt $ENCRYPTED_KEY. Existing SSH key was left untouched."
fi

chmod 600 "$TMP_KEY"

# ssh-keygen is deliberately run before replacing the active key.
if ! ssh-keygen -y -f "$TMP_KEY" >/dev/null 2>&1; then
  fail "Decrypted file is not a valid SSH private key. Existing SSH key was left untouched."
fi

# Replace atomically only after successful decryption and validation.
mv -f "$TMP_KEY" "$TARGET_KEY"
chmod 600 "$TARGET_KEY"

# TMP_KEY no longer exists after mv; keep cleanup harmless.
TMP_KEY=""

log "SSH key materialized at $TARGET_KEY"

# Manage only our own block in ~/.ssh/config and leave any unrelated user
# configuration untouched.
BEGIN_MARKER="# BEGIN coder-github-identity"
END_MARKER="# END coder-github-identity"

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

TMP_CONFIG="$(mktemp "$SSH_DIR/.config.XXXXXX")"

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skip = 1; next }
  $0 == end   { skip = 0; next }
  !skip       { print }
' "$SSH_CONFIG" > "$TMP_CONFIG"

# Normalize trailing whitespace/newlines before appending our managed block.
while [[ -s "$TMP_CONFIG" ]] && [[ "$(tail -c 1 "$TMP_CONFIG" | wc -l)" -eq 0 ]]; do
  printf '\n' >> "$TMP_CONFIG"
  break
done

cat >> "$TMP_CONFIG" <<EOF
$BEGIN_MARKER
Host github.com
  HostName github.com
  User git
  IdentityFile $TARGET_KEY
  IdentitiesOnly yes
$END_MARKER
EOF

chmod 600 "$TMP_CONFIG"
mv -f "$TMP_CONFIG" "$SSH_CONFIG"

log "SSH config updated for github.com"
log "GitHub SSH identity '$KEY_SELECTOR' is ready."
