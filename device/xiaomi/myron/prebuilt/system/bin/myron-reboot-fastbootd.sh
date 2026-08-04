#!/system/bin/sh

LOG=/tmp/recovery.log
PERSIST=/metadata/twrp-fastbootd.log

record() {
    echo "$*" >> "$LOG"
    if [ -d /metadata ]; then
        echo "$*" >> "$PERSIST" 2>/dev/null
    fi
}

MISC=/dev/block/by-name/misc
[ -e "$MISC" ] || MISC=/dev/block/bootdevice/by-name/misc
if [ ! -e "$MISC" ]; then
    record "E:Fastbootd: misc partition not found."
    exit 1
fi

record "I:Fastbootd: request started; misc=$MISC"
/system/bin/dd if=/dev/zero of="$MISC" bs=2048 count=1 conv=notrunc 2>>"$LOG" || exit 1
printf 'boot-fastboot' | /system/bin/dd of="$MISC" bs=1 count=13 conv=notrunc 2>>"$LOG" || exit 1
printf 'recovery
--fastboot
' | /system/bin/dd of="$MISC" bs=1 seek=64 conv=notrunc 2>>"$LOG" || exit 1
/system/bin/sync

command=$(/system/bin/dd if="$MISC" bs=1 count=13 2>/dev/null)
recovery_args=$(/system/bin/dd if="$MISC" bs=1 skip=64 count=20 2>/dev/null)
record "I:Fastbootd: BCB command='$command' args='$recovery_args'"
if [ "$command" != "boot-fastboot" ]; then
    record "E:Fastbootd: BCB read-back failed."
    exit 1
fi

record "I:Fastbootd: rebooting to recovery userspace fastboot."
/system/bin/setprop sys.powerctl reboot,recovery
/system/bin/sleep 2
record "W:Fastbootd: sys.powerctl returned; retrying with reboot binary."
/system/bin/reboot recovery
while :; do
    /system/bin/sleep 1
done
