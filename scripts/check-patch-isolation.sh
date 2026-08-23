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
    if grep -RIniE \
            --exclude='compatibility_matrix.device.xml' \
            --exclude='README.md' \
            -- "$pattern" "$@"; then
        fail "unexpected device-specific content found"
    fi
}

assert_no_match \
    'songyuan|K100PM|neo8|nezha|RE6402L1|RMX8899|Goodix|OPlus|realme|ColorOS|ST54|SELog|Thales|vendor\.weaver_tms' \
    "$REPO_ROOT/patches/common/files" "$REPO_ROOT/patches/common/patches"

assert_no_match \
    'neo8|nezha|RE6402L1|RMX8899|Goodix|OPlus|realme|ColorOS|vendor\.weaver_tms|twrp\.keymint\.' \
    "$REPO_ROOT/patches/songyuan/files"

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

assert_no_match_outside_stock_matrix \
    'annibale|myron|neo8|nezha|RE6402L1|RMX8899|nezha-goodix|secure_element-service-goodix|weaver-service-goodix|libese_weaver_goodix|vendor\.goodix\.hardware\.secure_element|OPlus|realme|ColorOS|vendor\.weaver_tms|twrp\.keymint\.' \
    "$REPO_ROOT/device/xiaomi/songyuan"

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

for source_file in Decrypt.cpp KeyStorage.cpp Weaver1.cpp; do
    [ -s "$REPO_ROOT/patches/songyuan/files/system/vold/$source_file" ] || \
        fail "Songyuan security source is missing: $source_file"
done
grep -q 'Refusing KeyMint-upgraded blob' \
    "$REPO_ROOT/patches/songyuan/files/system/vold/KeyStorage.cpp" || \
    fail "Songyuan KeyMint upgrade-write protection is missing"
grep -q 'songyuan_mtp_adb' \
    "$REPO_ROOT/patches/songyuan/files/bootable/recovery/partitionmanager.cpp" || \
    fail "Songyuan MTP/ADB composite mode is missing"
grep -q 'MTP background worker: starting after the current action completed' \
    "$REPO_ROOT/patches/songyuan/files/bootable/recovery/gui/action.cpp" || \
    fail "Songyuan post-decrypt MTP race fix is missing"

for other_set in neo8 nezha; do
    for source_file in Decrypt.cpp KeyStorage.cpp; do
        if cmp -s \
                "$REPO_ROOT/patches/songyuan/files/system/vold/$source_file" \
                "$REPO_ROOT/patches/$other_set/files/system/vold/$source_file"; then
            fail "Songyuan must not reuse $other_set $source_file"
        fi
    done
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
    'setRecoveryKeyMintEnvironment|usePersistentKeystoreDatabase|MS_BIND|spblob-rescue|metadata_key_rescue' \
    "$REPO_ROOT/patches/myron" "$REPO_ROOT/device/xiaomi/myron"

myron_evox_patch="$REPO_ROOT/patches/myron/patches/system_extras/evox_android17_fscrypt_policy.patch"
[ -f "$myron_evox_patch" ] || \
    fail "Myron Evolution X 17 fscrypt compatibility patch is missing"
grep -q 'IsEvolutionXAndroid17' "$myron_evox_patch" || \
    fail "Myron Evolution X 17 fingerprint gate is missing"
grep -q 'ExistingPolicyMatches' "$myron_evox_patch" || \
    fail "Myron existing fscrypt policy verification is missing"
grep -q 'memcmp(&current.policy.v2, &expected, sizeof(expected)) == 0' "$myron_evox_patch" || \
    fail "Myron fscrypt v2 policy must be compared byte for byte"
assert_no_match \
    'fscrypt_prepare_user_storage|Keeping the existing unlocked media directory' \
    "$REPO_ROOT/patches/myron"

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
[ -f "$REPO_ROOT/patches/myron/patches/bootable_recovery/mtp_autostart_after_decrypt.patch" ] || \
    fail "Myron post-decrypt MTP startup patch is missing"
grep -q 'tw_is_decrypted' \
    "$REPO_ROOT/patches/myron/patches/bootable_recovery/mtp_autostart_after_decrypt.patch" || \
    fail "Myron MTP startup must wait for decryption"
if grep -q 'mPersist.SetValue("tw_mtp_enabled", "1")' \
        "$REPO_ROOT/patches/myron/patches/bootable_recovery/mtp_autostart_after_decrypt.patch"; then
    fail "Myron MTP startup must not overwrite the saved user preference"
fi
[ ! -e "$REPO_ROOT/patches/neo8/patches/bootable_recovery/mtp_composite.patch" ] || \
    fail "Neo8 must use the standard common MTP path"

