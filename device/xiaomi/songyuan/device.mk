# Device package definition — Redmi K100 Pro Max / songyuan

DEVICE_PATH := device/xiaomi/songyuan

PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false
PRODUCT_PLATFORM := canoe
PRODUCT_TARGET_VNDK_VERSION := 36
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_VIRTUAL_AB_OTA := true
PRODUCT_PROPERTY_OVERRIDES += persist.sys.fuse.passthrough.enable=true
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

PRODUCT_PACKAGES += \
    fastbootd \
    ip \
    lpdump \
    lpflash \
    mke2fs \
    e2fsck \
    tune2fs \
    resize2fs \
    fsck.f2fs \
    mkfs.f2fs \
    sload_f2fs \
    fsck.erofs \
    songyuan_installer_compat_links \
    sqlite3.recovery \
    strace

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery.fstab:recovery/root/system/etc/recovery.fstab \
    $(DEVICE_PATH)/prebuilt/system/etc/twrp.flags:recovery/root/system/etc/twrp.flags \
    $(DEVICE_PATH)/prebuilt/system/etc/task_profiles.json:recovery/root/system/etc/task_profiles.json \
    $(DEVICE_PATH)/prebuilt/system/etc/event-log-tags:recovery/root/system/etc/event-log-tags \
    $(DEVICE_PATH)/prebuilt/system/etc/vintf/manifest.xml:recovery/root/system/etc/vintf/manifest.xml \
    $(DEVICE_PATH)/prebuilt/system/etc/vintf/compatibility_matrix.device.xml:recovery/root/system/etc/vintf/compatibility_matrix.device.xml

# Keep framework and device VINTF data in their standard partitions.  A main
# manifest is required before libvintf will merge the per-HAL fragments under
# vendor/ and odm/; copying device fragments into the framework directory makes
# servicemanager reject the whole manifest instead.

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root,recovery/root)

# Keep the exact K100PM vendor and ODM stacks.  In particular, retain
# songyuan's own QTI Health binary, init entry and VINTF declaration; replacing
# them with the AOSP example service breaks the device manifest and delays the
# KeyMint/Keystore chain needed by FBE.
SONGYUAN_RECOVERY_VENDOR_COPY_FILES := $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/vendor,recovery/root/vendor)

PRODUCT_COPY_FILES += \
    $(SONGYUAN_RECOVERY_VENDOR_COPY_FILES) \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/vendor_dlkm,recovery/root/vendor_dlkm) \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/odm,recovery/root/odm)

# Keep a ramdisk fallback copy of the exact songyuan/K100PM FocalTech payload.
# The recovery firmware gate prefers the mounted stock ODM copy and accepts this
# copy only when its size matches the verified 148712-byte official image.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/odm/firmware/focaltech_ts_fw_songyuan.bin:recovery/root/vendor/firmware/focaltech_ts_fw_songyuan.bin

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/bin/bash:recovery/root/system/bin/bash \
    $(DEVICE_PATH)/prebuilt/system/bin/se_omapi:recovery/root/system/bin/se_omapi \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-dhcp.sh:recovery/root/system/bin/wifi-dhcp.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-load-modules.sh:recovery/root/system/bin/wifi-load-modules.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/iw:recovery/root/system/bin/iw \
    $(DEVICE_PATH)/prebuilt/system/bin/wpa_cli:recovery/root/system/bin/wpa_cli \
    $(DEVICE_PATH)/prebuilt/vendor/bin/hw/wpa_supplicant:recovery/root/system/bin/wpa_supplicant

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-dhcp.sh:recovery/root/sbin/wifi-dhcp.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-load-modules.sh:recovery/root/sbin/wifi-load-modules.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/iw:recovery/root/sbin/iw \
    $(DEVICE_PATH)/prebuilt/vendor/bin/hw/wpa_supplicant:recovery/root/sbin/wpa_supplicant \
    $(DEVICE_PATH)/prebuilt/vendor/bin/wpa_cli:recovery/root/sbin/wpa_cli \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.wifi.common-V2-ndk.so:recovery/root/sbin/lib64/android.hardware.wifi.common-V2-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.wifi.supplicant-V4-ndk.so:recovery/root/sbin/lib64/android.hardware.wifi.supplicant-V4-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.system.keystore2-V1-ndk.so:recovery/root/sbin/lib64/android.system.keystore2-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/libcert_parse.wpa_s.so:recovery/root/sbin/lib64/libcert_parse.wpa_s.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/libkeystore-engine-wifi-hidl.so:recovery/root/sbin/lib64/libkeystore-engine-wifi-hidl.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/vendor.qti.hardware.wifi.supplicant-V1-ndk.so:recovery/root/sbin/lib64/vendor.qti.hardware.wifi.supplicant-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/vendor.xiaomi.hardware.wifi.supplicant-V1-ndk.so:recovery/root/sbin/lib64/vendor.xiaomi.hardware.wifi.supplicant-V1-ndk.so

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.secure_element-V1-ndk.so:recovery/root/system/lib64/android.hardware.secure_element-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.se.omapi-V1-ndk.so:recovery/root/system/lib64/android.se.omapi-V1-ndk.so
