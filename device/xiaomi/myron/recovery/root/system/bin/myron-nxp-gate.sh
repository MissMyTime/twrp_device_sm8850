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

setprop twrp.myron.nxp_gate_started 1
setprop twrp.myron.nxp_gate_error ""
setprop twrp.myron.nxp_gate_attempt 0
log_msg "start"

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
