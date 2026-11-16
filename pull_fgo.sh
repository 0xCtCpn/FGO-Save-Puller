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
#   - If adb is missing, the script asks for confirmation and then installs the official
#     SDK Platform-Tools automatically (downloads ~15 MB from Google, developer.android.com).

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- ensure adb is available -------------------------------------------------

ADB_URL="https://developer.android.com/tools/releases/platform-tools"

# Resolve an existing adb: PATH first, then a copy sitting next to this script.
find_existing_adb() {
  if command -v adb >/dev/null 2>&1; then
    ADB="$(command -v adb)"
    return 0
  fi
  local c
  for c in "$SCRIPT_DIR/adb" "$SCRIPT_DIR/adb.exe" \
           "$SCRIPT_DIR/platform-tools/adb" "$SCRIPT_DIR/platform-tools/adb.exe"; do
    if [ -f "$c" ]; then
      ADB="$c"
      return 0
    fi
  done
  return 1
}

# Convert a local path to Windows form (needed when shelling out to powershell.exe).
winpath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

download_file() { # <url> <dest>
  local url="$1" dest="$2" wdest
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 2 --connect-timeout 20 -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$dest" "$url"
  elif command -v powershell.exe >/dev/null 2>&1; then
    wdest="$(winpath "$dest")"
    powershell.exe -NoProfile -Command \
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '${url}' -OutFile '${wdest}' -UseBasicParsing } catch { exit 1 }"
  else
    die "no downloader available (need curl, wget, or powershell.exe)"
  fi
}

extract_zip() { # <zip> <destdir>
  local zip="$1" destdir="$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -oq "$zip" -d "$destdir"
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "Expand-Archive -LiteralPath '$(winpath "$zip")' -DestinationPath '$(winpath "$destdir")' -Force"
  else
    die "no unzip available (need unzip or powershell.exe)"
  fi
}

# Download the official Platform-Tools zip for this OS and unpack it next to the script.
install_adb() {
  local uname_s os zipname url tmpdir zip

  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  case "$uname_s" in
    MINGW*|MSYS*|CYGWIN*) os=windows ;;
    Darwin*)             os=darwin  ;;
    Linux*)              os=linux   ;;
    *)                   os=""      ;;
  esac

  if [ -z "$os" ]; then
    echo "error: can't detect your platform to auto-install adb." >&2
    echo "Install the official Platform-Tools manually:" >&2
    echo "  ${ADB_URL}" >&2
    return 1
  fi

  zipname="platform-tools-latest-${os}.zip"
  url="https://dl.google.com/android/repository/${zipname}"

  echo "  Downloading the official Android SDK Platform-Tools from Google"
  echo "  (~15 MB, developer.android.com) and installing it next to this script."
  echo "    ${url}"

  tmpdir="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/fgo-adb-$$")"
  mkdir -p "$tmpdir"
  zip="${tmpdir}/${zipname}"

  echo "  Downloading..."
  if ! download_file "$url" "$zip"; then
    rm -rf "$tmpdir"
    echo "error: download failed. Check your connection and try again." >&2
    return 1
  fi

  echo "  Extracting..."
  if ! extract_zip "$zip" "$SCRIPT_DIR"; then
    rm -rf "$tmpdir"
    echo "error: extraction failed." >&2
    return 1
  fi
  rm -rf "$tmpdir"

  ADB="$SCRIPT_DIR/platform-tools/adb"
  [ -f "$ADB" ] || ADB="$SCRIPT_DIR/platform-tools/adb.exe"
  if [ ! -f "$ADB" ]; then
    echo "error: adb binary not found after extraction." >&2
    return 1
  fi
  chmod +x "$ADB" 2>/dev/null || true

  echo "  Installed adb -> ${ADB}"
  return 0
}

if find_existing_adb; then
  :
else
  echo "  adb not found on PATH." >&2
  if [ -t 0 ]; then
    printf '  Install adb automatically now? [y/N] '
    read -r ans
    case "$ans" in
      y | Y) install_adb || exit 1 ;;
      *)     die "install adb first, then re-run (or re-run and answer y)" ;;
    esac
  else
    echo "  (not an interactive terminal; install adb manually)" >&2
    echo "  ${ADB_URL}" >&2
    die "install adb first, then re-run"
  fi
fi

# sanity check that the resolved adb actually runs
if ! "$ADB" version >/dev/null 2>&1; then
  die "adb is not usable: $ADB"
fi

# --- wait for a device -------------------------------------------------------

for _ in $(seq 1 30); do
  state=$("$ADB" get-state 2>/dev/null || true)
  [ "$state" = "device" ] && break
  if [ "$state" = "unauthorized" ]; then
    echo "Waiting for USB-debugging authorization on the phone..."
  fi
  sleep 2
done
[ "$state" = "device" ] || die "no authorized device (state: ${state:-none})"

"$ADB" devices -l

# --- pull --------------------------------------------------------------------

mkdir -p "${OUTDIR}/files/data"
cd "${OUTDIR}/files/data"

ok=0
fail=0
for f in "${FILES[@]}"; do
  if MSYS_NO_PATHCONV=1 "$ADB" pull "${REMOTE_BASE}/${f}" "./" 2>/dev/null; then
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