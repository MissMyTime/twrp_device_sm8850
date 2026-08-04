# Xiaomi 17 Ultra (nezha)

## Device information

| Parameter | Value |
|---|---|
| Product | Xiaomi 17 Ultra |
| Codename | `nezha` |
| Product platform | `canoe` |
| Board platform | `sm8850` |
| Architecture | arm64 |
| Shipping API | 36 |
| Display | 1200 × 2608, 480 dpi |
| Recovery partition | 104857600 bytes (100 MiB), A/B |
| Super partition | 15300820992 bytes (14.25 GiB) |
| Userdata / metadata | F2FS |
| Build target | `twrp_nezha-bp2a-eng` |

## Encryption and security services

Nezha variants carry different secure-element components. The device tree contains the Goodix recovery service and the Thales Weaver/ST54 files required by the final device fix.

| Component | Recovery implementation |
|---|---|
| Default KeyMint | QTI `onekeymint-service-qti` |
| Weaver service assets | Goodix and Thales recovery binaries |
| Secure element assets | Goodix eSE and ST54 support |
| FBE policy | fscrypt policy v2 with wrapped keys |
| Device vold set | `patches/nezha` |

The recovery gate records the detected route as follows:

- `25128PNA1C` or hardware version `5.9.7`: `leica_597`
- `2512BPNDAC` or hardware version `5.9.0`: `normal_590`

The routes use separate startup timing and retry limits before credential verification.

## Final decryption fixes

The following fixes are retained from the final July 15, 2026 Nezha update:

- Thales Weaver recovery service and supporting libraries
- `stm_st54se_gpio.ko` for ST54 secure-element access
- ST54 DAC/SELog safety handling
- KeyMint environment selection based on the installed system version and patch levels
- Key-storage upgrade write-back protection
- Pre-decrypt waiting, failure retry and reboot cleanup hooks
- Recovery settings stored under `/data/recovery/TWRP` instead of vendor persist
- MTP RC-only composite-mode fix, dated July 15, 2026: preserve the MTP FunctionFS ready state and route `mtp` and `twrp_mtp_adb` through `mtp,adb`

## Build

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_nezha-bp2a-eng
mka recoveryimage
```

Output:

```text
out/target/product/nezha/recovery.img
```

The unified build script may also be used:

```bash
twrp_device_sm8850/scripts/build.sh nezha
```

## Flash

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

Use `--slot=a` when `current-slot` reports `a`.

`fastboot boot recovery.img` is not supported because the generated recovery image is ramdisk-only.

## Notes

- `TW_NO_AUTO_DECRYPT := true`: start decryption manually from TWRP when required.
- The Nezha `Decrypt.cpp` and `KeyStorage.cpp` files must remain in `patches/nezha`; do not move them into the common set.
- Reboot cleanup releases recovery-owned secure-element sessions before Android starts.
