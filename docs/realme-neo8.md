# realme Neo8 (RE6402L1 / RMX8899)

## Device Information

| Parameter | Value |
|-------------|-------|
| Device | realme Neo8 |
| Product | RE6402L1 |
| Model | RMX8899 |
| Platform | Qualcomm SM8850 (canoe) |
| Architecture | arm64 |
| Android Version | 16 (BP2A) |
| Shipping API | 36 |
| Recovery Header | v4 |
| Screen | 1080x2354, 474dpi, 120Hz |
| Brightness | 0-4095 (default: 1600) |
| Recovery Partition Size | 104857600 bytes (100 MB) |
| Super Partition Size | 18790481920 bytes (17.5 GB) |
| File System (logical) | EROFS |
| File System (userdata) | F2FS |
| Virtual A/B | Yes (gz compression) |

## Key Features

- **File-based encryption (FBE)** and metadata encryption support
- **OPlus touch service** and touch firmware support
- **WLAN service** with WPA2/WPA3 supplicant handling and status display
- **Explicit physical A/B targets** for image flashing
- **Fastboot / Fastbootd** handling
- **Center punch-hole** and status bar layout adjustments
- **Optional F2FS virtual SD card** partition (`rannki` -> `/SDKa`)

## Partition Table

| Partition | Size | Type | Notes |
|-----------|------|------|-------|
| boot_a / boot_b | 100663296 | Image | Physical A/B targets |
| init_boot_a / init_boot_b | 8388608 | Image | Physical A/B targets |
| vendor_boot_a / vendor_boot_b | 100663296 | Image | Physical A/B targets |
| dtbo_a / dtbo_b | 25165824 | Image | Physical A/B targets |
| vbmeta_a / vbmeta_b | 65536 | Image | Physical A/B targets |
| vbmeta_system_a / vbmeta_system_b | 65536 | Image | Physical A/B targets |
| vbmeta_vendor_a / vbmeta_vendor_b | 65536 | Image | Physical A/B targets |
| recovery_a / recovery_b | 104857600 | Image | Physical A/B targets |
| system | Logical | EROFS | A/B slot, dynamic |
| system_ext | Logical | EROFS | A/B slot, dynamic |
| system_dlkm | Logical | EROFS | A/B slot, dynamic |
| product | Logical | EROFS | A/B slot, dynamic |
| vendor | Logical | EROFS | A/B slot, dynamic |
| vendor_dlkm | Logical | EROFS | A/B slot, dynamic |
| odm | Logical | EROFS | A/B slot, dynamic |
| metadata | - | F2FS | Encryption key storage |
| userdata | - | F2FS | Data + FBE |
| misc | - | EMMC | Boot control |
| persist | - | EXT4 | Persist partition |

The image list deliberately avoids unsuffixed `boot`, `recovery` and `vbmeta`
aliases. This keeps image flashing independent of a missing or late slot
property. The `super` entry is created by TWRP's dynamic-partition manager and
is not duplicated in `twrp.flags`.

## FBE / Decryption

| Parameter | Value |
|-----------|-------|
| FBE Policy | `fscrypt_policy_v2` |
| Keymaster | Vendor Keymint (QTI) |
| OMAPI | Enabled (`636F6D2E6E78702E7365637572697479`) |
| StrongBox / Weaver | TMS secure-element services (`vendor.weaver_tms`) with SPU support components |
| SELinux | Permissive in recovery |

## Prebuilt Components

### `prebuilt/kernel/`

Prebuilt kernel image (Image, boot header v4).

### `prebuilt/odm/firmware/secure_ta/`

TrustZone / Secure TA firmware blobs for keymint, weaver, crypto, FIDO, etc.

### `prebuilt/sbin/`

- `neo8_wifi_hal_client`: Wi-Fi HAL client for recovery
- `wifi-dhcp.sh`: DHCP script for Wi-Fi
- `wifi-load-modules.sh`: Kernel module loader for Wi-Fi
- `vendor/etc/vintf/`: Wi-Fi supplicant manifest

### `prebuilt/system/`

