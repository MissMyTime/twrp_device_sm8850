# Product definition — Redmi K100 Pro Max / songyuan

DEVICE_PATH := device/xiaomi/songyuan

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, $(DEVICE_PATH)/device.mk)

PRODUCT_RELEASE_NAME := songyuan
PRODUCT_DEVICE := songyuan
PRODUCT_NAME := twrp_songyuan
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := Redmi K100 Pro Max
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_PLATFORM := canoe
PRODUCT_SHIPPING_API_LEVEL := 36

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="songyuan-user 16 BP2A.250605.031.A3 OS3.0.306.0.WGNCNXM release-keys"

BUILD_FINGERPRINT := Redmi/songyuan/songyuan:16/BP2A.250605.031.A3/OS3.0.306.0.WGNCNXM:user/release-keys
