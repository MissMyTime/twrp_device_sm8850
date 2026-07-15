# Xiaomi 17 Ultra (nezha)
Xiaomi SM8850 (canoe) platform device tree for Xiaomi 17 Ultra.

## Key Fixes
- ST54 secure element DAC initialization null pointer crash fix
- SELinux log (SELog) guard for ST54 DAC access, prevents early recovery boot hang
- Thales strongbox weaver/keymint recovery service support
- Key storage safety patches for Android 16 FBE decryption
- Prebuilt ST54 GPIO kernel module included

## Status
- FBE decryption: Working
- Touch/Display: Working
- Secure element/Weaver: Working (with ST54 fixes)
- MTP/ADB: Working

See [realme-neo8.md](realme-neo8.md) for full documentation template.
