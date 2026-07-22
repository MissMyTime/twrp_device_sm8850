# BoardConfig.mk — Redmi K90 Pro Max / myron
# TWRP 16 build target on AOSP android-16.0.0_r1
# Android 16 / API 36 / SM8850 / canoe / GKI 2.0 / Virtual A/B
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/myron

# -----------------------------------------------------------------------------
# 0. Build compatibility
# -----------------------------------------------------------------------------

ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := \
    soong-libaosprecovery_defaults \
    soong-libguitwrp_defaults \
    soong-libminuitwrp_defaults \
    soong-vold_defaults

# -----------------------------------------------------------------------------
# 1. Architecture
# Verified:
#   ro.product.cpu.abi=arm64-v8a
#   ro.soc.model=SM8850
#   Oryon runtime CPU family
# -----------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon

ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# -----------------------------------------------------------------------------
# Build against Android 16 (API 36) — device ships with Android 16.
# -----------------------------------------------------------------------------
BOARD_SHIPPING_API_LEVEL := 36

# -----------------------------------------------------------------------------
# 2. Platform identity
# Verified:
#   ro.product.device=myron
#   ro.product.board=canoe
#   ro.board.platform=canoe
#   ro.vendor.qti.soc_model=SM8850
#   ro.vendor.qti.soc_name=canoe
#
# PRODUCT_PLATFORM follows board/product codename: canoe
# TARGET_BOARD_PLATFORM follows QCOM SoC platform: sm8850
# -----------------------------------------------------------------------------
PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := canoe
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840

TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true
TARGET_USES_HARDWARE_QCOM := true
QCOM_BOARD_PLATFORMS += sm8850

# -----------------------------------------------------------------------------
# 3. Kernel / boot image / recovery image
# Verified from unpacked stock images:
#   boot_a.img       : header v4, kernel present, ramdisk size 0
#   init_boot_a.img  : header v4, LZ4 ramdisk
#   vendor_boot_a.img: vendor boot header v4, LZ4 vendor ramdisk, DTB present
#   recovery_a.img   : header v4, kernel_size 0, LZ4 recovery ramdisk only
#
# Dedicated recovery behavior:
#   recovery.img must be ramdisk-only.
#   kernel is loaded from boot_a/boot_b.
#   DTB/vendor ramdisk are loaded from vendor_boot_a/vendor_boot_b.
#   TARGET_PREBUILT_KERNEL is only a build-system placeholder.
# -----------------------------------------------------------------------------
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel

BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

# Verified 2026-06-15 release-image configuration: header and build props use
# the platform 99.87.36 / 2099-12-31 values, same as the June baseline.
BOARD_RECOVERY_MKBOOTIMG_ARGS := $(BOARD_MKBOOTIMG_ARGS)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 99.87.36
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_patch_level 2099-12-31
BOARD_RECOVERY_BUILD_PROP_VERSION_RELEASE := 99.87.36
BOARD_RECOVERY_BUILD_PROP_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := 2099-12-31

BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_ODM_PREBUILT_DIR := $(DEVICE_PATH)/prebuilt/odm
BOARD_RAMDISK_USE_LZ4 := true
BOARD_USES_RECOVERY_AS_BOOT := false

# Real cmdline/bootconfig comes from boot/vendor_boot.
# Keep empty to avoid injecting guessed parameters into ramdisk-only recovery.
BOARD_KERNEL_CMDLINE :=

# -----------------------------------------------------------------------------
# 4. A/B / Virtual A/B
# Verified:
#   slot-count = 2
#   ro.boot.slot_suffix exists
#   lpdump header has virtual_ab_device
#   dedicated recovery_a / recovery_b raw partitions exist
# -----------------------------------------------------------------------------
AB_OTA_UPDATER := true
# Matches the official OS3.0.306.4.WPMCNXM full-OTA payload manifest exactly
# (58 partitions, verified against payload.bin of the official package).
AB_OTA_PARTITIONS += \
    abl \
    aop \
    aop_config \
    bluetooth \
    boot \
    countrycode \
    cpucp \
    cpucp_dtb \
    dcp \
    devcfg \
    dsp \
    dtbo \
    featenabler \
    hyp \
    hyp_ac_config \
    idmanager \
    imagefv \
    init_boot \
    keymaster \
    mi_ext \
    modem \
    modemfirmware \
    multiimgqti \
    odm \
    pdp \
    pdp_cdb \
    product \
    pvmfw \
    qtvm_dtbo \
    qupfw \
    recovery \
    secretkeeper \
    shrm \
    soccp \
    soccp_dcd \
    soccp_debug \
    spuservice \
    system \
    system_dlkm \
    system_ext \
    tme_config \
    tme_fw \
    tme_seq_patch \
    tz \
    tz_ac_config \
    tz_qti_config \
    uefi \
    uefisecapp \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm \
    vm-bootsys \
    xbl \
    xbl_ac_config \
    xbl_config \
    xbl_ramdump