grep -q '/system/bin/twrp-vab-format-guard.sh' \
    "$REPO_ROOT/patches/myron/patches/bootable_recovery/format_data_guard_ui.patch" || \
    fail "Myron isolated Format Data guard page is missing"
[ -x "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/twrp-vab-format-guard.sh" ] || \
    fail "Myron Format Data guard script must be executable"
grep -q 'get-snapshot-merge-status' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/twrp-vab-format-guard.sh" || \
    fail "Myron Virtual A/B snapshot check is missing"
grep -q 'snapshot state is merging; force format is forbidden' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/twrp-vab-format-guard.sh" || \
    fail "Myron merging state must never permit force format"
grep -q 'format_data_vab_force_btn' \
    "$REPO_ROOT/patches/myron/patches/bootable_recovery/format_data_guard_ui.patch" || \
    fail "Myron custom-ROM force-format confirmation is missing"

if sed -n \
        '/int TWPartitionManager::Format_Data(void)/,/int TWPartitionManager::Wipe_Media_From_Data(void)/p' \
        "$REPO_ROOT/patches/common/files/bootable/recovery/partitionmanager.cpp" | \
        grep -q 'WaitForService'; then
    fail "Format Data must not block the recovery UI waiting for BootControl"
fi

[ -s "$REPO_ROOT/patches/myron/files/bootable/recovery/gui/theme/portrait_hdpi/images/splashkoi.png" ] || \
    fail "Myron koi splash image is missing"
grep -q 'splashkoi' \
    "$REPO_ROOT/patches/myron/files/bootable/recovery/gui/theme/portrait_hdpi/splash.xml" || \
    fail "Myron koi splash resource is not referenced"

grep -q 'mount_runtime_partition vendor_dlkm' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/wifi-load-modules.sh" || \
    fail "Myron runtime WLAN module selection is missing"
grep -q 'wifi-dhcp.lease' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/wifi-dhcp.sh" || \
    fail "Myron WLAN lease publication is missing"

for helper in \
    myron-evox-mtp-keeper.sh \
    myron-evox-time-fix.sh \
    myron-reboot-fastbootd.sh \
    myron-usb-role-recover.sh; do
    [ -x "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/$helper" ] || \
        fail "Myron helper must be executable: $helper"
done
grep -q 'EvolutionX-17' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/myron-evox-time-fix.sh" || \
    fail "Myron EvoX time helper must remain fingerprint-gated"
grep -q 'EvolutionX-17' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/myron-evox-mtp-keeper.sh" || \
    fail "Myron EvoX MTP helper must remain fingerprint-gated"
grep -q 'boot-fastboot' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/system/bin/myron-reboot-fastbootd.sh" || \
    fail "Myron Fastbootd BCB request is missing"
[ -x "$REPO_ROOT/device/xiaomi/myron/recovery/root/system/bin/myron-fastbootd-block-labels.sh" ] || \
    fail "Myron Fastbootd block-label helper must be executable"
grep -q 'myron-fastbootd-block-labels.sh' \
    "$REPO_ROOT/device/xiaomi/myron/recovery/root/init.recovery.qcom.rc" || \
    fail "Myron Fastbootd block-label helper is not started"
grep -q 'pvmfw_a pvmfw_b' \
    "$REPO_ROOT/device/xiaomi/myron/recovery/root/system/bin/myron-fastbootd-block-labels.sh" || \
    fail "Myron Fastbootd pvmfw targets are missing"
grep -q '^mi_product[[:space:]].*/mi_product[[:space:]]' \
    "$REPO_ROOT/device/xiaomi/myron/recovery.fstab" || \
    fail "Myron mi_product logical partition is missing"

printf '%s  %s\n' \
    '39b6f96e4ef240066464ccf3223dd0119b2922c279a878a3af74bd79349136d8' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/vendor/lib64/libqmi_encdec.so" \
    'adbe20f901278a8a122bb12493e7a16901ece6d8afee7e2a34d24037ce12ddf9' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/vendor/lib64/libtaautoload.so" \
    'edc9bd9ac85b9cfa69607873824166173078a5da96e11e7b3ce452261b6d339d' \
    "$REPO_ROOT/device/xiaomi/myron/prebuilt/vendor/etc/ssg/ta_config.json" | \
    sha256sum -c - >/dev/null || \
    fail "Myron official QTI runtime files do not match the verified vendor image"

