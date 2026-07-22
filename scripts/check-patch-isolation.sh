#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

assert_no_match() {
    local pattern="$1"
    shift
    if grep -RIniE -- "$pattern" "$@"; then
        fail "unexpected device-specific content found"
    fi
}

assert_no_match_outside_stock_matrix() {
    local pattern="$1"
    shift
    if grep -RIniE --exclude='compatibility_matrix.device.xml' -- "$pattern" "$@"; then
        fail "unexpected device-specific content found"
    fi
}

assert_no_match \
    'neo8|nezha|RE6402L1|RMX8899|Goodix|OPlus|realme|ColorOS|ST54|SELog|Thales|vendor\.weaver_tms' \
    "$REPO_ROOT/patches/common/files" "$REPO_ROOT/patches/common/patches"

assert_no_match \
    'neo8|RE6402L1|RMX8899|OPlus|realme|ColorOS|vendor\.weaver_tms' \
    "$REPO_ROOT/patches/nezha/files" "$REPO_ROOT/patches/nezha/patches"

assert_no_match \
    'nezha|Goodix|ST54|SELog|Thales' \
    "$REPO_ROOT/patches/neo8/files" "$REPO_ROOT/patches/neo8/patches"

assert_no_match_outside_stock_matrix \
    'annibale|neo8|nezha|RE6402L1|RMX8899|nezha-goodix|secure_element-service-goodix|weaver-service-goodix|libese_weaver_goodix|vendor\.goodix\.hardware\.secure_element|OPlus|realme|ColorOS|vendor\.weaver_tms' \
    "$REPO_ROOT/device/xiaomi/myron"

assert_no_match_outside_stock_matrix \
    'myron|neo8|nezha|RE6402L1|RMX8899|nezha-goodix|secure_element-service-goodix|weaver-service-goodix|libese_weaver_goodix|vendor\.goodix\.hardware\.secure_element|OPlus|realme|ColorOS|vendor\.weaver_tms' \
    "$REPO_ROOT/device/xiaomi/annibale"

for file in \
    etc/init.rc \
    etc/init.recovery.logd.rc \
    gui/Android.bp \
    minuitwrp/graphics_drm.cpp; do
    [ ! -e "$REPO_ROOT/patches/common/files/bootable/recovery/$file" ] || \
        fail "$file must not be stored in the common set"
    [ -f "$REPO_ROOT/patches/neo8/files/bootable/recovery/$file" ] || \
        fail "$file is missing from the Neo8 set"
done

[ -f "$REPO_ROOT/patches/common/files/bootable/recovery/partitions.hpp" ] || \
    fail "common partitions.hpp is required by the shared partition interfaces"

for hook in twrp-pre-decrypt.sh twrp-decrypt-retry.sh twrp-reboot-cleanup.sh; do
    [ -f "$REPO_ROOT/device/xiaomi/nezha/recovery/root/system/bin/$hook" ] || \
        fail "missing nezha hook: $hook"
done

grep -q 'setRecoveryKeyMintEnvironment' \
    "$REPO_ROOT/patches/common/files/bootable/recovery/partitionmanager.cpp" || \
    fail "common KeyMint extension point is missing"
for set_name in neo8 nezha; do
    grep -q 'bool setRecoveryKeyMintEnvironment(bool stock_environment)' \
        "$REPO_ROOT/patches/$set_name/files/system/vold/Decrypt.cpp" || \
        fail "$set_name KeyMint implementation is missing"
done

# The KeyMint override channel must use the shared twrp.keymint.* namespace
# on both the setter (device scripts) and reader (vold Decrypt.cpp) sides.
assert_no_match \
    'twrp\.neo8\.(osver|ospatch|venpatch)|twrp\.nezha\.keymint\.' \
    "$REPO_ROOT/device" "$REPO_ROOT/patches"
for prop in osver ospatch venpatch; do
    grep -q "twrp.keymint.$prop" \
        "$REPO_ROOT/device/realme/RE6402L1/prebuilt/vendor/bin/prepdecrypt.sh" || \
        fail "neo8 prepdecrypt KeyMint override channel is broken"
done

for set_name in annibale myron; do
    [ ! -e "$REPO_ROOT/patches/$set_name/files/system/vold/Decrypt.cpp" ] || \
        fail "$set_name must use stock Decrypt.cpp"
    [ ! -e "$REPO_ROOT/patches/$set_name/files/system/vold/KeyStorage.cpp" ] || \
        fail "$set_name must use stock KeyStorage.cpp"
    if [ "$set_name" = "annibale" ] || [ "$set_name" = "myron" ]; then
        if [ -d "$REPO_ROOT/patches/$set_name/patches/system_vold" ] && \
            find "$REPO_ROOT/patches/$set_name/patches/system_vold" -type f -print -quit | grep -q .; then
            fail "$set_name must not carry private system/vold patches"
        fi
    fi
done

assert_no_match \
    'setRecoveryKeyMintEnvironment|usePersistentKeystoreDatabase|MS_BIND' \
    "$REPO_ROOT/patches/myron" "$REPO_ROOT/device/xiaomi/myron"

