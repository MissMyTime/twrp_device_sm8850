#!/system/bin/sh

LOG_FILE=/tmp/wifi-modules.log
KERNEL_RELEASE="$(uname -r)"
SLOT_SUFFIX="$(getprop ro.boot.slot_suffix)"

if [ -z "$SLOT_SUFFIX" ]; then
  SLOT="$(getprop ro.boot.slot)"
  [ -n "$SLOT" ] && SLOT_SUFFIX="_$SLOT"
fi

: > "$LOG_FILE"
echo "kernel=$KERNEL_RELEASE" >> "$LOG_FILE"
echo "bootimage=$(getprop ro.bootimage.build.version.incremental)" >> "$LOG_FILE"
echo "slot_suffix=$SLOT_SUFFIX" >> "$LOG_FILE"

# Security owns the slot-aware modem firmware mount.  Waiting for its explicit
# ready latch prevents a Wi-Fi click from mounting below a temporary logical
# /vendor mount and breaking the already working eSE/Weaver chain.
i=0
while [ "$i" -lt 30 ] && [ "$(getprop twrp.songyuan.security_ready)" != 1 ]; do
  error="$(getprop twrp.songyuan.security_error)"
  [ -n "$error" ] && {
    echo "security chain unavailable: $error" >> "$LOG_FILE"
    exit 1
  }
  sleep 1
  i=$((i + 1))
done
if [ "$(getprop twrp.songyuan.security_ready)" != 1 ]; then
  echo "security chain not ready" >> "$LOG_FILE"
  exit 1
fi

# IPA and CNSS request their signed blobs through the firmware sysfs fallback
# in recovery. Enable it before probing the packaged Wi-Fi modules.
# inserting the peach_v2 host driver or MHI power-on can block until watchdog.
FIRMWARE_FALLBACK=/proc/sys/kernel/firmware_config/force_sysfs_fallback
if [ ! -e "$FIRMWARE_FALLBACK" ] || ! echo 1 > "$FIRMWARE_FALLBACK"; then
  echo "firmware sysfs fallback unavailable" >> "$LOG_FILE"
  exit 1
fi

# songyuan-security-start mounts the official modem partition here. Refuse to
# load the WLAN host driver when that mount is absent; failing safely is better
# than entering the CNSS/MHI timeout loop seen on V20.
if ! grep -q " /vendor/firmware_mnt " /proc/mounts || \
   [ ! -d /vendor/firmware_mnt/image ]; then
  echo "official firmware mount unavailable" >> "$LOG_FILE"
  exit 1
fi

mount_runtime_partition() {
  partition="$1"
  mount_point="/$partition"

  grep -q " $mount_point " /proc/mounts && return 0
  mkdir -p "$mount_point"

  for block_device in \
    "/dev/block/mapper/${partition}${SLOT_SUFFIX}" \
    "/dev/block/bootdevice/by-name/${partition}${SLOT_SUFFIX}" \
    "/dev/block/by-name/${partition}${SLOT_SUFFIX}" \
    "/dev/block/mapper/$partition" \
    "/dev/block/bootdevice/by-name/$partition" \
    "/dev/block/by-name/$partition"; do
    [ -e "$block_device" ] || continue
    mount -o ro "$block_device" "$mount_point" >> "$LOG_FILE" 2>&1 && return 0
    mount -t erofs -o ro "$block_device" "$mount_point" >> "$LOG_FILE" 2>&1 && return 0
    mount -t ext4 -o ro "$block_device" "$mount_point" >> "$LOG_FILE" 2>&1 && return 0
  done

  echo "mount failed: $mount_point" >> "$LOG_FILE"
  return 1
}

mount_runtime_partition system_dlkm
mount_runtime_partition vendor_dlkm

mkdir -p /firmware
mount | grep -q " /firmware " || mount -o bind /vendor/firmware_mnt /firmware 2>/dev/null

mkdir -p /vendor/firmware/wlan/qca_cld/peach_v2
cp /vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini \
  /vendor/firmware/wlan/qca_cld/peach_v2/WCNSS_qcom_cfg.ini 2>/dev/null

load_module_from() {
  name="$1"
  shift
  module_name="${name%.ko}"
  module_name="$(echo "$module_name" | tr '-' '_')"
  grep -q "^${module_name} " /proc/modules && return 0

  for module_path in "$@"; do
    [ -f "$module_path" ] || continue
    echo "insmod $module_path" >> "$LOG_FILE"
    if insmod "$module_path" >> "$LOG_FILE" 2>&1; then
      return 0
    fi
  done

  echo "load failed: $name" >> "$LOG_FILE"
  return 1
}

load_gki_module() {
  name="$1"
  relative_path="$2"
  load_module_from "$name" \
    "/system_dlkm/flatten/lib/modules/$name" \
    "/system_dlkm/lib/modules/$KERNEL_RELEASE/$relative_path/$name" \
    "/system/lib/modules/$name" \
    "/vendor/lib/modules/$name" \
    "/vendor_dlkm/lib/modules/$name" \
    "/tmp/vendor/lib/modules/$name" \
    "/tmp/vendor_dlkm/lib/modules/$name"
}

load_vendor_module() {
  name="$1"
  load_module_from "$name" \
    "/vendor_dlkm/lib/modules/$name" \
    "/vendor/lib/modules/$name" \
    "/tmp/vendor_dlkm/lib/modules/$name" \
    "/tmp/vendor/lib/modules/$name"
}

load_gki_module libarc4.ko kernel/lib/crypto
load_gki_module rfkill.ko kernel/net/rfkill
load_vendor_module cfg80211.ko
load_vendor_module mac80211.ko
load_vendor_module wlan_firmware_service.ko
load_vendor_module cnss_prealloc.ko
load_vendor_module cnss_utils.ko
load_vendor_module cnss_nl.ko
load_vendor_module cnss_plat_ipc_qmi_svc.ko
load_vendor_module cnss2.ko
load_vendor_module qca_cld3_peach_v2.ko

[ -e /sys/devices/platform/soc/b0000000.qcom,cnss-peach/fs_ready ] && \
  echo 1 > /sys/devices/platform/soc/b0000000.qcom,cnss-peach/fs_ready
[ -e /sys/kernel/cnss/fs_ready ] && echo 1 > /sys/kernel/cnss/fs_ready

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  [ -e /sys/class/net/wlan0 ] && exit 0
  sleep 1
done

exit 1
