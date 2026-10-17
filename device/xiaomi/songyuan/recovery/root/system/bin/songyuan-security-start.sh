#!/system/bin/sh

# K100PM/songyuan boot-time security initialization. All TA files are read
# directly from this phone's active-slot modem partition; no key or firmware
# payload is carried in the recovery ramdisk.
#
# Android 17 decryption support (ported from the vendor implementation):
#   vendor.keymint is started by init.recovery.qcom.rc during 'on fs', long
#   before this script runs, so it inherits the Android 16 build properties
#   baked into this recovery. KeyMint then believes the OS is older than the
#   installed one and asks for a key upgrade. songyuan's vold KeyStorage.cpp
#   deliberately refuses every upgraded blob ("Refusing KeyMint-upgraded blob
#   ... recovery decryption is aborted and the original remains unchanged"),
#   so the upgrade path can only ever end in a failed decrypt.
#
#   The fix is to never let KeyMint ask for that upgrade: read the real
#   properties from the current-slot system, publish them, then restart
#   KeyMint and Keystore2 once so they run with the installed OS environment.
#   The refusal in KeyStorage stays untouched -- it is the guard that keeps an
#   upgraded blob from ever being written back over the original.
LOG=/tmp/recovery.log

# songyuan bakes real Android 16 patch levels (2026-07-01 / 2026-08-01) instead
# of the legacy 2099-12-31 placeholders. KeyMint compares BOTH the OS release and
# the patch levels against the key blob, so pinning only the release is not
# enough here: the stale patch level still triggers the upgrade request.
# Set to 0 to reproduce the legacy behaviour (release only).
SONGYUAN_PIN_SECURITY_PATCH=1

BAKED_PLATFORM_PATCH="$(getprop ro.build.version.security_patch)"
BAKED_VENDOR_PATCH="$(getprop ro.vendor.build.security_patch)"

# Arm the volume-key forwarding for this session.  TWRP only writes
# /tmp/twrp-ak3-volkey while this marker exists, so forwarding stays
# selective; ordinary installers can poll the file without patching.
echo 1 > /tmp/twrp-ak3-volkey-arm 2>/dev/null || true

log_msg() {
    echo "songyuan-security-start: $1" >> "$LOG"
    log -t songyuan_security_start "$1" 2>/dev/null || true
}

fail_start() {
setprop twrp.recovery.skip_default_fbe_password 1
    setprop twrp.songyuan.security_ready 0
    setprop twrp.songyuan.security_error "$1"
    log_msg "$1"
    exit 1
}

# --- firmware sysfs fallback -------------------------------------------------
# IPA requests ipa_fws.mdt during early boot.  Without the sysfs fallback the
# driver retries every 512 ms for the whole boot window because the kernel only
# looks in /lib/firmware (firmware_class.path is empty).  The write in
# init.recovery.qcom.rc does not work: init is denied by SELinux
#   scontext=u:r:init:s0 tcontext=u:object_r:proc:s0 permissive=0
# so the flag stayed 0.  Verified on device: flipping it here makes ueventd load
# the firmware through /vendor/firmware_mnt/image and the retry loop stops
# ("IPA FW loaded successfully" / "IPA driver initialization was successful").
# Set it early and retry once on the next pass; never fail the security chain.
set_firmware_fallback() {
    fw=/proc/sys/kernel/firmware_config/force_sysfs_fallback
    [ -e "$fw" ] || return 0
    if echo 1 > "$fw" 2>/dev/null; then
        setprop twrp.songyuan.firmware_fallback "$(cat "$fw" 2>/dev/null)"
        return 0
    fi
    setprop twrp.songyuan.firmware_fallback failed
    return 0
}
set_firmware_fallback

