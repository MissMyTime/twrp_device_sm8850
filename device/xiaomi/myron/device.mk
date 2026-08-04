# device.mk — Redmi K90 Pro Max / myron
# TWRP 16 on AOSP android-16.0.0_r1
# Android 16 / API 36 / SM8850 / canoe / Virtual A/B
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/myron

# -----------------------------------------------------------------------------
# Platform
# -----------------------------------------------------------------------------
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false


PRODUCT_PLATFORM := canoe
PRODUCT_TARGET_VNDK_VERSION := 36

# -----------------------------------------------------------------------------
# Dynamic partitions / Virtual A/B
# -----------------------------------------------------------------------------
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_VIRTUAL_AB_OTA := true

# -----------------------------------------------------------------------------
# Emulated storage / FUSE passthrough
# -----------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.fuse.passthrough.enable=true

# -----------------------------------------------------------------------------
# Soong namespace
# -----------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH) \
    external/lptools

# -----------------------------------------------------------------------------
# Recovery tools
# -----------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    fastbootd \
    ip \
    lpdump \
    lpflash \
    lpmake \
    lpunpack \
    mke2fs \
    e2fsck \
    tune2fs \
    resize2fs \
    fsck.f2fs \
    mkfs.f2fs \
    sload_f2fs \
    fsck.erofs \
    strace \
    tzdata_prebuilt

# -----------------------------------------------------------------------------
# Recovery fstab
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery.fstab:recovery/root/system/etc/recovery.fstab \
    $(DEVICE_PATH)/prebuilt/system/bin/bash:recovery/root/system/bin/bash

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/etc/twrp.flags:recovery/root/system/etc/twrp.flags \
    $(DEVICE_PATH)/prebuilt/system/etc/task_profiles.json:$(TARGET_COPY_OUT_SYSTEM)/etc/task_profiles.json \
    $(DEVICE_PATH)/prebuilt/system/etc/task_profiles.json:recovery/root/system/etc/task_profiles.json \
    $(DEVICE_PATH)/prebuilt/system/etc/event-log-tags:recovery/root/system/etc/event-log-tags \
    $(DEVICE_PATH)/prebuilt/system/etc/vintf/manifest.xml:recovery/root/system/etc/vintf/manifest.xml \
    $(DEVICE_PATH)/prebuilt/system/etc/vintf/compatibility_matrix.device.xml:recovery/root/system/etc/vintf/compatibility_matrix.device.xml

# -----------------------------------------------------------------------------
# Recovery root overlay (init*.rc files)
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/recovery/root,recovery/root)

# -----------------------------------------------------------------------------
# Device-specific additional.fstab for metadata encryption decrypt
#
# The running twrp_17pm.img confirms additional.fstab is still needed
# for fs_mgr metadata decrypt passthrough with wrapped_key_v0.
#
# Also symlinked as /system/etc/fstab.qcom for OrangeFox backward compat.
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/etc/additional.fstab:recovery/root/system/etc/additional.fstab \
    $(DEVICE_PATH)/prebuilt/system/etc/additional.fstab:recovery/root/system/etc/fstab.qcom

# -----------------------------------------------------------------------------
# se_omapi (OMAPI secure element HAL service)
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/bin/se_omapi:recovery/root/system/bin/se_omapi

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-dhcp.sh:recovery/root/system/bin/wifi-dhcp.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-load-modules.sh:recovery/root/system/bin/wifi-load-modules.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/myron-evox-mtp-keeper.sh:recovery/root/system/bin/myron-evox-mtp-keeper.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/myron-evox-time-fix.sh:recovery/root/system/bin/myron-evox-time-fix.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/myron-reboot-fastbootd.sh:recovery/root/system/bin/myron-reboot-fastbootd.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/myron-usb-role-recover.sh:recovery/root/system/bin/myron-usb-role-recover.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/twrp-vab-format-guard.sh:recovery/root/system/bin/twrp-vab-format-guard.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/wpa_cli:recovery/root/system/bin/wpa_cli \
    $(DEVICE_PATH)/prebuilt/system/bin/iw:recovery/root/system/bin/iw

