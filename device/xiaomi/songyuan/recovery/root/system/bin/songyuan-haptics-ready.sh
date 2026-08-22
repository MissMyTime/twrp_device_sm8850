#!/system/bin/sh
# Make the stock K100PM qcom-haptics controls available to TWRP after the
# vendor modules have finished loading.  This only fixes ownership/mode; it
# deliberately does not emit a diagnostic vibration on arbitrary touches.
# This helper is packaged as an executable recovery ramdisk service.

LOG_TAG=songyuan_haptics
i=0
while [ "$i" -lt 100 ]; do
    if [ -e /sys/class/qcom-haptics/swr_play ] && \
       [ -e /sys/class/qcom-haptics/primitive_duration ]; then
        chown root root /sys/class/qcom-haptics/swr_play
        chown root root /sys/class/qcom-haptics/primitive_duration
        chmod 0660 /sys/class/qcom-haptics/swr_play
        chmod 0660 /sys/class/qcom-haptics/primitive_duration
        setprop twrp.songyuan.haptics_ready 1
        log -p i -t "$LOG_TAG" "qcom-haptics controls ready for TWRP"
        exit 0
    fi
    i=$((i + 1))
    sleep 0.1
done

setprop twrp.songyuan.haptics_ready 0
log -p e -t "$LOG_TAG" "qcom-haptics controls did not appear"
exit 1
