# BoardConfig.mk — Redmi K100 Pro Max / songyuan
# TWRP recovery target for Android 16 / SM8850 (canoe)

DEVICE_PATH := device/xiaomi/songyuan

ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := \
    soong-libaosprecovery_defaults \
    soong-libguitwrp_defaults \
    soong-libminuitwrp_defaults \
    soong-vold_defaults

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon
BOARD_SHIPPING_API_LEVEL := 36

PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := canoe
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true
TARGET_USES_HARDWARE_QCOM := true
QCOM_BOARD_PLATFORMS += sm8850

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RECOVERY_MKBOOTIMG_ARGS := $(BOARD_MKBOOTIMG_ARGS)
# Match the installed K100PM OS3.0.306.0.WGNCNXM environment exactly. A
# recovery header/build spoof can make QTI KeyMint irreversibly upgrade
# Synthetic Password key blobs.
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 16.0.0
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_patch_level 2026-07-01
BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS += --prop com.android.build.boot.os_version:16.0.0
BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS += --prop com.android.build.boot.security_patch:2026-07-01
BOARD_RECOVERY_BUILD_PROP_VERSION_RELEASE := 16
BOARD_RECOVERY_BUILD_PROP_SECURITY_PATCH := 2026-07-01
VENDOR_SECURITY_PATCH := 2026-08-01
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_KERNEL_CMDLINE :=

AB_OTA_UPDATER := true
# Matches the official OS3.0.306.0.WGNCNXM full-OTA payload manifest exactly
# (58 partitions, verified directly from the Songyuan payload.bin manifest).
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
BOARD_AVB_ENABLE := true

BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_VBMETAIMAGE_PARTITION_SIZE := 131072

BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_SUPER_PARTITION_SIZE := 14495514624
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 14485028864
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext system_dlkm product vendor vendor_dlkm odm

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

BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_CRYPTO_USE_VENDOR_KEYMINT := true

TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/config.fs
TARGET_RECOVERY_ODM_PREBUILT_DIR := $(DEVICE_PATH)/prebuilt/odm
TARGET_RECOVERY_USB_RC := $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
RECOVERY_SDCARD_ON_DATA := true

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

# Keep the status row on the verified 1200 x 2608 coordinates instead of
# relying on portrait_hdpi auto-placement.
TW_CUSTOM_CPU_POS := 72
TW_CUSTOM_CLOCK_POS := 326
TW_CUSTOM_BATTERY_POS := 786
TW_STATUS_ICONS_ALIGN := bottom
TW_Y_OFFSET := 0
TW_H_OFFSET := 0

TW_CUSTOM_TOUCH_DEVICE := "/dev/input/event7"
TW_INPUT_BLACKLIST := "hbtp_vm:uinput-xiaomi"
# The official 148712-byte songyuan firmware reports the correct orientation;
# do not add a recovery-side X/Y flip.
TW_NO_LEGACY_PROPS := true
TW_NO_AUTO_DECRYPT := true
TW_NO_HAPTICS := false
# K100PM live recovery logs identify /dev/input/event6 as qcom-hv-haptics.
# Its vendor FF ABI requires custom_len=6 and a persistent uploaded effect;
# custom_len=3 or erase/re-upload returns success but produces an empty slot.
TW_SUPPORT_INPUT_FF_HAPTICS := true
TW_SUPPORT_INPUT_FF_HAPTICS_K100PM := true
TW_INCLUDE_BOOTSTRAP_LINKER := true

TW_ENABLE_FS_COMPRESSION := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_7ZA := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPTOOLS := true
TW_EXCLUDE_LPTOOLS := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_FASTBOOTD := true
TW_USE_TOOLBOX := true
TW_ENABLE_ALL_PARTITION_TOOLS := true
TW_USE_DMCTL := true
TW_EXCLUDE_NANO := true

TW_POWER_SUPPLY_BATTERY_PATH := "/sys/class/power_supply/battery"
TW_USE_BATTERY_SYSFS_STATS := true
TW_BATTERY_SYSFS_WAIT_SECONDS := 8
TW_USE_LEGACY_BATTERY_SERVICES := true
# zone0/1 are fixed 95 C hardware trip thresholds and zone77 is quiet_therm.
# Report the live pa_therm1 sensor instead of a fixed trip-point zone.
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone75/temp"

# The list follows the K100PM vendor_dlkm/modules.load order and uses the
# focaltech module shipped by the songyuan package.
TW_LOAD_VENDOR_MODULES := "qmi_helpers.ko qcom_glink.ko qcom_glink_smem.ko qcom_smd.ko rproc_qcom_common.ko qcom_pdr_msg.ko pdr_interface.ko qcom_sysmon.ko qcom_q6v5.ko qcom_ramdump.ko qcom_va_minidump.ko qcom_pil_info.ko qcom_q6v5_pas.ko q6_pdr_dlkm.ko q6_notifier_dlkm.ko snd_event_dlkm.ko gpr_dlkm.ko spf_core_dlkm.ko adsp_loader_dlkm.ko q6_dlkm.ko pcie-pdc.ko pci-msm-drv.ko mhi.ko wcd_usbss_i2c.ko usb_f_gsi.ko dwc3-msm.ko repeater.ko redriver.ko ipam.ko gsim.ko rmnet_mem.ko smem-mailbox.ko cfg80211.ko mac80211.ko wlan_firmware_service.ko cnss_prealloc.ko cnss_utils.ko cnss_nl.ko cnss_plat_ipc_qmi_svc.ko cnss2.ko qca_cld3_peach_v2.ko qca_cld3_wcn7750.ko qti_pmic_glink.ko qti_battery_charger.ko panel_event_notifier.ko gh_irq_lend.ko xiaomi_touch.ko focaltech_touch_3685g_1.ko swr_dlkm.ko mca_sysfs.ko mca_event.ko mca_log.ko mca_parse_dts.ko mca_charge_mievent.ko mca_protocol_class.ko mca_protocol_qc_class.ko mca_platform_bc12_class.ko mca_platform_buckchg_class.ko mca_strategy_class.ko mca_adsp_glink.ko mca_qcom_subpmic_proxy.ko leds-qcom-flash.ko leds-qpnp-vibrator-ldo.ko qcom-hv-haptics.ko swr_haptics_dlkm.ko smcinvoke_dlkm.ko qsee_ipc_irq_bridge.ko stm_st54se_gpio.ko stm_nfc_i2c.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_PREBUILT_MODULES_AT_FIRST := true

TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true
TW_HAS_EDL_MODE := false
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
TW_BACKUP_EXCLUSIONS := /data/fonts
TW_DEVICE_VERSION := Redmi_K100_Pro_Max
TW_DEFAULT_TIMEZONE := "Asia/Shanghai"

BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd strace ip
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/ip
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libiprouteutil.so
RECOVERY_LIBRARY_SOURCE_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libnetlink.so

include vendor/twrp/config/BoardConfigTWRP.mk
