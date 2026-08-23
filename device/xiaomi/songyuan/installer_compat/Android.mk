LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := songyuan_installer_compat_links
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/sbin
LOCAL_POST_INSTALL_CMD := \
    mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/sbin; \
    ln -sfn /system/bin/sh $(TARGET_RECOVERY_ROOT_OUT)/sbin/sh; \
    ln -sfn /system/bin/bash $(TARGET_RECOVERY_ROOT_OUT)/sbin/bash; \
    ln -sfn /system/bin/bash $(TARGET_RECOVERY_ROOT_OUT)/sbin/bas; \
    ln -sfn /system/bin/getprop $(TARGET_RECOVERY_ROOT_OUT)/sbin/getprop
include $(BUILD_PHONY_PACKAGE)
