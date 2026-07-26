#!/system/bin/sh

LOG=/tmp/neo8-wifi-loader.log
SEEN_DIR=/tmp/neo8-wifi-seen
rm -rf "$SEEN_DIR"
mkdir -p "$SEEN_DIR"
: > "$LOG"
exec >>"$LOG" 2>&1
trap '{
    echo "===== neo8 Wi-Fi loader ====="
    cat "$LOG"
    echo "===== end Wi-Fi loader ====="
} >> /tmp/recovery.log 2>&1' EXIT

echo "Neo8 WCN7750 loader starting"

mount_partition() {
    local point="$1"
    local name block
    grep -q " $point " /proc/mounts && return 0
    name="${point#/}"
    mkdir -p "$point"
    for block in \
        "/dev/block/bootdevice/by-name/$name" \
        "/dev/block/mapper/$name"; do
        [ -e "$block" ] || continue
        mount -t erofs -o ro "$block" "$point" 2>/dev/null && return 0
        mount -t ext4 -o ro "$block" "$point" 2>/dev/null && return 0
    done
    echo "unable to mount $point directly"
    return 1
}

mount_partition /vendor
mount_partition /vendor_dlkm
mount_partition /system_dlkm
mount_partition /odm

mount_persist() {
    grep -q " /mnt/vendor/persist " /proc/mounts && return 0
    mkdir -p /mnt/vendor/persist /persist
    for block in \
        /dev/block/bootdevice/by-name/persist \
        /dev/block/by-name/persist \
        /dev/block/sda2; do
        [ -e "$block" ] || continue
        if mount -t ext4 -o rw,nosuid,nodev,noatime "$block" /mnt/vendor/persist 2>/dev/null; then
            mount --bind /mnt/vendor/persist /persist 2>/dev/null
            echo "persist mounted from $block"
            return 0
        fi
    done
    echo "unable to mount persist; WLAN calibration may be unavailable"
    return 1
}

mount_persist

module_loaded() {
    local module="${1%.ko}"
    module="$(echo "$module" | tr '-' '_')"
    grep -q "^${module} " /proc/modules
}

find_module() {
    local requested="$1"
    local base path
    base="$(basename "$requested")"
    for path in \
        "$requested" \
        "/vendor/lib/modules/$base" \
        "/vendor_dlkm/lib/modules/$base" \
        "/system_dlkm/lib/modules/$base" \
        "/odm/lib/modules/$base" \
        "/odm_dlkm/lib/modules/$base"; do
        [ -f "$path" ] && {
            echo "$path"
            return 0
        }
    done
    return 1
}

dependency_line() {
    local base depfile line
    base="$(basename "$1")"
    for depfile in \
        /vendor/lib/modules/modules.dep \
        /vendor_dlkm/lib/modules/modules.dep \
        /system_dlkm/lib/modules/modules.dep \
        /odm/lib/modules/modules.dep \
        /odm_dlkm/lib/modules/modules.dep; do
        [ -f "$depfile" ] || continue
        line="$(grep "/$base:" "$depfile" 2>/dev/null | head -n 1)"
        [ -n "$line" ] && {
            echo "${line#*:}"
            return 0
        }
    done
    return 1
}

load_with_dependencies() {
    local requested="$1"
    local base deps dep path
    base="$(basename "$requested")"
    module_loaded "$base" && return 0
    [ -e "$SEEN_DIR/$base" ] && return 0
    : > "$SEEN_DIR/$base"

    deps="$(dependency_line "$base")"
    for dep in $deps; do
        load_with_dependencies "$dep"
    done

    module_loaded "$base" && return 0
    path="$(find_module "$requested")" || {
        echo "missing module: $requested"
        return 1
    }
    echo "insmod $path"
    insmod "$path" || {
        module_loaded "$base" && return 0
        echo "failed module: $path"
        return 1
    }
}

load_with_dependencies /vendor/lib/modules/cnss_plat_ipc_qmi_svc.ko

# WCN7750 is attached through the WPSS remote processor. Android's vendor init
# boots WPSS through icnss before the qcacld module is asked to start. Recovery
# must reproduce that ordering or /dev/wlan ON waits for firmware readiness and
# times out.
load_with_dependencies /vendor/lib/modules/icnss2.ko