grep -q 'setprop ctl.start adbd' \
    "$REPO_ROOT/patches/common/files/bootable/recovery/partitionmanager.cpp" || \
    fail "common MTP/ADB startup is missing"
if grep -q 'setprop sys.usb.config twrp_mtp_adb' \
        "$REPO_ROOT/patches/common/files/bootable/recovery/partitionmanager.cpp"; then
    fail "Myron MTP configuration must not be stored in the common set"
fi
grep -q 'setprop sys.usb.config twrp_mtp_adb' \
    "$REPO_ROOT/patches/myron/patches/bootable_recovery/mtp_composite.patch" || \
    fail "Myron MTP composite override is missing"
[ ! -e "$REPO_ROOT/patches/neo8/patches/bootable_recovery/mtp_composite.patch" ] || \
    fail "Neo8 must use the standard common MTP path"

for file in \
    prebuilt/odm/bin/hw/android.hardware.weaver-service.thales \
    prebuilt/vendor_dlkm/lib/modules/stm_st54se_gpio.ko \
    recovery/root/sbin/android.hardware.weaver-service-thales-recovery; do
    [ -s "$REPO_ROOT/device/xiaomi/nezha/$file" ] || \
        fail "missing Nezha July 15 fix file: $file"
done

grep -q 'normal_590' "$REPO_ROOT/device/xiaomi/nezha/recovery/root/system/bin/nezha-goodix-gate.sh" || \
    fail "Nezha normal route is missing"
grep -q 'leica_597' "$REPO_ROOT/device/xiaomi/nezha/recovery/root/system/bin/nezha-goodix-gate.sh" || \
    fail "Nezha Leica route is missing"
grep -q 'Recovery must never persist a KeyMint-upgraded blob' \
    "$REPO_ROOT/patches/nezha/files/system/vold/KeyStorage.cpp" || \
    fail "Nezha key-upgrade write-back protection is missing"

for device in myron annibale; do
    prop="$REPO_ROOT/device/xiaomi/$device/system.prop"
    if grep -nE '^(twrp\.recovery\.|twrp\.keymint\.)' "$prop"; then
        fail "$device must not opt into another device's recovery behavior"
    fi
done

while IFS= read -r patch; do
    git apply --numstat "$patch" >/dev/null
done < <(find "$REPO_ROOT/patches" -type f -name '*.patch' -print)

if grep -nE 'LOCAL_MODULE[[:space:]]*:=[[:space:]]*recovery-(persist|refresh)' \
        "$REPO_ROOT/patches/common/files/bootable/recovery/Android.mk"; then
    fail "recovery-persist/recovery-refresh must remain owned by Android 16 Soong"
fi

# Myron follows the verified 2026-06-15 release-image configuration:
# 99.87.36 / 2099-12-31 header and build props, no rollback index override.
grep -q '^BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 99.87.36$' \
    "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk" || \
    fail "Myron recovery header os_version is not the verified 99.87.36"
grep -q '^BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_patch_level 2099-12-31$' \
    "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk" || \
    fail "Myron recovery header os_patch_level is not the verified 2099-12-31"
grep -q '^BOARD_RECOVERY_BUILD_PROP_VERSION_RELEASE := 99.87.36$' \
    "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk" || \
    fail "Myron recovery build version release is not the verified 99.87.36"
grep -q '^BOARD_RECOVERY_BUILD_PROP_SECURITY_PATCH := 2099-12-31$' \
    "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk" || \
    fail "Myron recovery build security patch is not the verified 2099-12-31"
grep -q '^VENDOR_SECURITY_PATCH := 2099-12-31$' \
    "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk" || \
    fail "Myron vendor security patch is not the verified 2099-12-31"
if grep -qE '^BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS \+= --rollback_index' \
        "$REPO_ROOT/device/xiaomi/myron/BoardConfig.mk"; then
    fail "Myron recovery must not pin a rollback index (verified image uses 0)"
fi
[ ! -d "$REPO_ROOT/device/xiaomi/myron/release" ] || \
    fail "Myron must not carry release flag overrides"

grep -q 'name: "init_recovery.rc"' \
    "$REPO_ROOT/patches/common/files/bootable/recovery/etc/Android.bp" || \
    fail "Android 16 recovery init.rc install rule is missing"

if grep -RniE 'recovery_ab|^[[:space:]]*fastboot[[:space:]]+(flash[[:space:]]+recovery[[:space:]]|boot[[:space:]]+recovery\.img)' \
        "$REPO_ROOT" --include='*.md' --include='*.sh' \
        --exclude='check-patch-isolation.sh' \
        --exclude-dir=.git; then
    fail "invalid or non-slotted recovery flashing instructions found"
fi

bash -n "$REPO_ROOT/scripts/apply-patches.sh"
bash -n "$REPO_ROOT/scripts/build.sh"
find "$REPO_ROOT/device" "$REPO_ROOT/scripts" -type f -name '*.sh' -print0 | \
    xargs -0 -r -n1 bash -n

echo "Patch isolation checks passed."