BOARD_RECOVERY_NEEDS_BOOTLOADER_CONTROL := true

# -----------------------------------------------------------------------------
# 5. AVB
# Verified:
#   bootloader unlocked
#   ro.boot.verifiedbootstate=orange
#   ro.boot.vbmeta.device_state=unlocked
#   ro.boot.veritymode=enforcing
# -----------------------------------------------------------------------------
BOARD_AVB_ENABLE := true
# No --rollback_index override: the verified 2026-06-15 image ships index 0,
# and flashing a higher index can permanently block returning to that image.

# -----------------------------------------------------------------------------
# 6. Physical partition sizes
# Verified by fastboot getvar / blockdev / stock image dumps:
#   boot_a        = 100663296
#   init_boot_a   = 8388608
#   vendor_boot_a = 100663296
#   recovery_a    = 104857600
#   dtbo_a        = 33554432
#   vbmeta_a      = 131072
#   super         = 14495514624
# -----------------------------------------------------------------------------
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_VBMETAIMAGE_PARTITION_SIZE := 131072

# -----------------------------------------------------------------------------
# 7. Dynamic partitions / super
# Verified by lpdump:
#   group: qti_dynamic_partitions_a
#   max size: 14485028864
#   logical partitions:
#     system, product, vendor, odm, system_ext, system_dlkm, vendor_dlkm, mi_ext
# -----------------------------------------------------------------------------
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_SUPER_PARTITION_SIZE := 14495514624
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions

BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 14485028864
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    system_dlkm \
    product \
    vendor \
    vendor_dlkm \
    odm

# -----------------------------------------------------------------------------
# 8. Filesystems / partition copy-out
# Verified:
#   system/vendor/product/odm/system_ext/system_dlkm/vendor_dlkm/mi_ext = EROFS
#   userdata = F2FS
#   metadata = F2FS
# -----------------------------------------------------------------------------
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs

BOARD_USES_VENDOR_DLKMIMAGE := true

TARGET_COPY_OUT_SYSTEM := system
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM := odm

BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_METADATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USES_MKE2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# -----------------------------------------------------------------------------
# 9. FBE / metadata encryption / KeyMint
# Verified from fstab.qcom:
#   fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0
#   keydirectory=/metadata/vold/metadata_encryption
#   metadata_encryption=aes-256-xts:wrappedkey_v0
#
# Verified services:
#   android.hardware.security.keymint.IKeyMintDevice/default     — onekeymint-service-qti
#   android.hardware.security.keymint.IKeyMintDevice/strongbox   — keymint3-service.strongbox.nxp
#   android.hardware.gatekeeper.IGatekeeper/default              — gatekeeper-rust-service-qti
#   android.hardware.weaver.IWeaver/default                      — weaver-service.nxp-qti
#   android.system.keystore2.IKeystoreService/default            — keystore2
# -----------------------------------------------------------------------------
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true

TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_CRYPTO_USE_VENDOR_KEYMINT := true

# -----------------------------------------------------------------------------
# 10. Recovery base
# APEX is loaded and working on AOSP 16 TWRP (twrp.apex.loaded=true).
# additional.fstab is used for metadata-encrypted userdata decrypt passthrough.
# -----------------------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
RECOVERY_SDCARD_ON_DATA := true

# -----------------------------------------------------------------------------
# 12. Display / graphics
# Verified:
#   wm size = 1200x2608
#   wm density = 480
#   display modes include 120Hz
#   brightness path = /sys/class/backlight/panel0-backlight/brightness
#   max_brightness = 16383
#   current brightness during verification = 950
# -----------------------------------------------------------------------------
TARGET_SCREEN_WIDTH := 1200
TARGET_SCREEN_HEIGHT := 2608
TARGET_SCREEN_DENSITY := 480

TARGET_USES_VULKAN := true
TARGET_USES_QCOM_SPR := true

TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 16383
TW_DEFAULT_BRIGHTNESS := 950
TW_NO_SCREEN_BLANK := true
TW_SCREEN_BLANK_ON_BOOT := true

TW_CUSTOM_CPU_POS := 72
TW_CUSTOM_CLOCK_POS := 326
TW_CUSTOM_BATTERY_POS := 786
TW_STATUS_ICONS_ALIGN := bottom
TW_NO_AUTO_DECRYPT := true
TW_NO_HAPTICS := false
TW_Y_OFFSET := 0
TW_H_OFFSET := 0

