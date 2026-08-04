#!/system/bin/sh

grep -Eq '(swinfo|mtdoops|bootmonitor)\.fingerprint=EvolutionX-17\.' /proc/cmdline 2>/dev/null || exit 0

gadget=/config/usb_gadget/g1
controller="$(getprop sys.usb.controller)"
[ -n "$controller" ] || controller=a600000.dwc3
mode=/sys/bus/platform/devices/a600000.ssusb/mode

i=0
while [ "$i" -lt 80 ]; do
    config="$(getprop sys.usb.config)"
    [ "$config" = twrp_mtp_adb ] || exit 0

    if [ "$(getprop twrp.usb.mtp_configured)" = 1 ] &&
       [ -L "$gadget/configs/b.1/f1" ] && [ -L "$gadget/configs/b.1/f2" ]; then
        udc="$(cat "$gadget/UDC" 2>/dev/null)"
        if [ -z "$udc" ] || [ "$udc" = none ]; then
            [ -w "$mode" ] && echo peripheral > "$mode" 2>/dev/null
            sleep 0.15
            echo "$controller" > "$gadget/UDC" 2>/dev/null
        elif [ -r "/sys/class/udc/$controller/state" ] &&
             [ "$(cat "/sys/class/udc/$controller/state" 2>/dev/null)" = configured ]; then
            setprop twrp.evox.mtp_keeper 1
        fi
    fi

    sleep 0.10
    i=$((i + 1))
done