# Bounded readiness wait used in place of fixed sleeps. Returns 0 as soon as the
# service reports running, and also returns 0 on timeout so callers proceed exactly
# as the previous unconditional `sleep` did. Keeps the startup ORDER unchanged.
wait_settle() {
    name="$1"
    limit="$2"
    i=0
    while [ "$i" -lt "$limit" ]; do
        [ "$(getprop "init.svc.$name")" = "running" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 0
}

wait_prop() {
    prop="$1"
    expected="$2"
    limit="$3"
    i=0
    while [ "$i" -lt "$limit" ]; do
        [ "$(getprop "$prop")" = "$expected" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

wait_path() {
    path="$1"
    limit="$2"
    i=0
    while [ "$i" -lt "$limit" ]; do
        [ -e "$path" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

wait_stopped() {
    name="$1"
    limit="$2"
    i=0
    while [ "$i" -lt "$limit" ]; do
        state="$(getprop "init.svc.$name")"
        if [ -z "$state" ] || [ "$state" = "stopped" ]; then
            return 0
        fi
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}

wait_vendor_ramdisk() {
    limit="$1"
    i=0
    while [ "$i" -lt "$limit" ]; do
        # TWRP temporarily mounts the active logical vendor partition while it
        # reads fstab/VINTF data.  Starting the security chain before that
        # mount is released hides the recovery copies of libEseUtils and the
        # wrapper scripts.  Mounting firmware below it also makes the later
        # unmount fail with EBUSY.  Wait for the ramdisk vendor tree instead.
        grep -q ' /vendor ' /proc/mounts || return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# Read one property from the installed system of the current slot. $1 is the
# property name, $2 the mount point, $3 the block device being mounted.
read_installed_property() {
    prop="$1"
    mount_point="$2"
    block="$3"
    value=""

    for prop_file in /system_root/system/build.prop /system_root/build.prop; do
        [ -r "$prop_file" ] || continue
        value="$(sed -n "s/^${prop}=//p" "$prop_file" | head -n 1)"
        [ -n "$value" ] && { echo "$value"; return 0; }
    done

    [ -b "$block" ] || return 1
    mkdir -p "$mount_point" || return 1
    if mount -t erofs -o ro "$block" "$mount_point" 2>/dev/null; then
        for prop_file in "$mount_point/system/build.prop" "$mount_point/build.prop"; do
            [ -r "$prop_file" ] || continue
            value="$(sed -n "s/^${prop}=//p" "$prop_file" | head -n 1)"
            [ -n "$value" ] && break
        done
        umount "$mount_point" 2>/dev/null || true
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    return 1
}

# Publish the installed OS environment before any decrypt request reaches
# KeyMint. Only the current-slot system is read; nothing is imported from
# another device and no key blob is ever written back.
pin_installed_keymint_environment() {
    km_slot="$(getprop ro.boot.slot_suffix)"
    case "$km_slot" in
        _a|_b) ;;
        a|b) km_slot="_$km_slot" ;;
        *) km_slot="" ;;
    esac

    mount_point=/mnt/songyuan_keymint_system
    release=""
    platform_patch=""
    i=0

    while [ "$i" -lt 50 ]; do
        for block in \
            "/dev/block/mapper/system${km_slot}" \
            /dev/block/mapper/system \
            "/dev/block/by-name/system${km_slot}"; do
            release="$(read_installed_property ro.build.version.release "$mount_point" "$block")"
            case "$release" in
                16|17) break 2 ;;
                *) release="" ;;
            esac
        done
        sleep 0.1
        i=$((i + 1))
    done

    case "$release" in
        16|17)
            /system/bin/resetprop ro.build.version.release "$release"
            /system/bin/resetprop ro.build.version.release_or_codename "$release"
            setprop twrp.songyuan.installed_android_release "$release"
            log_msg "KeyMint environment uses installed Android $release"
            ;;
        *)
            setprop twrp.songyuan.keymint_error installed_android_release_unavailable
            log_msg "installed Android release unavailable; refusing to guess"
            return 1
            ;;
    esac

    if [ "$SONGYUAN_PIN_SECURITY_PATCH" != "1" ]; then
        return 0
    fi

    i=0
    while [ "$i" -lt 50 ] && [ -z "$platform_patch" ]; do
        for block in \
            "/dev/block/mapper/system${km_slot}" \
            /dev/block/mapper/system \
            "/dev/block/by-name/system${km_slot}"; do
            platform_patch="$(read_installed_property ro.build.version.security_patch "$mount_point" "$block")"
            [ -n "$platform_patch" ] && break 2
        done
        sleep 0.1
        i=$((i + 1))
    done

    if [ -n "$platform_patch" ]; then
        /system/bin/resetprop ro.build.version.security_patch "$platform_patch"
        setprop twrp.songyuan.installed_security_patch "$platform_patch"
        log_msg "KeyMint environment uses installed platform patch $platform_patch"
    else
        log_msg "installed platform patch unavailable; keeping the baked value"
    fi

    # The vendor patch level is owned by TWRP's property override, which reads
    # /vendor/build.prop before this script runs. Recovery measured it as
    # 2026-09-01 on Android 17, i.e. the installed value, so there is nothing
    # to wait for here. Do not block on it: TWRP reaches
    # fscrypt_mount_metadata_encrypted()/read_key() while this script is still
    # running, and every extra second here is a second in which recovery talks
    # to a KeyMint that has not been refreshed yet.
    log_msg "KeyMint patches ready: platform=$(getprop ro.build.version.security_patch) vendor=$(getprop ro.vendor.build.security_patch)"
    return 0
}

