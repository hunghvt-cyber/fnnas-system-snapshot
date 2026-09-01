#!/usr/bin/env bash
set -u
set -o pipefail

REPO="/vol1/Docker/fnnas-system-snapshot"
SNAPSHOT_ROOT="$REPO/snapshots"
LATEST="$SNAPSHOT_ROOT/latest"
TMP_ROOT="/tmp/fnnas-system-snapshot"
OUT="$TMP_ROOT/current"

rm -rf "$OUT"
mkdir -p \
    "$OUT/docker" \
    "$OUT/compose" \
    "$OUT/services" \
    "$OUT/security"

warn() {
    echo "[WARN] $*" >&2
}

run_to_file() {
    local file="$1"
    shift

    {
        echo "Command: $*"
        echo

        if "$@" 2>&1; then
            :
        else
            echo
            echo "[WARN] command failed: $*"
        fi
    } > "$file"
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

safe_path_list() {
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

echo "========================================"
echo "FnNAS System Snapshot"
echo "========================================"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Output:  $OUT"
echo

echo "Collecting host information..."

{
    echo "===== HOST ====="
    echo

    echo "Hostname:"
    hostname 2>&1

    echo
    echo "Kernel:"
    uname -a 2>&1

    echo
    echo "OS:"
    cat /etc/os-release 2>&1

    echo
    echo "Architecture:"
    uname -m 2>&1

    echo
    echo "CPU:"
    lscpu 2>&1 || true
} > "$OUT/host.txt"

echo "Collecting memory..."

{
    echo "===== MEMORY ====="
    echo
    free -h 2>&1

    echo
    echo "===== /proc/meminfo ====="
    cat /proc/meminfo 2>&1

    echo
    echo "===== SWAP ====="
    swapon --show 2>&1 || true
} > "$OUT/memory.txt"

echo "Collecting storage..."

{
    echo "===== FILESYSTEMS ====="
    df -hT 2>&1

    echo
    echo "===== MOUNTS ====="
    findmnt 2>&1 || true

    echo
    echo "===== BLOCK DEVICES ====="
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,ROTA,TYPE 2>&1 || true
} > "$OUT/storage.txt"

echo "Collecting Docker information..."

run_to_file "$OUT/docker/version.txt" docker version
run_to_file "$OUT/docker/containers.txt" docker ps -a --no-trunc
run_to_file "$OUT/docker/images.txt" docker images --no-trunc
run_to_file "$OUT/docker/networks.txt" docker network ls
run_to_file "$OUT/docker/volumes.txt" docker volume ls
run_to_file "$OUT/docker/resources.txt" docker system df

echo "Collecting Compose inventory..."

{
    echo "FnNAS Docker Compose Inventory"
    echo "=============================="
    echo
    echo "Only compose/project paths are recorded."
    echo "Compose file contents are NOT copied."
    echo

    find /vol1/Docker \
        -type f \
        \( \
            -name 'docker-compose.yml' \
            -o -name 'docker-compose.yaml' \
            -o -name 'compose.yml' \
            -o -name 'compose.yaml' \
        \) \
        -not -path '*/node_modules/*' \
        2>/dev/null |
    while IFS= read -r file; do
        if ! is_sensitive_name "$file"; then
            printf '%s\n' "$file"
        fi
    done |
    sort -u

} > "$OUT/compose/inventory.txt"

{
    echo "FnNAS Compose / Docker Paths"
    echo "============================"
    echo
    echo "Sensitive filenames are excluded."
    echo

    find /vol1/Docker \
        -maxdepth 3 \
        -type d \
        2>/dev/null |
    while IFS= read -r dir; do
        if ! is_sensitive_name "$dir"; then
            printf '%s\n' "$dir"
        fi
    done |
    sort -u

} > "$OUT/compose/paths.txt"

echo "Collecting system cron..."

{
    echo "===== SYSTEM CRONTAB ====="

    if [ -r /etc/crontab ]; then
        sed -E \
            -e 's/(password|passwd|token|secret|api[_-]?key|authorization|bearer|credential|client_secret|access_token|refresh_token)[[:space:]]*=[[:space:]]*[^[:space:]]+/\1=[REDACTED]/Ig' \
            /etc/crontab
    fi

    echo
    echo "===== USER CRONTAB ====="

    crontab -l 2>&1 |
        sed -E \
            -e 's/(password|passwd|token|secret|api[_-]?key|authorization|bearer|credential|client_secret|access_token|refresh_token)[[:space:]]*=[[:space:]]*[^[:space:]]+/\1=[REDACTED]/Ig' \
        || true

    echo
    echo "===== CRON.D ====="

    if [ -d /etc/cron.d ]; then
        find /etc/cron.d \
            -maxdepth 1 \
            -type f \
            -not -name '*.dpkg-*' \
            2>/dev/null |
        sort |
        while IFS= read -r file; do

            if is_sensitive_name "$file"; then
                continue
            fi

            echo "--- $file ---"

            sed -E \
                -e 's/(password|passwd|token|secret|api[_-]?key|authorization|bearer|credential|client_secret|access_token|refresh_token)[[:space:]]*=[[:space:]]*[^[:space:]]+/\1=[REDACTED]/Ig' \
                "$file" 2>/dev/null || true
        done
    fi

} > "$OUT/services/cron.txt"

echo "Collecting custom script inventory..."

{
    echo "FnNAS Custom Script Inventory"
    echo "============================="
    echo
    echo "Paths only."
    echo "Script contents are intentionally excluded."
    echo

    for dir in \
        /opt/scripts \
        /vol1/Docker \
        /usr/local/bin
    do
        safe_path_list "$dir"
    done

} > "$OUT/services/scripts.txt"

echo "Writing security report..."

cat > "$OUT/security/sanitized.txt" <<'SECURITY'
FnNAS Security / Secret Scan
=============================

This snapshot intentionally excludes secret contents
and sensitive filenames.

Protected categories:
- passwords
- API keys
- access tokens
- bearer tokens
- credentials
- private keys
- certificates
- JWT secrets
- Gemini credentials
- Cloudflare credentials
- Telegram credentials
- .env files
- SSH keys
- Docker secret files

The snapshot records system structure and operational
metadata, not secret values.

Security status:
Secret-content protection enabled.
SECURITY

echo "Writing metadata..."

{
    echo "FnNAS System Snapshot Metadata"
    echo "=============================="
    echo

    echo "Created:"
    date '+%Y-%m-%d %H:%M:%S %z'

    echo
    echo "Hostname:"
    hostname 2>&1

    echo
    echo "Kernel:"
    uname -r 2>&1

    echo
    echo "Architecture:"
    uname -m 2>&1

    echo
    echo "Snapshot type:"
    echo "latest"

} > "$OUT/metadata.txt"

echo "Creating summary..."

FILE_COUNT="$(find "$OUT" -type f | wc -l | tr -d ' ')"
SIZE="$(du -sh "$OUT" | awk '{print $1}')"

{
    echo "FnNAS Snapshot Summary"
    echo "====================="
    echo "Created:  $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo

    echo "Files:"
    find "$OUT" \
        -type f \
        -printf '%P\n' |
        sort

    echo
    echo "File count:"
    echo "$FILE_COUNT"

    echo
    echo "Snapshot size:"
    echo "$SIZE"

} > "$OUT/SUMMARY.txt"

echo
echo "========================================"
echo "Snapshot collection completed"
echo "Files: $FILE_COUNT"
echo "Size:  $SIZE"
echo "========================================"


# Replace latest safely.
rm -rf "$LATEST.new"
cp -a "$OUT" "$LATEST.new"

rm -rf "$LATEST"
mv "$LATEST.new" "$LATEST"

echo "Latest snapshot updated:"
echo "$LATEST"
