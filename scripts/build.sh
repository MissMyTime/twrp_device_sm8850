#!/bin/bash
# scripts/build.sh
# Unified build script for SM8850 devices
# Usage: ./scripts/build.sh <codename> [vendor]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
CODENAME="${1:-}"
VENDOR="${2:-}"
TWRP_SOURCE="${TWRP_SOURCE:-$(pwd)}"
if [ -n "${LUNCH_TARGET:-}" ]; then
    LUNCH_TARGET="$LUNCH_TARGET"
else
    LUNCH_TARGET="twrp_${CODENAME}-bp2a-eng"
fi

if [ -z "$CODENAME" ]; then
    echo "Usage: ./scripts/build.sh <codename> [vendor]"
    echo ""
    echo "Supported devices:"
    ls -1 "$REPO_ROOT/device"/*/* 2>/dev/null | while read -r line; do
        if [ -d "$line" ]; then
            v=$(basename "$(dirname "$line")")
            c=$(basename "$line")
            echo "  $c (vendor: $v)"
        fi
    done
    echo ""
    echo "Example: ./scripts/build.sh RE6402L1 realme"
    exit 1
fi

# Auto-detect vendor if not provided
if [ -z "$VENDOR" ]; then
    for vdir in "$REPO_ROOT"/device/*/; do
        v=$(basename "$vdir")
        if [ -d "$REPO_ROOT/device/$v/$CODENAME" ]; then
            VENDOR="$v"
            break
        fi
    done
fi

if [ -z "$VENDOR" ] || [ ! -d "$REPO_ROOT/device/$VENDOR/$CODENAME" ]; then
    echo "Error: Device '$CODENAME' not found."
    exit 1
fi

DEVICE_PATH="$REPO_ROOT/device/$VENDOR/$CODENAME"
if [ ! -f "$TWRP_SOURCE/build/envsetup.sh" ]; then
    echo "Error: '$TWRP_SOURCE' is not a TWRP source root."
    echo "Run this script from the TWRP source root or set TWRP_SOURCE."
    exit 1
fi

TWRP_SOURCE="$(cd "$TWRP_SOURCE" && pwd)"
DEVICE_PATH="$(cd "$DEVICE_PATH" && pwd)"
TARGET_DEVICE_PATH="$TWRP_SOURCE/device/$VENDOR/$CODENAME"

echo "========================================"
echo "Building TWRP for: $CODENAME"
echo "Vendor: $VENDOR"
echo "Device path: $DEVICE_PATH"
echo "TWRP source: $TWRP_SOURCE"
echo "Lunch target: $LUNCH_TARGET"
echo "========================================"
echo ""

# Install the selected tree at the path expected by Android's product loader.
if [ "$DEVICE_PATH" != "$TARGET_DEVICE_PATH" ]; then
    echo "Syncing device tree to: $TARGET_DEVICE_PATH"
    mkdir -p "$TARGET_DEVICE_PATH"
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Error: rsync is required to synchronize the device tree exactly."
        exit 1
    fi
    rsync -a --delete "$DEVICE_PATH/" "$TARGET_DEVICE_PATH/"
    echo ""
fi

# Apply source changes
"$SCRIPT_DIR/apply-patches.sh" "$TWRP_SOURCE" "$CODENAME"

if [ "$CODENAME" = "myron" ]; then
    if find "$REPO_ROOT/patches/myron/files/system/vold" -type f -print -quit 2>/dev/null | grep -q .; then
        echo "Error: Myron must not replace complete system/vold source files."
        exit 1
    fi

    if grep -q 'setRecoveryKeyMintEnvironment\|usePersistentKeystoreDatabase\|MS_BIND' \
            "$TWRP_SOURCE/system/vold/Decrypt.cpp" \
            "$TWRP_SOURCE/system/vold/KeyStorage.cpp"; then
        echo "Error: Myron contains an unapproved KeyMint or persistent-keystore override."
        exit 1
    fi

    grep -q 'setprop sys.usb.config twrp_mtp_adb' \
        "$TWRP_SOURCE/bootable/recovery/partitionmanager.cpp" || {
        echo "Error: Myron MTP/ADB composite configuration is missing."
        exit 1
    }
fi

# Build
cd "$TWRP_SOURCE"
source build/envsetup.sh
lunch "$LUNCH_TARGET"
m recoveryimage

BUILD_OUT="${OUT_DIR:-$TWRP_SOURCE/out}"
case "$BUILD_OUT" in
    /*) ;;
    *) BUILD_OUT="$TWRP_SOURCE/$BUILD_OUT" ;;
esac
PRODUCT_OUT="$BUILD_OUT/target/product/$CODENAME"
RECOVERY_ROOT="$PRODUCT_OUT/recovery/root"
RECOVERY_INIT="$RECOVERY_ROOT/system/etc/init/hw/init.rc"
if [ ! -s "$RECOVERY_INIT" ]; then
    echo "Error: recovery image is missing /system/etc/init/hw/init.rc."
    exit 1
fi
if ! cmp -s "$TWRP_SOURCE/bootable/recovery/etc/init.rc" "$RECOVERY_INIT"; then
    echo "Error: installed recovery init.rc does not match the TWRP source file."
    exit 1
fi

if [ "$CODENAME" = "myron" ]; then
    RECOVERY_PROP="$RECOVERY_ROOT/prop.default"
    RECOVERY_IMAGE="$PRODUCT_OUT/recovery.img"
    check_prop() {
        local name="$1"
        local value="$2"
        grep -qx "$name=$value" "$RECOVERY_PROP" || {
            echo "Error: recovery property mismatch: expected $name=$value"
            exit 1
        }
    }

    check_prop ro.build.version.release 99.87.36
    check_prop ro.build.version.security_patch 2099-12-31
    check_prop ro.vendor.build.security_patch 2099-12-31

    AVBTOOL="$BUILD_OUT/host/linux-x86/bin/avbtool"
    [ -x "$AVBTOOL" ] || AVBTOOL="$(command -v avbtool || true)"
    if [ -z "$AVBTOOL" ]; then
        echo "Error: avbtool is unavailable; recovery rollback index was not verified."
        exit 1
    fi
    "$AVBTOOL" info_image --image "$RECOVERY_IMAGE" | \
        grep -Eq 'Rollback Index:[[:space:]]+0$' || {
        echo "Error: recovery AVB rollback index is not the verified 0."
        exit 1
    }
fi

echo ""
echo "========================================"
echo "Build complete."
echo "Output: $PRODUCT_OUT/recovery.img"
echo "========================================"