# TWRP can mount the real /system and /vendor while browsing partitions. Keep
# the recovery WiFi userspace under /sbin so it remains visible.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-dhcp.sh:recovery/root/sbin/wifi-dhcp.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/wifi-load-modules.sh:recovery/root/sbin/wifi-load-modules.sh \
    $(DEVICE_PATH)/prebuilt/system/bin/iw:recovery/root/sbin/iw \
    $(DEVICE_PATH)/prebuilt/vendor/bin/hw/wpa_supplicant:recovery/root/sbin/wpa_supplicant \
    $(DEVICE_PATH)/prebuilt/vendor/bin/wpa_cli:recovery/root/sbin/wpa_cli \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.security.keymint-V1-ndk.so:recovery/root/sbin/lib64/android.hardware.security.keymint-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.wifi.common-V2-ndk.so:recovery/root/sbin/lib64/android.hardware.wifi.common-V2-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.wifi.supplicant-V4-ndk.so:recovery/root/sbin/lib64/android.hardware.wifi.supplicant-V4-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.system.keystore2-V1-ndk.so:recovery/root/sbin/lib64/android.system.keystore2-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/libcert_parse.wpa_s.so:recovery/root/sbin/lib64/libcert_parse.wpa_s.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/libkeystore-engine-wifi-hidl.so:recovery/root/sbin/lib64/libkeystore-engine-wifi-hidl.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/libnl.so:recovery/root/sbin/lib64/libnl.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/vendor.qti.hardware.wifi.supplicant-V1-ndk.so:recovery/root/sbin/lib64/vendor.qti.hardware.wifi.supplicant-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/vendor.xiaomi.hardware.wifi.supplicant-V1-ndk.so:recovery/root/sbin/lib64/vendor.xiaomi.hardware.wifi.supplicant-V1-ndk.so

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini:recovery/root/vendor/firmware/wlan/qca_cld/peach_v2/WCNSS_qcom_cfg.ini

# se_omapi is installed under /system/bin, so its AIDL NDK dependencies must
# also be visible in /system/lib64 during recovery.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.hardware.secure_element-V1-ndk.so:recovery/root/system/lib64/android.hardware.secure_element-V1-ndk.so \
    $(DEVICE_PATH)/prebuilt/vendor/lib64/android.se.omapi-V1-ndk.so:recovery/root/system/lib64/android.se.omapi-V1-ndk.so

# -----------------------------------------------------------------------------
# Touch config
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/prebuilt/system/etc/touch/myron_fts_thp_config.ini:recovery/root/system/etc/touch/myron_fts_thp_config.ini

# -----------------------------------------------------------------------------
# Vendor blobs → recovery/root/vendor/
#
# Includes:
#   vendor/bin/hw/*          — KeyMint, Gatekeeper, Boot, Health, SE, Secretkeeper
#   vendor/bin/qseecomd      — QSEEComm daemon
#   vendor/bin/hlosminkdaemon— MinK daemon
#   vendor/lib64/*           — HAL dependency libraries
#   vendor/etc/vintf/*       — VINTF manifests (version 9.0)
#   vendor/etc/vintf/manifest_sm8850.xml — platform-specific TWRP keymaster detection
#   vendor/etc/init/*        — Service init scripts
#   vendor/firmware_mnt/*    — QSEE TA firmware images
#   vendor/etc/gpfspath_oem_config.xml — GP firmware path
#   vendor/etc/ueventd.rc    — Udev config
#   vendor/etc/touch/*       — Touch THP config
#   vendor/lib/modules/*.ko  — Kernel modules
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/vendor,recovery/root/vendor)

# -----------------------------------------------------------------------------
# Vendor DLKM modules
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/vendor_dlkm,recovery/root/vendor_dlkm)

# -----------------------------------------------------------------------------
# ODM blobs → recovery/root/odm/
#
# Direct copy to /odm/ (matching the running twrp_17pm.img layout).
# The init.rc creates symlinks for stock path compatibility:
#   /odm/bin      -> /odm/bin
#   /odm/etc      -> /odm/etc
#   /odm/lib64    -> /odm/lib64
#
# Includes:
#   odm/bin/hw/*             — NXP StrongBox KeyMint, Weaver, Vibrator HALs
#   odm/lib64/*              — NXP keymint transport, weaver, touch libs
#   odm/etc/init/*           — StrongBox NXP, Weaver NXP inits
#   odm/firmware/*           — FocalTech touch firmware + THP config
#   odm/etc/vintf/manifest/* — StrongBox + Weaver VINTF
# -----------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(DEVICE_PATH)/prebuilt/odm,recovery/root/odm)