for file in \
    prebuilt/odm/bin/hw/android.hardware.weaver-service.thales \
    prebuilt/vendor_dlkm/lib/modules/stm_st54se_gpio.ko \
    recovery/root/sbin/android.hardware.weaver-service-thales-recovery; do
    [ -s "$REPO_ROOT/device/xiaomi/nezha/$file" ] || \
        fail "missing Nezha July 15 fix file: $file"
done

nezha_usb_rc="$REPO_ROOT/device/xiaomi/nezha/recovery/root/init.recovery.usb.rc"
if sed -n \
        '/on property:sys.usb.config=mtp,adb /,/on property:sys.usb.config=sideload /p' \
        "$nezha_usb_rc" | grep -q 'setprop sys.usb.ffs.mtp.ready 0'; then
    fail "Nezha MTP RC-only fix must preserve the FunctionFS MTP ready state"
fi
for usb_mode in mtp twrp_mtp_adb; do
    grep -A1 -F \
        "on property:sys.usb.config=$usb_mode && property:sys.usb.configfs=1" \
        "$nezha_usb_rc" | grep -q 'setprop sys.usb.config mtp,adb' || \
        fail "Nezha MTP RC-only alias is missing: $usb_mode"
done
grep -q 'property:sys.usb.ffs.ready=1 && property:sys.usb.ffs.mtp.ready=1 && property:sys.usb.config=mtp,adb' \
    "$nezha_usb_rc" || fail "Nezha MTP composite readiness check is missing"
grep -q 'write /config/usb_gadget/g1/idVendor 0x2717' "$nezha_usb_rc" || \
    fail "Nezha Xiaomi MTP vendor ID is missing"
grep -q 'write /config/usb_gadget/g1/idProduct 0xFF48' "$nezha_usb_rc" || \
    fail "Nezha Xiaomi MTP/ADB product ID is missing"

grep -q 'normal_590' "$REPO_ROOT/device/xiaomi/nezha/recovery/root/system/bin/nezha-goodix-gate.sh" || \
    fail "Nezha normal route is missing"
grep -q 'leica_597' "$REPO_ROOT/device/xiaomi/nezha/recovery/root/system/bin/nezha-goodix-gate.sh" || \
    fail "Nezha Leica route is missing"
grep -q 'Recovery must never persist a KeyMint-upgraded blob' \
    "$REPO_ROOT/patches/nezha/files/system/vold/KeyStorage.cpp" || \
    fail "Nezha key-upgrade write-back protection is missing"

myron_prop="$REPO_ROOT/device/xiaomi/myron/system.prop"
if grep -nE '^(twrp\.keymint\.|twrp\.recovery\.)' "$myron_prop" | \
        grep -v '^.*:twrp\.recovery\.post_decrypt_media_bind=1$'; then
    fail "Myron contains an unapproved recovery or KeyMint property"
fi

annibale_prop="$REPO_ROOT/device/xiaomi/annibale/system.prop"
if grep -nE '^(twrp\.recovery\.|twrp\.keymint\.)' "$annibale_prop"; then
    fail "Annibale must not opt into another device's recovery behavior"
fi

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

songyuan_board="$REPO_ROOT/device/xiaomi/songyuan/BoardConfig.mk"
grep -q '^BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 16\.0\.0$' \
    "$songyuan_board" || fail "Songyuan recovery header must use Android 16.0.0"
grep -q '^BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_patch_level 2026-07-01$' \
    "$songyuan_board" || fail "Songyuan recovery header security patch is incorrect"
grep -q '^BOARD_RECOVERY_BUILD_PROP_VERSION_RELEASE := 16$' \
    "$songyuan_board" || fail "Songyuan recovery release property is incorrect"
grep -q '^BOARD_RECOVERY_BUILD_PROP_SECURITY_PATCH := 2026-07-01$' \
    "$songyuan_board" || fail "Songyuan recovery security patch is incorrect"
grep -q '^VENDOR_SECURITY_PATCH := 2026-08-01$' \
    "$songyuan_board" || fail "Songyuan vendor security patch is incorrect"
assert_no_match \
    '99\.87\.36|2099-12-31|twrp\.keymint\.|neo8|nezha|RE6402L1' \
    "$songyuan_board" \
    "$REPO_ROOT/device/xiaomi/songyuan/system.prop" \
    "$REPO_ROOT/patches/songyuan/files"

