# Redmi K100 Pro Max (songyuan) source set

This directory contains the source changes used by the verified Songyuan recovery build. They are applied after `patches/common` and must not be reused by another device.

## Scope

- Songyuan FBE preparation and credential-page selection.
- QTI KeyMint upgrade-write protection with the stock OS version and patch level.
- Thales Weaver timeout handling.
- K100PM input force-feedback haptics.
- Songyuan MTP/ADB composite mode and Fastbootd transition guards.
- Touch, navigation, splash and recovery GUI behavior verified on the 1200 x 2608 panel.

`Decrypt.cpp`, `KeyStorage.cpp` and `Weaver1.cpp` are kept in this device set because the Neo8 and Nezha implementations use different security-service stacks. Moving any of them into `patches/common` would make the patch isolation unsafe.

`ota-partitions.txt` is the ordered 58-entry partition list read from the official `OS3.0.306.0.WGNCNXM` payload manifest. The isolation check compares it with `BoardConfig.mk` exactly.