boot_wpss() {
    local boot_node ready_node value second
    boot_node=
    ready_node=

    for node in \
        /sys/kernel/icnss/wpss_boot \
        /sys/devices/platform/soc/*wcn*/wpss_boot; do
        [ -e "$node" ] || continue
        boot_node="$node"
        break
    done
    for node in \
        /sys/kernel/icnss/firmware_ready \
        /sys/devices/platform/soc/*wcn*/firmware_ready; do
        [ -e "$node" ] || continue
        ready_node="$node"
        break
    done

    if [ -n "$boot_node" ]; then
        echo "booting WPSS through $boot_node"
        printf '1' > "$boot_node" 2>/dev/null || \
            echo "failed to request WPSS boot through $boot_node"
    else
        echo "WPSS boot node not found"
    fi

    if [ -z "$ready_node" ]; then
        echo "WPSS firmware-ready node not found"
        return 0
    fi

    for second in $(seq 1 15); do
        value="$(cat "$ready_node" 2>/dev/null)"
        case "$value" in
            1|Y|y|ready|READY)
                echo "WPSS firmware ready after ${second}s"
                return 0
                ;;
        esac
        sleep 1
    done
    echo "WPSS firmware not ready after 15s (value=$value)"
    return 0
}

boot_wpss
load_with_dependencies /vendor/lib/modules/qca_cld3_wcn7750.ko

start_cnss_daemon() {
    local daemon
    if /system/bin/toybox pidof cnss-daemon >/dev/null 2>&1; then
        echo "cnss-daemon already running"
        return 0
    fi
    for daemon in \
        /vendor/bin/cnss-daemon \
        /vendor/bin/hw/cnss-daemon; do
        [ -x "$daemon" ] || continue
        echo "starting $daemon -n -l"
        LD_LIBRARY_PATH=/vendor/lib64:/system/lib64:/sbin/lib64 \
            "$daemon" -n -l >>"$LOG" 2>&1 &
        sleep 2
        if /system/bin/toybox pidof cnss-daemon >/dev/null 2>&1; then
            echo "cnss-daemon running"
            return 0
        fi
        echo "cnss-daemon did not stay running"
    done
    echo "missing or failed cnss-daemon"
    return 1
}

start_cnss_daemon

start_wifi_hal() {
    local hal client
    hal=/vendor/bin/hw/android.hardware.wifi-service
    client=/sbin/neo8_wifi_hal_client

    if [ ! -x "$hal" ]; then
        echo "missing Wi-Fi HAL service: $hal"
        return 1
    fi
    # PRODUCT_COPY_FILES can flatten executable prebuilts to 0644 in the
    # recovery ramdisk. Restore the helper mode before testing it.
    if [ -f "$client" ] && [ ! -x "$client" ]; then
        chmod 0755 "$client" 2>/dev/null || \
            echo "failed to restore execute permission on Wi-Fi HAL client"
    fi
    if [ ! -x "$client" ]; then
        echo "missing Wi-Fi HAL client: $client"
        return 1
    fi

    mkdir -p /data/vendor/wifi /data/vendor/wifi/wpa/sockets
    chmod 0770 /data/vendor/wifi /data/vendor/wifi/wpa \
        /data/vendor/wifi/wpa/sockets 2>/dev/null

    if ! /system/bin/toybox pidof android.hardware.wifi-service >/dev/null 2>&1; then
        echo "starting $hal"
        LD_LIBRARY_PATH=/system/lib64:/system_ext/lib64:/vendor/lib64:/odm/lib64:/sbin/lib64 \
            "$hal" >>"$LOG" 2>&1 &
    else
        echo "Wi-Fi HAL service already running"
    fi

    echo "requesting STA interface through IWifi/default"
    LD_LIBRARY_PATH=/system/lib64:/system_ext/lib64:/vendor/lib64:/odm/lib64:/sbin/lib64 \
        "$client" start-sta >>"$LOG" 2>&1
}

start_wifi_hal

# A cold WCN7750/WPSS boot on the Neo8 can take about 30 seconds after
# qca_cld3 is inserted before the STA netdev is registered.  The old
# 15-second timeout returned an error even though the driver completed
# asynchronously a few seconds later, which made a second press succeed.
for second in $(seq 1 45); do
    if [ -e /sys/class/net/wlan0 ]; then
        /system/bin/toybox ip link set wlan0 up 2>/dev/null
        echo "wlan0 ready after ${second}s"
        exit 0
    fi
    case "$second" in
        15|30)
            echo "still waiting for cold WLAN firmware startup (${second}s)"
            ;;
    esac
    sleep 1
done

echo "wlan0 did not appear after 45s"
for pid in $(/system/bin/toybox pidof android.hardware.wifi-service 2>/dev/null); do
    echo "stopping failed Wi-Fi HAL process $pid"
    kill "$pid" 2>/dev/null
done
exit 1
