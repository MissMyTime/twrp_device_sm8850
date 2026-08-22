#!/system/bin/sh

# The Android 16 vendor executable has a policy type unknown to the compact
# recovery policy when logical vendor is mounted.  Enter recovery through this
# ramdisk wrapper, then execute the original K100PM Gatekeeper unchanged.
export LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/hw:/odm/lib64:/system/lib64
exec /vendor/bin/hw/android.hardware.gatekeeper-rust-service-qti
