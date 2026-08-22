#!/system/bin/sh

# The installed K100PM ODM is mounted with stock SELinux labels that are not
# present in recovery's compact policy.  Starting the Thales binary directly
# from init therefore resolves its label to "unlabeled" and enforcing init
# refuses execve().  Enter the permissive recovery domain through this ramdisk
# wrapper, then execute the unchanged K100PM Weaver service with its stock
# vendor/ODM libraries.
export LD_LIBRARY_PATH=/odm/lib64:/vendor/lib64:/system/lib64
exec /odm/bin/hw/android.hardware.weaver-service.thales
