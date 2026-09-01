#!/usr/bin/env bash
set -u
set -o pipefail

REPO="/vol1/Docker/fnnas-system-snapshot"
LOCK="/tmp/fnnas-system-snapshot.lock"
DEBOUNCE=10

cd "$REPO" || exit 1

exec 9>"$LOCK"

if ! flock -n 9; then
    exit 0
fi

echo "========================================"
echo "FnNAS Snapshot Auto Update"
echo "========================================"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %z')"

# Wait for burst of filesystem events to settle.
sleep "$DEBOUNCE"

echo
echo "Running snapshot..."
if ! "$REPO/scripts/snapshot.sh"; then
    echo "[ERROR] snapshot failed"
    exit 1
fi

echo
echo "Running security scan..."

if grep -RniE \
    '(^|[[:space:]"'\''])(password|passwd|token|api[_-]?key|authorization|bearer|credential|client_secret|access_token|refresh_token|GEMINI_API_KEY)[[:space:]]*[:=][[:space:]]*[^[:space:]]' \
    "$REPO/snapshots/latest" \
    --exclude='sanitized.txt' \
    --exclude='*.log' \
    >/tmp/fnnas-secret-scan.txt 2>/dev/null
then
    echo "[ERROR] Possible secret content detected."
    cat /tmp/fnnas-secret-scan.txt
    echo "[ERROR] Snapshot will NOT be pushed."
    exit 1
fi

if grep -RniE \
    'BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY|BEGIN CERTIFICATE' \
    "$REPO/snapshots/latest" \
    >/tmp/fnnas-key-scan.txt 2>/dev/null
then
    echo "[ERROR] Private key/certificate detected."
    cat /tmp/fnnas-key-scan.txt
    echo "[ERROR] Snapshot will NOT be pushed."
    exit 1
fi

echo "Security scan: OK"

echo
echo "Checking Git changes..."

git add \
    snapshots/latest \
    scripts/snapshot.sh \
    scripts/auto-update.sh \
    .gitignore \
    README.md \
    docs/

if git diff --cached --quiet; then
    echo "No repository changes."
    exit 0
fi

echo
echo "Changes detected:"
git diff --cached --stat

COMMIT_MSG="chore: update FnNAS system snapshot"

git commit -m "$COMMIT_MSG"

echo
echo "Pushing to GitHub..."

if git push origin main; then
    echo
    echo "GitHub update: OK"
else
    echo
    echo "[ERROR] GitHub push failed."
    echo "Local commit was preserved."
    exit 1
fi

echo
echo "========================================"
echo "Auto update completed"
echo "========================================"