- Boot service (recovery variant)
- Health service (recovery variant)
- SELinux policy contexts
- VINTF manifests

### `prebuilt/vendor/`

- Boot service
- Gatekeeper (Rust + legacy)
- Health service
- Keymint (onekeymint)
- Secretkeeper
- `init` scripts, `ueventd.rc`
- Firmware, firmware_mnt, vintf, Wi-Fi config
- `lib` / `lib64` libraries
- `odm` overlay

### `prebuilt/system_ext/`

System extension prebuilts for recovery.

## Recovery Init Scripts

| Script | Purpose |
|--------|---------|
| `init.recovery.qcom.rc` | Qualcomm platform init, service start, property setup |
| `init.recovery.usb.rc` | USB configuration, MTP, ADB, fastbootd |
| `ueventd.qcom.rc` | Device node permissions |
| `system/bin/neo8-early-mount.sh` | Early mount helper |
| `system/bin/neo8-partition-links.sh` | Partition alias links |
| `system/bin/neo8-touch-props.sh` | Touch properties setup |

## Touch Stack

OPlus touch service integration:

- `vendor.oplus.hardware.touch` AIDL HAL
- TensorFlow Lite touch model
- Touch firmware config (`synaptics` / `fts` depending on variant)

## Wi-Fi

- WPA2/WPA3 supplicant workflow
- DHCP client with fallback
- Status display in TWRP UI
- WCN7750/WPSS module loading via `wifi-load-modules.sh`
- Up to 45 seconds for a cold firmware start before reporting failure
- Runtime executable-mode repair for `neo8_wifi_hal_client`

`neo8_wifi_hal_client` is also stored as an executable in Git. The loader
repairs the mode at runtime because Android `PRODUCT_COPY_FILES` can install a
prebuilt helper as `0644` in the recovery ramdisk.

## Sepolicy

- `file_contexts`: Recovery file context labels
- `recovery.te`: Recovery-specific SELinux rules

## Build

```bash
source build/envsetup.sh
lunch twrp_RE6402L1-bp2a-eng
mka recoveryimage
```

Output: `out/target/product/RE6402L1/recovery.img`

## Flash

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

Use `--slot=a` when `current-slot` reports `a`.

> **Note:** `fastboot boot recovery.img` (temporary boot) is **not supported** on this
> device. The recovery image is ramdisk-only (kernel is in `vendor_boot`); most
> SM8850 bootloaders will reject booting it directly. Flash the A/B recovery
> partition for the selected slot; temporary boot is not supported.

## Known Issues / Notes

- `TW_NO_AUTO_DECRYPT := true` — decryption must be triggered manually.
- `TW_SKIP_POST_GUI_FSTAB_SETUP := true` — fstab is set up before GUI.
- `TW_FORCE_STOCK_THEME_ON_BOOT := true` — forces stock theme at boot to avoid UI corruption.
- `TW_SKIP_ADDITIONAL_FSTAB := true` — skips additional fstab overlay.
- `TW_HAS_EDL_MODE := false` — no EDL mode entry in TWRP.
- The reboot page falls back to `ro.boot.slot_suffix` and `ro.boot.slot` when
  the recovery backend has not populated `tw_active_slot`.
- `/SDKa` is shown only when `/dev/block/by-name/rannki` exists and contains
  an F2FS filesystem.

## Device Tree Path

```
device/realme/RE6402L1/
├── AndroidProducts.mk
├── BoardConfig.mk
├── device.mk
├── recovery.fstab
├── recovery/
│   └── root/
│       ├── init.recovery.qcom.rc
│       ├── init.recovery.usb.rc
│       ├── ueventd.qcom.rc
│       └── system/bin/
│           ├── neo8-early-mount.sh
│           ├── neo8-partition-links.sh
│           └── neo8-touch-props.sh
├── prebuilt/
│   ├── kernel
│   ├── odm/firmware/secure_ta/
│   ├── sbin/
│   ├── system/
│   ├── system_ext/
│   └── vendor/
├── sepolicy/
├── system.prop
├── twrp_RE6402L1.mk
└── vendorsetup.sh
```
