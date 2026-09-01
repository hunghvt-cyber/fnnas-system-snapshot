#!/usr/bin/env bash
set -u
set -o pipefail

REPO="/vol1/Docker/fnnas-system-snapshot"
WATCH_ROOT="/vol1/Docker"
LOCK="/tmp/fnnas-system-snapshot-watcher.lock"

cd "$REPO" || exit 1

exec 9>"$LOCK"

if ! flock -n 9; then
    echo "Watcher already running."
    exit 1
fi

echo "========================================"
echo "FnNAS Snapshot Watcher"
echo "========================================"
echo "Watching: $WATCH_ROOT"
echo "Debounce: 10 seconds"
echo "========================================"

while true; do

    inotifywait \
        -r \
        -q \
        -e close_write \
        -e create \
        -e delete \
        -e move \
        --exclude '(^|/)(\.git|node_modules|cache|Cache|logs?|tmp)(/|$)' \
        "$WATCH_ROOT" >/dev/null 2>&1

    echo
    echo "[EVENT] Change detected: $(date '+%Y-%m-%d %H:%M:%S %z')"

    "$REPO/scripts/auto-update.sh" || true

done
