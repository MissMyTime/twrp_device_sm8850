#!/system/bin/sh

# Keep Xiaomi authsecretd in recovery's permissive domain while using only the
# stock K100PM ODM binary and libraries.  No foreign-device credential or key
# material is copied or referenced here.
export LD_LIBRARY_PATH=/odm/lib64:/vendor/lib64:/system/lib64
exec /odm/bin/hw/vendor.xiaomi.hardware.authsecretd
