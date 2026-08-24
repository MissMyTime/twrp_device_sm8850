#!/system/bin/sh
# Start NXP eSE/Weaver in the order used by the working Xiaomi 17 Pro Max TWRP.

LOG=/tmp/recovery.log

log_msg() {
    echo "myron-nxp-gate: $1" >> "$LOG"
    log -t myron_nxp_gate "$1" 2>/dev/null || true
}

wait_running() {
    name="$1"
    limit="$2"
    i=0
    while [ "$i" -lt "$limit" ]; do
        [ "$(getprop "init.svc.$name")" = "running" ] && return 0
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
        [ -z "$state" ] || [ "$state" = "stopped" ] && return 0
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}

wait_security_patch_override() {
    i=0
    while [ "$i" -lt 200 ]; do
        platform_patch="$(getprop ro.build.version.security_patch)"
        vendor_patch="$(getprop ro.vendor.build.security_patch)"
        if [ -n "$platform_patch" ] && [ "$platform_patch" != "2099-12-31" ] && \
           [ -n "$vendor_patch" ] && [ "$vendor_patch" != "2099-12-31" ]; then
            log_msg "KeyMint patches ready: platform=$platform_patch vendor=$vendor_patch"
            return 0
        fi
        sleep 0.1
        i=$((i + 1))
    done
    log_msg "security patch override timeout: platform=$platform_patch vendor=$vendor_patch"
    return 1
}

pin_installed_android_release() {
    mount_point=/mnt/myron_keymint_system
    slot="$(getprop ro.boot.slot_suffix)"
    release=""
    i=0

    mkdir -p "$mount_point"
    while [ "$i" -lt 50 ]; do
        for prop_file in \
            /system_root/system/build.prop \
            /system_root/build.prop; do
            [ -r "$prop_file" ] || continue
            release="$(sed -n 's/^ro.build.version.release=//p' "$prop_file" | head -n 1)"
            case "$release" in
                16|17) break 2 ;;
                *) release="" ;;
            esac
        done

        for block in \
            "/dev/block/mapper/system${slot}" \
            /dev/block/mapper/system \
            "/dev/block/by-name/system${slot}"; do
            [ -b "$block" ] || continue
            if mount -t erofs -o ro "$block" "$mount_point" 2>/dev/null; then
                for prop_file in \
                    "$mount_point/system/build.prop" \
                    "$mount_point/build.prop"; do
                    [ -r "$prop_file" ] || continue
                    release="$(sed -n 's/^ro.build.version.release=//p' "$prop_file" | head -n 1)"
                    case "$release" in
                        16|17) break ;;
                        *) release="" ;;
                    esac
                done
                umount "$mount_point" 2>/dev/null || true
                [ -n "$release" ] && break 2
            fi
        done

        sleep 0.1
        i=$((i + 1))
    done

    case "$release" in
        16|17)
            /system/bin/resetprop ro.build.version.release "$release"
            /system/bin/resetprop ro.build.version.release_or_codename "$release"
            setprop twrp.myron.installed_android_release "$release"
            log_msg "KeyMint environment uses installed Android $release"
            return 0
            ;;
        *)
            setprop twrp.myron.nxp_gate_error installed_android_release_unavailable
            log_msg "installed Android release unavailable; refusing to guess"
            return 1
            ;;
    esac
}

restart_keymint_environment() {
    release="$(getprop twrp.myron.installed_android_release)"
    if [ -z "$release" ]; then
        log_msg "KeyMint restart skipped: installed Android release unavailable"
        return 1
    fi

    # KeyMint is started by the vendor rc during 'on init', before recovery has
    # replaced the rollback-resistant 2099 patch properties. Stop it before any
    # decrypt request, wait for TWRP's real patch override, then start KeyMint
    # and Keystore2 once with the installed OS environment.
    stop keystore2
    stop vendor.keymint

    if ! wait_stopped keystore2 50; then
        setprop twrp.myron.nxp_gate_error keystore2_stop_timeout
        log_msg "keystore2 did not stop before KeyMint restart"
    fi
    if ! wait_stopped vendor.keymint 50; then
        setprop twrp.myron.nxp_gate_error keymint_stop_timeout
        log_msg "vendor.keymint did not stop before environment refresh"
    fi

    wait_security_patch_override || true

    start vendor.keymint
    if ! wait_running vendor.keymint 10; then
        setprop twrp.myron.nxp_gate_error keymint_restart_failed
        log_msg "vendor.keymint failed to restart"
        start keystore2
        return 1
    fi

    start keystore2
    if ! wait_running keystore2 10; then
        setprop twrp.myron.nxp_gate_error keystore2_restart_failed
        log_msg "keystore2 failed to restart"
        return 1
    fi

    setprop twrp.myron.keymint_env_ready 1
    log_msg "KeyMint and Keystore2 restarted with installed Android $release"
    return 0
}

setprop twrp.myron.nxp_gate_started 1
setprop twrp.myron.nxp_gate_error ""
setprop twrp.myron.nxp_gate_attempt 0
log_msg "start"

# Recovery is built with the rollback-resistant 99.87.36 header, but KeyMint
# must see the installed OS release. Otherwise it requests a key upgrade that
# recovery deliberately refuses to persist. Read only the current-slot system;
# never import another device's security files or write an upgraded key blob.
pin_installed_android_release
restart_keymint_environment

# Keep NXP StrongBox stopped in recovery; Weaver is enough for credential flow.
stop vendor.keymint-strongbox

start vendor.secure_element
if ! wait_running vendor.secure_element 30; then
    setprop twrp.myron.nxp_gate_error vendor_secure_element_not_running
    log_msg "vendor.secure_element not running"
    exit 0
fi

start se_omapi
if ! wait_running se_omapi 30; then
    setprop twrp.myron.nxp_gate_error se_omapi_not_running
    log_msg "se_omapi not running"
    exit 0
fi

# odm.weaver_nxp is a disabled service, so waiting before its first start only
# adds a fixed timeout. Start it as soon as its transport dependencies are up,
# then require two consecutive running samples before allowing decryption.
start odm.weaver_nxp

i=0
stable=0
while [ "$i" -lt 10 ]; do
    setprop twrp.myron.nxp_gate_attempt "$((i + 1))"
    if [ "$(getprop init.svc.odm.weaver_nxp)" = "running" ]; then
        stable=$((stable + 1))
    else
        stable=0
        start odm.weaver_nxp
    fi
    if [ "$stable" -ge 2 ]; then
        setprop twrp.myron.weaver_ready 1
        log_msg "weaver_nxp stable; strongbox kept stopped in recovery"
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done

if [ "$(getprop init.svc.odm.weaver_nxp)" != "running" ]; then
    setprop twrp.myron.nxp_gate_error weaver_nxp_not_stable
    log_msg "odm.weaver_nxp did not stay running"
    stop odm.weaver_nxp
    exit 0
fi

setprop twrp.myron.weaver_ready 1
log_msg "weaver_nxp running but stability window was short; continuing"
exit 0
