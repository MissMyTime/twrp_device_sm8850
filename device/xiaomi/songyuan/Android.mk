LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),songyuan)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
