#!/usr/bin/env bash
# pull_fgo.sh — pull specific FGO save files from Android /Android/data via adb.
#
# FGO's /Android/data/com.aniplex.fategrandorder.en folder is ~5.8 GB, so pulling the
# whole thing is slow and mostly pointless. These four small files under files/data are
# the ones that usually matter (account / transfer data).
#
# Usage:
#   ./pull_fgo.sh                  # pull the default 4 files
#   ./pull_fgo.sh <outdir>         # pull the default 4 files into <outdir>
#   ./pull_fgo.sh <outdir> <f1> <f2> ...   # pull specific files
#
# Notes:
#   - On Git Bash, MSYS_NO_PATHCONV=1 is required or the /sdcard/... path gets rewritten.
#   - The phone must be unlocked and USB-debugging authorized (accept the RSA prompt).
#   - If adb is missing, the script offers to open Google's official download page.

set -euo pipefail

PACKAGE="com.aniplex.fategrandorder.en"
REMOTE_BASE="/sdcard/Android/data/${PACKAGE}/files/data"

DEFAULT_FILES=(
  54cc
  969b
  644b
  e1a9
)

OUTDIR="${1:-fgo_android_data}"
shift || true
FILES=("$@")
[ ${#FILES[@]} -eq 0 ] && FILES=("${DEFAULT_FILES[@]}")

die() { echo "error: $*" >&2; exit 1; }

# --- ensure adb is available -------------------------------------------------

ADB_URL="https://developer.android.com/tools/releases/platform-tools"

if command -v adb >/dev/null 2>&1; then
  :
else
  echo "adb not found on PATH." >&2
  echo "Get the official Android SDK Platform-Tools here:" >&2
  echo "  ${ADB_URL}" >&2
  echo >&2
  echo "Download the 'SDK Platform-Tools for Windows' zip, unzip it," >&2
  echo "and add the folder to PATH (or put adb.exe next to this script)." >&2

  if [ -t 0 ] && command -v cmd.exe >/dev/null 2>&1; then
    printf 'Open the download page now? [y/N] '
    read -r ans
    case "$ans" in
      y | Y) cmd.exe /c start "" "${ADB_URL}" >/dev/null 2>&1 || true ;;
    esac
  fi

  die "install adb first, then re-run"
fi

# --- wait for a device -------------------------------------------------------

for _ in $(seq 1 30); do
  state=$(adb get-state 2>/dev/null || true)
  [ "$state" = "device" ] && break
  if [ "$state" = "unauthorized" ]; then
    echo "Waiting for USB-debugging authorization on the phone..."
  fi
  sleep 2
done
[ "$state" = "device" ] || die "no authorized device (state: ${state:-none})"

adb devices -l

# --- pull --------------------------------------------------------------------

mkdir -p "${OUTDIR}/files/data"
cd "${OUTDIR}/files/data"

ok=0
fail=0
for f in "${FILES[@]}"; do
  if MSYS_NO_PATHCONV=1 adb pull "${REMOTE_BASE}/${f}" "./" 2>/dev/null; then
    ok=$((ok + 1))
  else
    echo "  missing: $f" >&2
    fail=$((fail + 1))
  fi
done

echo
echo "pulled $ok file(s), $fail missing -> ${OUTDIR}/files/data/"
echo "total size: $(du -sh . 2>/dev/null | cut -f1)"
[ "$fail" -eq 0 ]