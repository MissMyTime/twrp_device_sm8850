#!/system/bin/sh

# Redmi K100 Pro Max (songyuan) requires the external 148712-byte FT3685G
# firmware.  The module's 123836-byte built-in fallback uses a different THP
# frame layout and causes intermittent, inverted-looking or dead touch.
TAG=songyuan-touch-fw
FW_NAME=focaltech_ts_fw_songyuan.bin
FW_SIZE=148712
FW_PATH_PARAM=/sys/module/firmware_class/parameters/path
TOUCH_DEV_SYSFS=/sys/class/misc/xiaomi-touch/dev
TOUCH_DEV=/dev/xiaomi-touch
TOUCH_CLASS=/sys/class/touch
TOUCH_ROOT=/sys/devices/virtual/touch
TOUCH_NODE=$TOUCH_ROOT/touch_dev
ABNORMAL_EVENT=$TOUCH_NODE/abnormal_event
TOUCH_RAW=$TOUCH_NODE/enable_touch_raw

setprop vendor.touch.recovery.firmware_ready 0
setprop vendor.touch.recovery.firmware_failed 0
stop touchfeature-service

retry=0
while [ "$retry" -lt 20 ]; do
    FW_DIR=
    for candidate in /odm/firmware /vendor/firmware; do
        file="$candidate/$FW_NAME"
        [ -r "$file" ] || continue
        size="$(wc -c < "$file" 2>/dev/null)"
        if [ "$size" = "$FW_SIZE" ]; then
            FW_DIR="$candidate"
            break
        fi
        /system/bin/log -p e -t "$TAG" "Rejected $file: size=$size"
    done

    FW_NODE=
    for candidate in /sys/bus/spi/devices/*/fts_force_upgrade; do
        [ -e "$candidate" ] || continue
        FW_NODE="$candidate"
        break
    done

    devno="$(cat "$TOUCH_DEV_SYSFS" 2>/dev/null)"
    major="${devno%:*}"
    minor="${devno#*:}"

    if [ -n "$FW_DIR" ] && [ -n "$FW_NODE" ] && [ -w "$FW_PATH_PARAM" ] && \
       [ -w "$FW_NODE" ] && [ -n "$devno" ] && [ "$major" != "$devno" ] && \
       [ -d "$TOUCH_NODE" ]; then
        # Recovery ueventd can miss this late-created misc node.  Recreate it
        # from the kernel-exported major/minor rather than hard-coding values.
        if [ ! -e "$TOUCH_DEV" ]; then
            # ueventd may win the race between the existence check and mknod.
            mknod "$TOUCH_DEV" c "$major" "$minor" 2>/dev/null || true
        fi
        if [ ! -c "$TOUCH_DEV" ]; then
            /system/bin/log -p e -t "$TAG" "Failed to create $TOUCH_DEV ($devno); retrying"
            retry=$((retry + 1))
            sleep 1
            continue
        fi
        chown system:system "$TOUCH_DEV"
        chmod 0666 "$TOUCH_DEV"

        # The stock HAL runs as system.  It must be able to traverse these
        # directories and open abnormal_event read/write during hal init.
        chown root:root "$TOUCH_CLASS" "$TOUCH_ROOT" "$TOUCH_NODE"
        chmod 0755 "$TOUCH_CLASS" "$TOUCH_ROOT" "$TOUCH_NODE"
        for attr in "$TOUCH_NODE"/*; do
            [ -f "$attr" ] || continue
            chown -f system:system "$attr"
            chmod -f 0664 "$attr"
        done
        if ! chown system:system "$ABNORMAL_EVENT" || ! chmod 0664 "$ABNORMAL_EVENT"; then
            /system/bin/log -p e -t "$TAG" "Could not prepare $ABNORMAL_EVENT; retrying"
            retry=$((retry + 1))
            sleep 1
            continue
        fi

        # Publish the real songyuan panel/touch properties before the Xiaomi
        # THP service starts; this script only reads the prepared sysfs nodes.
        /system/bin/sh /odm/etc/init.panel_info.sh

        # firmware_class.path is global, not touch-specific.  Preserve it so
        # the touch force-upgrade cannot strand IPA/CNSS lookups in
        # /odm/firmware after the official FocalTech image is loaded.
        old_fw_path="$(cat "$FW_PATH_PARAM" 2>/dev/null)"
        load_ok=0
        if echo "$FW_DIR" > "$FW_PATH_PARAM" && echo "$FW_NAME" > "$FW_NODE"; then
            load_ok=1
        fi
        echo "$old_fw_path" > "$FW_PATH_PARAM" 2>/dev/null || true

        if [ "$load_ok" = 1 ]; then
            # K100PM reports ordinary coordinates directly through fts_ts.
            # Raw/THP mode consumes those events and makes TWRP appear dead.
            [ -w "$TOUCH_RAW" ] && echo 0 > "$TOUCH_RAW"
            /system/bin/log -p i -t "$TAG" \
                "Prepared $TOUCH_DEV ($devno) and loaded $FW_DIR/$FW_NAME ($FW_SIZE bytes)"
            setprop vendor.touch.recovery.firmware_ready 1
            exit 0
        fi
    fi

    retry=$((retry + 1))
    sleep 1
done

/system/bin/log -p e -t "$TAG" "Official FT3685G firmware was not loaded; touch HAL remains gated"
setprop vendor.touch.recovery.firmware_failed 1
exit 1
