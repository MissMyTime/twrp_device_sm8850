#!/system/bin/sh

[ "$(getprop ro.twrp.fastbootd 2>/dev/null)" = 1 ] && exit 0

LOG=/tmp/songyuan-usb-role-recover.log
UDC=/config/usb_gadget/g1/UDC
MODE=/sys/bus/platform/devices/a600000.ssusb/mode
ROLE=/sys/class/usb_role/a600000.ssusb-role-switch/role

find_role_path() {
    if [ -r "$ROLE" ]; then
        return 0
    fi
    for candidate in /sys/class/usb_role/*/role; do
        if [ -r "$candidate" ]; then
            ROLE="$candidate"
            return 0
        fi
    done
    return 1
}

log_line() {
    message="$(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$message" >> "$LOG"
    echo "songyuan-usb-role-recover: $*" > /dev/kmsg 2>/dev/null || true
}

udc_state() {
    if [ -n "$controller" ] && [ -r "/sys/class/udc/$controller/state" ]; then
        cat "/sys/class/udc/$controller/state" 2>/dev/null
    else
        echo unknown
    fi
}

rebind_current_composite() {
    log_line "rebinding existing $config composite on $controller"
    [ -w "$UDC" ] && echo none > "$UDC" 2>/dev/null
    [ -w "$MODE" ] && echo peripheral > "$MODE" 2>/dev/null
    sleep 1
    if [ -n "$controller" ] && [ -w "$UDC" ]; then
        echo "$controller" > "$UDC" 2>/dev/null
    fi

    wait_count=0
    while [ "$wait_count" -lt 4 ]; do
        [ "$(udc_state)" = configured ] && {
            log_line "existing composite configured successfully"
            return 0
        }
        wait_count=$((wait_count + 1))
        sleep 1
    done
    return 1
}

restore_adb_only() {
    log_line "composite did not configure; rebuilding the init-managed adb gadget"
    setprop sys.usb.config none
    sleep 1
    [ -w "$MODE" ] && echo peripheral > "$MODE" 2>/dev/null
    setprop sys.usb.config adb

    wait_count=0
    while [ "$wait_count" -lt 8 ]; do
        [ "$(udc_state)" = configured ] && {
            log_line "adb gadget configured successfully"
            return 0
        }
        wait_count=$((wait_count + 1))
        sleep 1
    done
    log_line "adb fallback ended with UDC state $(udc_state)"
}

seen_host=0
setprop twrp.usb.host_active 0
log_line "monitor started"

while true; do
    [ "$(getprop ro.twrp.fastbootd 2>/dev/null)" = 1 ] && exit 0

    if ! find_role_path; then
        sleep 1
        continue
    fi

    role=$(cat "$ROLE" 2>/dev/null)
    case "$role" in
        host)
            setprop twrp.usb.host_active 1
            if [ -w "$UDC" ]; then
                bound_controller=$(cat "$UDC" 2>/dev/null)
                if [ -n "$bound_controller" ] && [ "$bound_controller" != none ]; then
                    echo none > "$UDC" 2>/dev/null
                fi
            fi
            if [ "$seen_host" != 1 ]; then
                log_line "USB role entered host mode"
            fi
            seen_host=1
            ;;
        device|peripheral)
            if [ "$seen_host" = 1 ]; then
                sleep 2
                role=$(cat "$ROLE" 2>/dev/null)
                if [ "$role" != device ] && [ "$role" != peripheral ]; then
                    sleep 1
                    continue
                fi

                setprop twrp.usb.host_active 0
                controller=$(getprop sys.usb.controller)
                [ -n "$controller" ] || controller=$(getprop ro.boot.usbcontroller)
                config=$(getprop sys.usb.config)

                if [ "$(udc_state)" = configured ]; then
                    log_line "device mode already configured ($config)"
                    seen_host=0
                    sleep 1
                    continue
                fi

                case "$config" in
                    adb|mtp|mtp,adb|songyuan_mtp_adb)
                        rebind_current_composite || restore_adb_only
                        ;;
                    *)
                        log_line "leaving USB config $config unchanged"
                        ;;
                esac
                seen_host=0
            else
                setprop twrp.usb.host_active 0
            fi
            ;;
    esac
    sleep 0.25
done
