#!/usr/bin/env bash
set -u
set -o pipefail

log() { printf '[bootstrap-repos] %s\n' "$*"; }
warn() { printf '[bootstrap-repos] WARNING: %s\n' "$*" >&2; }

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/workspace}"
REPOSITORIES_JSON="${REPOSITORIES_JSON:-}"

command -v jq >/dev/null 2>&1 || {
    warn "jq is not installed; skipping."
    exit 0
}
command -v git >/dev/null 2>&1 || {
    warn "git is not installed; skipping."
    exit 0
}

if [[ -z "$REPOSITORIES_JSON" ]]; then
    log "No repository manifest configured; nothing to do."
    exit 0
fi

if ! printf '%s' "$REPOSITORIES_JSON" | jq -e '
  type == "object"
  and (.repos | type == "array")
  and all(.repos[];
    type == "object"
    and (.url | type == "string" and length > 0)
    and (.path | type == "string" and length > 0)
  )
' >/dev/null 2>&1; then
    warn 'Invalid REPOSITORIES_JSON. Expected {"repos":[{"url":"...","path":"..."}]}'
    exit 0
fi

mkdir -p "$WORKSPACE_DIR"

printf '%s' "$REPOSITORIES_JSON" | jq -c '.repos[]' |
    while IFS= read -r repo; do
        url="$(printf '%s' "$repo" | jq -r '.url')"
        path="$(printf '%s' "$repo" | jq -r '.path')"

        if [[ "$path" == /* ]]; then
            warn "Skipping '$path': absolute paths are not allowed."
            continue
        fi

        if printf '%s\n' "$path" | tr '/' '\n' | grep -qx '\.\.'; then
            warn "Skipping '$path': parent-directory traversal is not allowed."
            continue
        fi

        if [[ ! "$path" =~ ^[A-Za-z0-9._/-]+$ ]]; then
            warn "Skipping '$path': unsupported characters."
            continue
        fi

        target="$WORKSPACE_DIR/$path"

        if [[ -e "$target" || -L "$target" ]]; then
            log "Exists, leaving untouched: $target"
            continue
        fi

        mkdir -p "$(dirname "$target")"
        log "Cloning $url -> $target"

        unset GIT_SSH_COMMAND
        unset GIT_ASKPASS

        if GIT_SSH_COMMAND="ssh -F $HOME/.ssh/config" \
            git clone -- "$url" "$target"; then
            log "Cloned: $path"
        else
            warn "Failed to clone '$url'; continuing."
            if [[ -d "$target" ]] && [[ -z "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
                rmdir "$target" 2>/dev/null || true
            fi
        fi
    done

log "Repository bootstrap finished."
