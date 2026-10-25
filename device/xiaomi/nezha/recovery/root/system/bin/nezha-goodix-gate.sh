#!/system/bin/sh
# Start the Xiaomi 17 Ultra Weaver backend used by the detected hardware.
#
# normal_590 and global_5190 reach eSE1 through the stock Thales Weaver path
# over OMAPI.  leica_597 uses Goodix eSE2.  The route name is kept stable
# because the boot-time timing table is keyed on it; the backend that each
# route needs is decided in select_backend().
#
# A route that fails to stabilise is retried on the other backend before the
# gate gives up, so an unknown SKU can still decrypt.

LOG=/tmp/recovery.log
TMPROOT=/tmp/nezha-crypto
TMPLOG=$TMPROOT/log

log_msg() {
    echo "nezha-goodix-gate: $1" >> "$LOG"
    echo "nezha-goodix-gate: $1" >> "$TMPLOG" 2>/dev/null || true
    log -t nezha_goodix_gate "$1" 2>/dev/null || true
}

wait_stable_running() {
    name="$1"
    stable_needed="$2"
    limit="$3"
    stable=0
    i=0
    while [ "$i" -lt "$limit" ]; do
        if [ "$(getprop "init.svc.$name")" = "running" ]; then
            stable=$((stable + 1))
            [ "$stable" -ge "$stable_needed" ] && return 0
        else
            stable=0
        fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}

detect_route() {
    model="$(getprop ro.product.model)"
    hwc="$(getprop ro.boot.hwc)"
    hwver="$(getprop ro.boot.hwversion)"
    vbstate="$(getprop ro.boot.verifiedbootstate)"
    fp="$(getprop ro.vendor.build.fingerprint)"

    route=goodix_fallback
    case "$hwc" in
        CN) route=normal_590 ;;
        GL) route=global_5190 ;;
        *)
            case "$hwver:$model" in
                5.9.0*) route=normal_590 ;;
                5.9.7*) route=leica_597 ;;
                5.19.*) route=global_5190 ;;
                *25128PNA1C*) route=leica_597 ;;
                *2512BPNDAC*) route=normal_590 ;;
            esac
            ;;
    esac

    setprop twrp.nezha.model "$model"
    setprop twrp.nezha.hwc "$hwc"
    setprop twrp.nezha.hwversion "$hwver"
    setprop twrp.nezha.verifiedbootstate "$vbstate"
    setprop twrp.nezha.crypto_route "$route"
    log_msg "route=$route model=$model hwc=$hwc hwversion=$hwver vbstate=$vbstate fp=$fp"
}

reset_weaver_services() {
    stop goodix_weaver_hal_service
    stop thales_weaver_hal_service
    stop secure_element_hal_service
    killall android.hardware.weaver-service-goodix-recovery 2>/dev/null || true
    killall android.hardware.weaver-service-thales-recovery 2>/dev/null || true
    killall android.hardware.secure_element-service-goodix-recovery 2>/dev/null || true
}

ensure_service_running() {
    name="$1"
    if [ "$(getprop "init.svc.$name")" != "running" ]; then
        log_msg "start $name without resetting secure-world peers"
        start "$name"
    else
        log_msg "keep existing $name session"
    fi
}

prepare_tmp_state() {
    mkdir -p "$TMPROOT" "$TMPROOT/data" "$TMPROOT/persist" "$TMPROOT/logs"
    chmod 0700 "$TMPROOT" "$TMPROOT/data" "$TMPROOT/persist" "$TMPROOT/logs"
    rm -rf /tmp/SELog* /tmp/goodix* /tmp/nezha-thales 2>/dev/null || true
}

# Apply the timing and service names for one backend.
select_backend() {
    case "$1" in
        thales)
            qsee_stable=2
            qsee_limit=15
            mink_stable=2
            mink_limit=15
            se_stable=3
            se_limit=20
            weaver_stable=3
            weaver_limit=12
            weaver_attempts=4
            settle_before_weaver=1
            retry_sleep=2
            weaver_service=thales_weaver_hal_service
            weaver_process=android.hardware.weaver-service-thales-recovery
            ;;
        *)
            qsee_stable=3
            qsee_limit=25
            mink_stable=3
            mink_limit=25
            se_stable=3
            se_limit=30
            weaver_stable=4
            weaver_limit=12
            weaver_attempts=6
            settle_before_weaver=2
            retry_sleep=3
            weaver_service=goodix_weaver_hal_service
            weaver_process=android.hardware.weaver-service-goodix-recovery
            ;;
    esac
    backend="$1"
    setprop twrp.nezha.weaver_backend "$backend"
}

