#!/system/bin/sh
# Start the Xiaomi 17 Ultra Weaver backend used by the detected hardware.
#
# The SKU spread is wider than any route table can track: normal_590, leica_597
# and global_5190 all exist, and a unit can report a hwversion that no branch
# lists.  The route therefore only orders the two backends; which one is really
# present is decided by bringing up its secure-element chain and seeing whether
# it survives.  A backend that dies is abandoned within a few seconds and the
# other one is tried, so an unknown SKU still reaches decryption.
#
# normal_590 and global_5190 are Thales routes (eSE1 over OMAPI).
# leica_597 is a Goodix route (eSE2).

LOG=/tmp/recovery.log
TMPROOT=/tmp/nezha-crypto
TMPLOG=$TMPROOT/log

log_msg() {
    echo "nezha-goodix-gate: $1" >> "$LOG"
    echo "nezha-goodix-gate: $1" >> "$TMPLOG" 2>/dev/null || true
    log -t nezha_goodix_gate "$1" 2>/dev/null || true
}

# wait_stable_running <service> <samples> <seconds>
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

weaver_service_for() {
    if [ "$1" = "thales" ]; then
        echo thales_weaver_hal_service
    else
        echo goodix_weaver_hal_service
    fi
}

weaver_process_for() {
    if [ "$1" = "thales" ]; then
        echo android.hardware.weaver-service-thales-recovery
    else
        echo android.hardware.weaver-service-goodix-recovery
    fi
}

# Bring up the secure-element side of one backend.  This is the part that tells
# us whether the hardware is really there: an absent eSE makes the HAL exit or
# the registration fail, and the following Weaver start then aborts.
start_secure_element_chain() {
    if [ "$1" = "thales" ]; then
        # Thales reaches eSE1 through OMAPI.  Goodix eSE2 must not be started:
        # it is absent on these units and its HAL aborts with BAD_TYPE.
        ensure_service_running vendor.secure_element
        if ! wait_stable_running vendor.secure_element 2 8; then
            log_msg "vendor.secure_element did not stay running"
            return 1
        fi
        ensure_service_running se_omapi
        if ! wait_stable_running se_omapi 2 8; then
            log_msg "se_omapi did not stay running"
            return 1
        fi
    else
        start secure_element_hal_service
        if ! wait_stable_running secure_element_hal_service 2 8; then
            log_msg "secure_element_hal_service did not stay running"
            return 1
        fi
    fi
    return 0
}

# Try one backend. Returns 0 when its Weaver service is up and stays up.
try_backend() {
    candidate="$1"
    service="$(weaver_service_for "$candidate")"
    process="$(weaver_process_for "$candidate")"
    setprop twrp.nezha.weaver_backend "$candidate"

    if ! start_secure_element_chain "$candidate"; then
        setprop twrp.nezha.goodix_gate_error "${candidate}_secure_element_not_ready"
        return 1
    fi

    # One quick attempt: a backend without hardware dies almost immediately.
    log_msg "probe $service"
    start "$service"
    if ! wait_stable_running "$service" 2 6; then
        log_msg "$service did not survive the probe"
        stop "$service"
        killall "$process" 2>/dev/null || true
        setprop twrp.nezha.goodix_gate_error "${candidate}_weaver_not_stable"
        return 1
    fi

    # It answered; give it the time a real warm-up needs before trusting it.
    if wait_stable_running "$service" 5 15; then
        setprop twrp.nezha.weaver_ready 1
        log_msg "$candidate Weaver stable route=$(getprop twrp.nezha.crypto_route)"
        return 0
    fi

    log_msg "$service dropped after the probe"
    stop "$service"
    killall "$process" 2>/dev/null || true
    setprop twrp.nezha.goodix_gate_error "${candidate}_weaver_dropped"
    return 1
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
# handles and makes the secure-element path fail with 0xF402 / invalid handle.
reset_weaver_services
ensure_service_running vendor.qseecomd
ensure_service_running vendor.minkdaemon

route="$(getprop twrp.nezha.crypto_route)"
first=thales
case "$route" in
    leica_597|goodix_fallback) first=goodix ;;
esac
if [ "$first" = "thales" ]; then second=goodix; else second=thales; fi

# A forced value skips the probe, for field testing without a rebuild.
forced="$(getprop twrp.nezha.force_backend)"
case "$forced" in
    thales|goodix) first="$forced"; second="$forced"; log_msg "backend forced to $first" ;;
esac

# A backend that already succeeded earlier in this boot is tried first, so the
# decrypt retry path does not pay for the probe again.
known="$(getprop twrp.nezha.weaver_backend_ok)"
case "$known" in
    thales|goodix) first="$known"; if [ "$known" = "thales" ]; then second=goodix; else second=thales; fi ;;
esac

tried=""
for candidate in "$first" "$second"; do
    [ "$candidate" = "$tried" ] && continue
    tried="$candidate"
    if try_backend "$candidate"; then
        setprop twrp.nezha.weaver_backend_ok "$candidate"
        exit 0
    fi
    log_msg "$candidate backend failed; continuing"
    setprop twrp.nezha.goodix_gate_error ""
done

setprop twrp.nezha.weaver_ready 0
setprop twrp.nezha.goodix_gate_error "no_weaver_backend_stable"
log_msg "no Weaver backend stabilised"
exit 0
