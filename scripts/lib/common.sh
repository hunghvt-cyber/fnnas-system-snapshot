#!/usr/bin/env bash
set -u

REPO="/vol1/Docker/fnnas-system-snapshot"
SNAPSHOT_DIR="$REPO/snapshots"

run() {
    local title="$1"
    shift

    {
        echo "===== $title ====="
        echo "Command: $*"
        echo

        if "$@" 2>&1; then
            :
        else
            echo
            echo "[WARN] command failed: $*"
        fi
    }
}

write_text() {
    local file="$1"
    shift

    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$@" > "$file"
}

is_sensitive_name() {
    local path="$1"
    local base
    base="$(basename "$path")"

    case "$base" in
        .env|.env.*)
            return 0
            ;;
        *.key|*.pem|*.p12|*.pfx|*.secret|*.crt)
            return 0
            ;;
        *credential*|*credentials*)
            return 0
            ;;
        *secret*|*token*)
            return 0
            ;;
        *apikey*|*api_key*)
            return 0
            ;;
        *private-key*|*private_key*)
            return 0
            ;;
    esac

    return 1
}

safe_file_list() {
    local dir="$1"

    [ -d "$dir" ] || return 0

    find "$dir" -type f 2>/dev/null |
        while IFS= read -r file; do
            if ! is_sensitive_name "$file"; then
                printf '%s\n' "$file"
            fi
        done |
        sort -u
}