restart_keymint_environment() {
    release="$(getprop twrp.songyuan.installed_android_release)"
    if [ -z "$release" ]; then
        log_msg "KeyMint restart skipped: installed Android release unavailable"
        return 1
    fi

    # KeyMint is started by the vendor rc during 'on fs', before this script has
    # published the installed OS properties. Stop it before any decrypt request,
    # then start KeyMint and Keystore2 once with the installed environment.
    stop keystore2
    stop vendor.keymint

    if ! wait_stopped keystore2 50; then
        setprop twrp.songyuan.keymint_error keystore2_stop_timeout
        log_msg "keystore2 did not stop before KeyMint restart"
    fi
    if ! wait_stopped vendor.keymint 50; then
        setprop twrp.songyuan.keymint_error keymint_stop_timeout
        log_msg "vendor.keymint did not stop before environment refresh"
    fi

    start vendor.keymint
    if ! wait_prop init.svc.vendor.keymint running 10; then
        setprop twrp.songyuan.keymint_error keymint_restart_failed
        log_msg "vendor.keymint failed to restart"
        start keystore2
        return 1
    fi

    start keystore2
    if ! wait_prop init.svc.keystore2 running 10; then
        setprop twrp.songyuan.keymint_error keystore2_restart_failed
        log_msg "keystore2 failed to restart"
        return 1
    fi

    setprop twrp.songyuan.keymint_env_ready 1
    log_msg "KeyMint and Keystore2 restarted with installed Android $release"
    return 0
}

# A second start must never tear down a KeyMint that TWRP is already using:
# recovery calls read_key() synchronously and a restart underneath it never
# returns. Leave the chain untouched once it has been brought up.
if [ "$(getprop twrp.songyuan.security_ready)" = "1" ]; then
    log_msg "security chain already ready; leaving KeyMint untouched"
    exit 0
fi

setprop twrp.recovery.skip_default_fbe_password 1
setprop twrp.songyuan.security_ready 0
setprop twrp.songyuan.security_error ""
setprop twrp.songyuan.security_start_started 1
setprop twrp.songyuan.keymint_error ""

wait_prop twrp.songyuan.modules_ready 1 30 || fail_start modules_not_ready
wait_prop init.svc.vendor.qseecomd running 30 || fail_start qseecomd_not_running
wait_path /dev/smcinvoke 20 || fail_start smcinvoke_missing
wait_vendor_ramdisk 30 || fail_start vendor_partition_still_mounted

