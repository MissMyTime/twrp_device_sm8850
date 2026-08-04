#!/system/bin/sh

LOG=/tmp/myron-usb-role-recover.log
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
    echo "myron-usb-role-recover: $*" > /dev/kmsg 2>/dev/null || true
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
    if [ -w "$UDC" ]; then
        echo none > "$UDC" 2>/dev/null
    fi
    if [ -w "$MODE" ]; then
        echo peripheral > "$MODE" 2>/dev/null
    fi
    sleep 1
    if [ -n "$controller" ] && [ -w "$UDC" ]; then
        echo "$controller" > "$UDC" 2>/dev/null
    fi

    wait_count=0
    while [ "$wait_count" -lt 4 ]; do
        state=$(udc_state)
        if [ "$state" = configured ]; then
            log_line "existing composite configured successfully"
            return 0
        fi
        wait_count=$((wait_count + 1))
        sleep 1
    done
    return 1
}

restore_adb_only() {
    log_line "composite did not configure; rebuilding the init-managed adb gadget"
    setprop sys.usb.config none
    sleep 1
    if [ -w "$MODE" ]; then
        echo peripheral > "$MODE" 2>/dev/null
    fi
    setprop sys.usb.config adb

    wait_count=0
    while [ "$wait_count" -lt 8 ]; do
        state=$(udc_state)
        if [ "$state" = configured ]; then
            log_line "adb gadget configured successfully"
            return 0
        fi
        wait_count=$((wait_count + 1))
        sleep 1
    done
    log_line "adb fallback ended with UDC state $(udc_state)"
}

seen_host=0
log_line "monitor started"

while true; do
    if ! find_role_path; then
        sleep 1
        continue
    fi

    role=$(cat "$ROLE" 2>/dev/null)
    case "$role" in
        host)
            if [ "$seen_host" != 1 ]; then
                log_line "USB role entered host mode"
            fi
            seen_host=1
            ;;
        device)
            if [ "$seen_host" = 1 ]; then
                sleep 2
                role=$(cat "$ROLE" 2>/dev/null)
                if [ "$role" != device ]; then
                    sleep 1
                    continue
                fi

                controller=$(getprop sys.usb.controller)
                if [ -z "$controller" ]; then
                    controller=$(getprop ro.boot.usbcontroller)
                fi
                config=$(getprop sys.usb.config)
                state=$(udc_state)

                if [ "$state" = configured ]; then
                    log_line "device mode already configured ($config)"
                    seen_host=0
                    sleep 1
                    continue
                fi

                case "$config" in
                    adb|mtp|mtp,adb|twrp_mtp_adb)
                        if ! rebind_current_composite; then
                            restore_adb_only
                        fi
                        ;;
                    *)
                        log_line "leaving USB config $config unchanged"
                        ;;
                esac
                seen_host=0
            fi
            ;;
    esac
    sleep 1
done
