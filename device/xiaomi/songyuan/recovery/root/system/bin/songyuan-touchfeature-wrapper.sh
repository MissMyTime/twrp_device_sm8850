#!/system/bin/sh

# The installed ODM is mounted with stock SELinux labels that are not mapped
# by recovery's compact policy.  Enter the permissive recovery domain via this
# ramdisk wrapper, then execute the unchanged K100PM touch HAL as the system
# user selected by its init service.
export LD_LIBRARY_PATH=/odm/lib64:/vendor/lib64:/system/lib64
exec /odm/bin/hw/vendor.xiaomi.hw.touchfeature-service