# -----------------------------------------------------------------------------
# 13. Input / touch / haptics
# Verified:
#   focaltech_ts = /dev/input/event7
#   non-touch devices include uinput-xiaomi
#   Haptics use qcom-hv-haptics input FF device.
# -----------------------------------------------------------------------------
TW_CUSTOM_TOUCH_DEVICE := "/dev/input/event7"
TW_INPUT_BLACKLIST := "hbtp_vm:uinput-xiaomi"

TW_NO_LEGACY_PROPS := true

# Enable the TWRP WLAN page. The runtime setup is handled by wlanstart().

# -----------------------------------------------------------------------------
# 14. Storage / tools
# -----------------------------------------------------------------------------
TW_ENABLE_FS_COMPRESSION := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true
TW_INCLUDE_NTFS_3G := true

TW_INCLUDE_7ZA := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_FASTBOOTD := true
TW_USE_TOOLBOX := true
TW_ENABLE_ALL_PARTITION_TOOLS := true
TW_USE_DMCTL := true

# -----------------------------------------------------------------------------
# 15. Battery
# Verified:
#   /sys/class/power_supply/battery exists and is valid through kernel symlink.
# -----------------------------------------------------------------------------
TW_POWER_SUPPLY_BATTERY_PATH := "/sys/class/power_supply/battery"
TW_USE_BATTERY_SYSFS_STATS := true
TW_BATTERY_SYSFS_WAIT_SECONDS := 8

TW_USE_LEGACY_BATTERY_SERVICES := true
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone75/temp"

# -----------------------------------------------------------------------------
# 16. Vendor modules
# Verified source:
#   /vendor/lib/modules -> /vendor_dlkm/lib/modules
#   modules.dep exists under /vendor_dlkm/lib/modules
#
# Ordered by dependency chain:
#   base QMI/GLINK/PDR/RPROC first
#   ADSP/Q6 chain next
#   PCIe/USB/networking next
#   WLAN subsystem
#   PMIC/panel/touch/flash/haptics next
#   secure invoke bridge last
# -----------------------------------------------------------------------------
TW_LOAD_VENDOR_MODULES := "qmi_helpers.ko qcom_glink.ko qcom_glink_smem.ko qcom_smd.ko rproc_qcom_common.ko qcom_pdr_msg.ko pdr_interface.ko qcom_sysmon.ko qcom_q6v5.ko qcom_ramdump.ko qcom_va_minidump.ko qcom_pil_info.ko qcom_q6v5_pas.ko q6_pdr_dlkm.ko q6_notifier_dlkm.ko snd_event_dlkm.ko gpr_dlkm.ko spf_core_dlkm.ko adsp_loader_dlkm.ko q6_dlkm.ko pcie-pdc.ko pci-msm-drv.ko mhi.ko wcd_usbss_i2c.ko usb_f_gsi.ko dwc3-msm.ko repeater.ko redriver.ko ipam.ko gsim.ko rmnet_mem.ko smem-mailbox.ko libarc4.ko rfkill.ko cfg80211.ko mac80211.ko wlan_firmware_service.ko cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko cnss2.ko qca_cld3_peach_v2.ko qti_pmic_glink.ko qti_battery_charger.ko panel_event_notifier.ko gh_irq_lend.ko xiaomi_touch.ko focaltech_touch_3683.ko swr_dlkm.ko mca_sysfs.ko mca_event.ko mca_log.ko mca_parse_dts.ko mca_charge_mievent.ko mca_protocol_class.ko mca_protocol_qc_class.ko mca_platform_bc12_class.ko mca_platform_buckchg_class.ko mca_strategy_class.ko mca_adsp_glink.ko mca_qcom_subpmic_proxy.ko leds-qcom-flash.ko leds-qpnp-vibrator-ldo.ko qcom-hv-haptics.ko swr_haptics_dlkm.ko smcinvoke_dlkm.ko qsee_ipc_irq_bridge.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_PREBUILT_MODULES_AT_FIRST := true

# -----------------------------------------------------------------------------
# 17. Localization / device defaults
# -----------------------------------------------------------------------------
TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true
TW_HAS_EDL_MODE := false
# TW_SUPPORT_INPUT_AIDL_HAPTICS := true
# TW_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_BACKUP_EXCLUSIONS := /data/fonts
TW_DEVICE_VERSION := Redmi_K90_Pro_Max
TW_DEFAULT_TIMEZONE := "Asia/Shanghai"

# -----------------------------------------------------------------------------
# 18. SELinux
# -----------------------------------------------------------------------------
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/private

# -----------------------------------------------------------------------------
# 19. Debug tools
# -----------------------------------------------------------------------------
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

include vendor/twrp/config/BoardConfigTWRP.mk
