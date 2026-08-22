#!/bin/bash
# scripts/apply-patches.sh
# Apply TWRP source changes for SM8850 devices.
# Applies patches/common first, then only the target device's own set.
# Usage: ./scripts/apply-patches.sh [TWRP_SOURCE_ROOT] [DEVICE_CODENAME]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
TWRP_SOURCE="${1:-$(pwd)}"
DEVICE="${2:-}"

echo "========================================"
echo "TWRP SM8850 Source Patch Apply Script"
echo "========================================"
echo "TWRP source root: $TWRP_SOURCE"
echo "Device codename:  ${DEVICE:-<none, common only>}"
echo ""

# Device codename -> per-device patch directory
device_patch_dir() {
    case "$1" in
        myron)            echo "myron" ;;
        annibale)         echo "annibale" ;;
        songyuan)         echo "songyuan" ;;
        nezha)            echo "nezha" ;;
        RE6402L1|neo8)    echo "neo8" ;;
        *)                echo "" ;;
    esac
}

# Option 1: Apply git patches (recommended for upstream tracking)
apply_patch_files() {
    local set_root="$1"
    for patch_file in "$set_root"/patches/*/*.patch; do
        [ -f "$patch_file" ] || continue
        dir=$(basename "$(dirname "$patch_file")")
        # Convert underscore notation to path
        target="${dir/_//}"
        echo "  -> Applying: $(basename "$patch_file") to $target"
        if [ -d "$TWRP_SOURCE/$target" ]; then
            if (cd "$TWRP_SOURCE/$target" && git apply --check "$patch_file" 2>/dev/null); then
                (cd "$TWRP_SOURCE/$target" && git apply "$patch_file")
            elif (cd "$TWRP_SOURCE/$target" && git apply --reverse --check "$patch_file" 2>/dev/null); then
                echo "     Already applied."
            else
                echo "     ERROR: patch does not match the target source tree."
                exit 1
            fi
        else
            echo "     WARNING: target directory $TWRP_SOURCE/$target not found, skipping."
        fi
    done
}

# Option 2: Copy modified files directly (fallback / exact replacement)
apply_files() {
    local set_root="$1"
    if [ -d "$set_root/files" ]; then
        ( cd "$set_root/files" && find . -type f ) | while read -r file; do
            src="$set_root/files/$file"
            dst="$TWRP_SOURCE/$file"
            mkdir -p "$(dirname "$dst")"
            echo "  -> Copying: $file"
            cp -f "$src" "$dst"
        done
    fi
}

# Copy device-owned files to source paths whose upstream modules otherwise
# overwrite the recovery-root copies during final ramdisk assembly.
apply_mapped_files() {
    local set_root="$1"
    local map_file="$set_root/source-files.map"
    [ -f "$map_file" ] || return 0

    while read -r source target; do
        [ -n "${source:-}" ] || continue
        case "$source" in \#*) continue ;; esac
        src="$REPO_ROOT/$source"
        dst="$TWRP_SOURCE/$target"
        if [ ! -f "$src" ]; then
            echo "     ERROR: mapped source file not found: $source"
            exit 1
        fi
        mkdir -p "$(dirname "$dst")"
        echo "  -> Mapping: $source to $target"
        cp -f "$src" "$dst"
    done < "$map_file"
}

apply_set() {
    echo "[set] $2"
    # Exact files establish the selected device baseline before incremental patches.
    apply_files "$1"
    apply_mapped_files "$1"
    apply_patch_files "$1"
    echo ""
}

# Reject unknown codenames instead of silently applying only the common set.
if [ -n "$DEVICE" ] && [ -z "$(device_patch_dir "$DEVICE")" ]; then
    echo "Error: unsupported device codename '$DEVICE'."
    exit 1
fi

# 1. Common patches: applied for every device.
apply_set "$REPO_ROOT/patches/common" "common (all devices)"

# 2. Per-device patches: only for the requested device.
DEVICE_SET="$(device_patch_dir "$DEVICE")"
if [ -n "$DEVICE_SET" ] && { [ -d "$REPO_ROOT/patches/$DEVICE_SET/files" ] || [ -d "$REPO_ROOT/patches/$DEVICE_SET/patches" ] || [ -f "$REPO_ROOT/patches/$DEVICE_SET/source-files.map" ]; }; then
    apply_set "$REPO_ROOT/patches/$DEVICE_SET" "device-specific: $DEVICE_SET"
else
    echo "No device-specific patches for '${DEVICE:-unknown}'."
    echo "(see patches/<device>/README.md)"
    echo ""
fi

echo "========================================"
echo "Done. Source changes applied."
echo "========================================"
