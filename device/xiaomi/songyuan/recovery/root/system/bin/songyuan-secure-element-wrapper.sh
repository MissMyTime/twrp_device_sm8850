#!/system/bin/sh

# Run the unchanged K100PM QTI secure-element HAL from the permissive recovery
# domain.  Include the stock hw library directory because mounted HyperOS
# vendor places libEseUtils.so there, while the recovery ramdisk also carries a
# top-level fallback copy.
export LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/hw:/odm/lib64:/system/lib64
exec /vendor/bin/hw/android.hardware.secure_element-service.qti
