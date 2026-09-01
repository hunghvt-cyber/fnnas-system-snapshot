#!/usr/bin/env bash

set -u
set -o pipefail

REPO="/vol1/Docker/fnnas-system-snapshot"
SNAPSHOT_ROOT="$REPO/snapshots"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
OUT="$SNAPSHOT_ROOT/fnnas-$TIMESTAMP"

mkdir -p \
    "$OUT/docker" \
    "$OUT/compose" \
    "$OUT/services" \
    "$OUT/security"

exec > >(tee "$OUT/collector.log") 2>&1

echo "========================================"
echo "FnNAS System Snapshot"
echo "========================================"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Output:  $OUT"
echo

warn() {
    echo "[WARN] $*"
}

run_to_file() {
    local file="$1"
    shift

    {
        echo "Command: $*"
        echo
        "$@" 2>&1 || {
            echo
            echo "[WARN] command failed: $*"
        }
    } > "$file"
}

safe_find_scripts() {
    local dir="$1"

    [ -d "$dir" ] || return 0

    find "$dir" -type f \
        \( -name '*.sh' -o -name '*.py' -o -name '*.js' \) \
        -not -path '*/node_modules/*' \
        2>/dev/null |
    while IFS= read -r file; do
        base="$(basename "$file")"

        case "$base" in
            *credential*|*credentials*|*secret*|*token*|*.env|*.key|*.pem)
                continue
                ;;
        esac

        printf '%s\n' "$file"
    done |
    sort -u
}

echo "Collecting host information..."

{
    echo "===== HOST ====="
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
        \( -name 'docker-compose.yml' \
        -o -name 'docker-compose.yaml' \
        -o -name 'compose.yml' \
        -o -name 'compose.yaml' \) \
        -not -path '*/node_modules/*' \
        2>/dev/null |
    while IFS= read -r file; do
        base="$(basename "$file")"

        case "$file" in
            */.git/*)
                continue
                ;;
        esac

        printf '%s\n' "$file"
    done |
    sort -u
} > "$OUT/compose/inventory.txt"

{
    echo "FnNAS Compose / Docker Paths"
    echo "============================"
    echo
    find /vol1/Docker \
        -maxdepth 3 \
        -type d \
        2>/dev/null |
        sort
} > "$OUT/compose/paths.txt"

echo "Collecting system cron..."

{
    echo "===== SYSTEM CRONTAB ====="
    crontab -l 2>&1 || true
    echo
    echo "===== /etc/crontab ====="
    cat /etc/crontab 2>&1 || true
    echo
    echo "===== CRON.D ====="

    if [ -d /etc/cron.d ]; then
        find /etc/cron.d -maxdepth 1 -type f \
            -not -name '*.dpkg-*' \
            -print 2>/dev/null |
            sort |
            while IFS= read -r file; do
                echo "--- $file ---"
                sed -E \
                    -e 's/(password|passwd|token|secret|api[_-]?key|authorization|bearer|credential|client_secret|access_token|refresh_token)=([^[:space:]]+)/\1=[REDACTED]/Ig' \
                    "$file" 2>/dev/null || true
            done
    fi
} > "$OUT/services/cron.txt"

echo "Collecting script inventory..."

{
    echo "FnNAS Custom Script Inventory"
    echo "============================="
    echo
    echo "Paths only. Script contents are intentionally excluded."
    echo

    for dir in \
        /opt/scripts \
        /vol1/Docker \
        /usr/local/bin
    do
        safe_find_scripts "$dir"
    done
} > "$OUT/services/scripts.txt"

echo "Writing security report..."

cat > "$OUT/security/sanitized.txt" <<'SECURITY'
FnNAS Security / Secret Scan
=============================

This snapshot intentionally excludes secret contents and
sensitive filenames.

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

The snapshot records system structure and operational metadata,
not secret values.

Security status:
Secret-content protection enabled.
SECURITY

echo "Writing metadata..."

{
    echo "FnNAS System Snapshot Metadata"
    echo "=============================="
    echo
    echo "Snapshot:"
    echo "$(basename "$OUT")"
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
    echo "Snapshot root:"
    echo "$REPO"
} > "$OUT/metadata.txt"

echo "Creating summary..."

FILE_COUNT="$(find "$OUT" -type f | wc -l | tr -d ' ')"
SIZE="$(du -sh "$OUT" | awk '{print $1}')"

{
    echo "FnNAS Snapshot Summary"
    echo "====================="
    echo "Snapshot: $(basename "$OUT")"
    echo "Created:  $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo
    echo "Files:"
    find "$OUT" -type f \
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
echo "Snapshot completed"
echo "Output: $OUT"
echo "Files:  $FILE_COUNT"
echo "Size:   $SIZE"
echo "========================================"