# Bring up one backend end to end. Returns 0 when Weaver stays running.
start_backend() {
    select_backend "$1"

    if ! wait_stable_running vendor.qseecomd "$qsee_stable" "$qsee_limit"; then
        setprop twrp.nezha.goodix_gate_error vendor_qseecomd_not_stable
        log_msg "vendor.qseecomd did not stay running backend=$backend"
        return 1
    fi

    if ! wait_stable_running vendor.minkdaemon "$mink_stable" "$mink_limit"; then
        setprop twrp.nezha.goodix_gate_error vendor_minkdaemon_not_stable
        log_msg "vendor.minkdaemon did not stay running backend=$backend"
        return 1
    fi

    if [ "$backend" = "thales" ]; then
        # The stock Thales route reaches eSE1 through OMAPI.  Goodix eSE2 is
        # absent on this hardware and must not be started.
        ensure_service_running vendor.secure_element
        if ! wait_stable_running vendor.secure_element "$se_stable" "$se_limit"; then
            setprop twrp.nezha.goodix_gate_error vendor_secure_element_not_stable
            log_msg "vendor.secure_element did not stay running backend=$backend"
            return 1
        fi
        ensure_service_running se_omapi
        if ! wait_stable_running se_omapi "$se_stable" "$se_limit"; then
            setprop twrp.nezha.goodix_gate_error se_omapi_not_stable
            log_msg "se_omapi did not stay running backend=$backend"
            return 1
        fi
    else
        start secure_element_hal_service
        if ! wait_stable_running secure_element_hal_service "$se_stable" "$se_limit"; then
            setprop twrp.nezha.goodix_gate_error secure_element_hal_not_stable
            log_msg "secure_element_hal_service did not stay running backend=$backend"
            return 1
        fi
    fi

    sleep "$settle_before_weaver"

    attempt=1
    while [ "$attempt" -le "$weaver_attempts" ]; do
        setprop twrp.nezha.goodix_gate_attempt "$attempt"
        log_msg "start $weaver_service backend=$backend attempt $attempt"
        start "$weaver_service"
        if wait_stable_running "$weaver_service" "$weaver_stable" "$weaver_limit"; then
            setprop twrp.nezha.weaver_ready 1
            log_msg "$backend Weaver stable route=$(getprop twrp.nezha.crypto_route)"
            return 0
        fi
        stop "$weaver_service"
        killall "$weaver_process" 2>/dev/null || true
        sleep "$retry_sleep"
        attempt=$((attempt + 1))
    done

    setprop twrp.nezha.goodix_gate_error "${backend}_weaver_hal_not_stable"
    log_msg "$weaver_service did not stay running backend=$backend"
    return 1
}

other_backend() {
    if [ "$1" = "thales" ]; then echo goodix; else echo thales; fi
}

setprop twrp.nezha.goodix_gate_started 1
setprop twrp.nezha.goodix_gate_error ""
setprop twrp.nezha.weaver_ready 0
prepare_tmp_state
detect_route
log_msg "start"

# PRODUCT_COPY_FILES can normalize rootfs overlay executables to 0644.
# Restore executable mode before init launches the stable /sbin copies.
chmod 0755 /sbin/android.hardware.secure_element-service-goodix-recovery
chmod 0755 /sbin/android.hardware.weaver-service-goodix-recovery
chmod 0755 /sbin/android.hardware.weaver-service-thales-recovery

# qseecomd and Mink may already be serving KeyMint, Gatekeeper and the stock
# secure-element service. Restarting either daemon invalidates live Mink object
# handles and makes the Goodix eSE path fail with 0xF402 / invalid handle.
# Preserve an existing session and start a daemon only when it is not running.
reset_weaver_services
ensure_service_running vendor.qseecomd
ensure_service_running vendor.minkdaemon

# normal_590 and global_5190 are Thales routes; leica_597 is Goodix.
primary=thales
case "$(getprop twrp.nezha.crypto_route)" in
    leica_597|goodix_fallback) primary=goodix ;;
esac

# A forced value helps field testing without rebuilding the image.
forced="$(getprop twrp.nezha.force_backend)"
case "$forced" in
    thales|goodix) primary="$forced"; log_msg "backend forced to $primary" ;;
esac

if start_backend "$primary"; then
    exit 0
fi

fallback="$(other_backend "$primary")"
log_msg "$primary backend failed; trying $fallback"
setprop twrp.nezha.goodix_gate_error ""

if start_backend "$fallback"; then
    exit 0
fi

setprop twrp.nezha.weaver_ready 0
setprop twrp.nezha.goodix_gate_error "no_weaver_backend_stable"
log_msg "both Weaver backends failed"
exit 0