# Refresh the KeyMint identity before the Thales chain is brought up so no
# decrypt attempt can reach a KeyMint that still believes it runs Android 16.
pin_installed_keymint_environment
restart_keymint_environment

slot="$(getprop ro.boot.slot_suffix)"
case "$slot" in
    _a|_b) ;;
    a|b) slot="_$slot" ;;
    *) fail_start invalid_slot_suffix ;;
esac

modem="/dev/block/bootdevice/by-name/modem${slot}"
wait_path "$modem" 20 || fail_start active_modem_partition_missing

mkdir -p /vendor/firmware_mnt /firmware || fail_start firmware_mountpoint_create_failed
if ! grep -q ' /vendor/firmware_mnt ' /proc/mounts; then
    # TA payloads remain read-only, but the system-owned Secure Element HAL
    # must be able to traverse and read the active modem firmware filesystem.
    mount -t vfat -o ro,uid=1000,gid=1000,fmask=0022,dmask=0022 "$modem" /vendor/firmware_mnt || fail_start modem_mount_failed
fi
firmware_mount="$(grep ' /vendor/firmware_mnt ' /proc/mounts | head -n 1)"
echo "$firmware_mount" | grep -q 'uid=1000' || fail_start modem_mount_wrong_uid
echo "$firmware_mount" | grep -q 'gid=1000' || fail_start modem_mount_wrong_gid
echo "$firmware_mount" | grep -q 'fmask=0022' || fail_start modem_mount_wrong_fmask
echo "$firmware_mount" | grep -q 'dmask=0022' || fail_start modem_mount_wrong_dmask
if ! grep -q ' /firmware ' /proc/mounts; then
    mount -o bind /vendor/firmware_mnt /firmware || fail_start firmware_bind_failed
fi

# These are the two eSE/GPQeSE UUID payloads shipped by K100PM modem firmware.
# Validate the complete split image before any security service is started.
for ta in FD719D50-FFFB-11EB-9A03-0242AC130003 32552B22-89FE-42B4-8A45-A0C4E2DB0326; do
    for ext in b00 b01 b02 b03 b04 b05 b06 b07 b08 mdt; do
        [ -r "/vendor/firmware_mnt/image/${ta}.${ext}" ] || fail_start "official_ta_${ta}_${ext}_missing"
    done
done

if wait_path /dev/qsee_ipc_irq_spss 20; then
    chown system:drmrpc /dev/qsee_ipc_irq_spss 2>/dev/null || true
    chmod 0660 /dev/qsee_ipc_irq_spss 2>/dev/null || true
fi

stop vendor.keymint-strongbox
stop weaver_hal_service
stop miweaver_hal_service
stop se_omapi
stop vendor.secure_element
stop vendor.gatekeeper_default

start vendor.gatekeeper_default
wait_prop init.svc.vendor.gatekeeper_default running 30 || fail_start vendor_gatekeeper_not_running

start vendor.secure_element
wait_prop init.svc.vendor.secure_element running 30 || fail_start vendor_secure_element_not_running
wait_settle vendor.secure_element 3

start se_omapi
wait_prop init.svc.se_omapi running 30 || fail_start se_omapi_not_running
wait_settle se_omapi 2

# K100PM's Xiaomi auth-secret service is lazy/oneshot; it can exit after
# publishing its AIDL interfaces and is not used as a readiness latch.
start miweaver_hal_service
wait_settle miweaver_hal_service 2

start weaver_hal_service
wait_prop init.svc.weaver_hal_service running 30 || fail_start weaver_not_running
wait_settle weaver_hal_service 3
[ "$(getprop init.svc.weaver_hal_service)" = running ] || fail_start weaver_not_stable



# Only the main recovery process may attempt the no-lockscreen credential, and
# only after the complete stock K100PM security chain is stable.
setprop twrp.recovery.skip_default_fbe_password 0
setprop twrp.songyuan.security_ready 1
setprop twrp.songyuan.security_error ""
log_msg "stock K100PM security chain ready from ${modem}"
exit 0