songyuan_ota_count=$(awk '
    /^AB_OTA_PARTITIONS \+=/ { in_list = 1; next }
    in_list && /^BOARD_RECOVERY_NEEDS_BOOTLOADER_CONTROL/ { exit }
    in_list && /^[[:space:]]+[a-z0-9_-]+([[:space:]]*\\)?$/ { count++ }
    END { print count + 0 }
' "$songyuan_board")
[ "$songyuan_ota_count" -eq 58 ] || \
    fail "Songyuan OTA partition list must contain exactly 58 entries"
diff -u "$REPO_ROOT/patches/songyuan/ota-partitions.txt" <(awk '
    /^AB_OTA_PARTITIONS \+=/ { in_list = 1; next }
    in_list && /^BOARD_RECOVERY_NEEDS_BOOTLOADER_CONTROL/ { exit }
    in_list && /^[[:space:]]+[a-z0-9_-]+([[:space:]]*\\)?$/ {
        gsub(/[[:space:]\\]/, "")
        print
    }
' "$songyuan_board") >/dev/null || \
    fail "Songyuan OTA partition list does not match the verified payload manifest"
[ "$(stat -c '%s' "$REPO_ROOT/device/xiaomi/songyuan/prebuilt/odm/firmware/focaltech_ts_fw_songyuan.bin")" -eq 148712 ] || \
    fail "Songyuan touch firmware size is not the verified 148712 bytes"
grep -q '^/pvmfw[[:space:]].*/dev/block/bootdevice/by-name/pvmfw[[:space:]]' \
    "$REPO_ROOT/device/xiaomi/songyuan/prebuilt/system/etc/twrp.flags" || \
    fail "Songyuan pvmfw image target is missing"
grep -q 'songyuan_installer_compat_links' \
    "$REPO_ROOT/device/xiaomi/songyuan/device.mk" || \
    fail "Songyuan installer compatibility package is missing"
grep -q '/sbin/bas' \
    "$REPO_ROOT/device/xiaomi/songyuan/installer_compat/Android.mk" || \
    fail "Songyuan legacy bash compatibility path is missing"
grep -q 'setprop twrp.recovery.skip_default_fbe_password 0' \
    "$REPO_ROOT/device/xiaomi/songyuan/recovery/root/system/bin/songyuan-security-start.sh" || \
    fail "Songyuan no-lockscreen decrypt gate is not released after security startup"
grep -q 'setprop ctl.stop adbd' \
    "$REPO_ROOT/device/xiaomi/songyuan/recovery/root/system/bin/songyuan-usb-role-recover.sh" || \
    fail "Songyuan OTG host mode does not release FunctionFS"
[ ! -d "$REPO_ROOT/device/xiaomi/songyuan/.github" ] || \
    fail "Songyuan device tree must not carry a private release workflow"

grep -q 'name: "init_recovery.rc"' \
    "$REPO_ROOT/patches/common/files/bootable/recovery/etc/Android.bp" || \
    fail "Android 16 recovery init.rc install rule is missing"

neo8_flags="$REPO_ROOT/device/realme/RE6402L1/recovery/root/system/etc/twrp.flags"
for partition in \
    boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b \
    recovery_a recovery_b dtbo_a dtbo_b vbmeta_a vbmeta_b \
    vbmeta_system_a vbmeta_system_b vbmeta_vendor_a vbmeta_vendor_b; do
    grep -q "^/$partition[[:space:]].*/dev/block/bootdevice/by-name/$partition[[:space:]]" \
        "$neo8_flags" || \
        fail "Neo8 image target is missing: $partition"
done
if grep -qE '^/(boot|init_boot|vendor_boot|recovery|dtbo|vbmeta|vbmeta_system|vbmeta_vendor)[[:space:]]' \
        "$neo8_flags"; then
    fail "Neo8 image targets must use physical A/B partition nodes"
fi
if grep -qE '^/super[[:space:]]' "$neo8_flags"; then
    fail "Neo8 twrp.flags must not duplicate the dynamic super entry"
fi

grep -q 'property.ro.boot.slot_suffix' \
    "$REPO_ROOT/patches/neo8/patches/bootable_recovery/ui_device_overrides.patch" || \
    fail "Neo8 slot-suffix display fallback is missing"
grep -q 'property.ro.boot.slot' \
    "$REPO_ROOT/patches/neo8/patches/bootable_recovery/ui_device_overrides.patch" || \
    fail "Neo8 slot display fallback is missing"

neo8_wifi_loader="$REPO_ROOT/device/realme/RE6402L1/prebuilt/sbin/wifi-load-modules.sh"
grep -q 'chmod 0755 "$client"' "$neo8_wifi_loader" || \
    fail "Neo8 Wi-Fi HAL client mode repair is missing"
git -C "$REPO_ROOT" ls-files -s \
        device/realme/RE6402L1/prebuilt/sbin/neo8_wifi_hal_client | \
    grep -q '^100755 ' || \
    fail "Neo8 Wi-Fi HAL client must be executable in Git"

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
