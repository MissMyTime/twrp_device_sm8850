#!/system/bin/sh

# The by-name symlinks have partition-specific SELinux labels, while ueventd
# can leave their dynamically assigned UFS targets as generic block_device.
# Resolve every target at runtime because UFS LUN letters are not stable.

LOG=/tmp/recovery.log

record() {
    echo "I:Myron Fastbootd labels: $*" >> "$LOG"
}

wait_for_by_name() {
    count=0
    while [ ! -e /dev/block/by-name/init_boot_a ] && [ "$count" -lt 30 ]; do
        /system/bin/sleep 0.1
        count=$((count + 1))
    done
}

label_target() {
    name="$1"
    label="$2"

    for link in \
        "/dev/block/by-name/$name" \
        "/dev/block/bootdevice/by-name/$name" \
        /dev/block/platform/soc/*/by-name/"$name"; do
        [ -e "$link" ] || continue
        target=$(/system/bin/readlink -f "$link" 2>/dev/null)
        [ -b "$target" ] || continue

        if /system/bin/chcon "u:object_r:${label}:s0" "$target" 2>>"$LOG"; then
            record "$name -> $target ($label)"
            return 0
        fi
    done

    record "$name target unavailable"
    return 1
}

wait_for_by_name

for name in \
    boot_a boot_b \
    init_boot_a init_boot_b \
    vendor_boot_a vendor_boot_b \
    recovery_a recovery_b \
    dtbo_a dtbo_b \
    vbmeta_a vbmeta_b \
    vbmeta_system_a vbmeta_system_b \
    pvmfw_a pvmfw_b; do
    label_target "$name" boot_block_device
done

label_target super super_block_device
label_target metadata metadata_block_device
label_target userdata userdata_block_device
label_target misc misc_block_device

exit 0
