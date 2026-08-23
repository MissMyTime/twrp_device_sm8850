#!/system/bin/sh

# K100PM/songyuan boot-time security initialization. All TA files are read
# directly from this phone's active-slot modem partition; no key or firmware
# payload is carried in the recovery ramdisk.
LOG=/tmp/recovery.log

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

setprop twrp.recovery.skip_default_fbe_password 1
setprop twrp.songyuan.security_ready 0
setprop twrp.songyuan.security_error ""
setprop twrp.songyuan.security_start_started 1

wait_prop twrp.songyuan.modules_ready 1 30 || fail_start modules_not_ready
wait_prop init.svc.vendor.qseecomd running 30 || fail_start qseecomd_not_running
wait_path /dev/smcinvoke 20 || fail_start smcinvoke_missing
wait_vendor_ramdisk 30 || fail_start vendor_partition_still_mounted

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
sleep 2

start se_omapi
wait_prop init.svc.se_omapi running 30 || fail_start se_omapi_not_running
sleep 1

# K100PM's Xiaomi auth-secret service is lazy/oneshot; it can exit after
# publishing its AIDL interfaces and is not used as a readiness latch.
start miweaver_hal_service
sleep 1

start weaver_hal_service
wait_prop init.svc.weaver_hal_service running 30 || fail_start weaver_not_running
sleep 2
[ "$(getprop init.svc.weaver_hal_service)" = running ] || fail_start weaver_not_stable

# Only the main recovery process may attempt the no-lockscreen credential, and
# only after the complete stock K100PM security chain is stable.
setprop twrp.recovery.skip_default_fbe_password 0
setprop twrp.songyuan.security_ready 1
setprop twrp.songyuan.security_error ""
log_msg "stock K100PM security chain ready from ${modem}"
exit 0
