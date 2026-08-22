# Qualcomm SM8750 / SM8850 Android 16 TWRP

> TWRP 3.7.1 / Android 16 device trees and source patches for recent Xiaomi and realme platforms

[![Issues](https://img.shields.io/github/issues/MissMyTime/twrp_device_sm8850)](https://github.com/MissMyTime/twrp_device_sm8850/issues)

This repository provides complete device trees, shared source changes and isolated per-device patches. A build receives only the common patch set and the selected device set, preventing decryption and boot configurations from different vendors or security backends from being mixed.

[中文](./README.md)

## Supported devices

| Device | Codename / build argument | Documentation |
| --- | --- | --- |
| Redmi K90 | `annibale` | [View](docs/xiaomi-annibale.md) |
| Redmi K90 Pro Max / POCO F8 Ultra | `myron` | [View](docs/xiaomi-myron.md) |
| Redmi K100 Pro Max | `songyuan` | [View](docs/xiaomi-songyuan.md) |
| Xiaomi 17 Ultra | `nezha` | [View](docs/xiaomi-nezha.md) |
| realme Neo8 | `RE6402L1` / `neo8` | [View](docs/realme-neo8.md) |

All listed devices use A/B recovery partitions. The generated `recovery.img` is ramdisk-only and should be flashed to the current recovery slot. Temporary boot with `fastboot boot recovery.img` is not recommended.

## Quick build

See the [build guide](docs/BUILD.md) for environment requirements and manual build instructions. The example below assumes the TWRP source tree is located at `~/android/twrp`:

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/twrp_device_sm8850.git
twrp_device_sm8850/scripts/build.sh myron
```

Replace `myron` with the target device argument. The script synchronizes the matching device tree, applies `patches/common`, applies only the selected device patches and starts the build.

To select the Lunch target explicitly:

```bash
LUNCH_TARGET=twrp_myron-myron-eng twrp_device_sm8850/scripts/build.sh myron
```

## Flashing

Verify the device codename, bootloader state and current slot, and back up important data before flashing.

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=a flash recovery recovery.img
fastboot reboot recovery
```

The example uses slot `a`; change it to the value reported by `current-slot`. Flashing only the current slot keeps the other slot available as a fallback.

## Repository scope

- Android 16 FBE and metadata-encryption support;
- Weaver, Gatekeeper, KeyMint and StrongBox interfaces;
- Virtual A/B, dynamic partitions and A/B recovery partitions;
- MTP, ADB, touch, brightness, vibration, Wi-Fi and reboot adaptations;
- isolation checks for shared and device-specific patches.

Implementation details, supported scope and device differences are documented in:

- [Build guide](docs/BUILD.md)
- [Patch documentation](docs/PATCHES.md)
- [Redmi K90 / annibale](docs/xiaomi-annibale.md)
- [Redmi K90 Pro Max / myron](docs/xiaomi-myron.md)
- [Redmi K100 Pro Max / songyuan](docs/xiaomi-songyuan.md)
- [Xiaomi 17 Ultra / nezha](docs/xiaomi-nezha.md)
- [realme Neo8 / RE6402L1](docs/realme-neo8.md)

## Data recovery

If Android reaches the launcher but every app continues to report that it must wait after reboot, do not format Data immediately. See [spblob-rescue](https://github.com/MissMyTime/spblob-rescue) to determine whether the active Synthetic Password protector has failed.

## Discussion and feedback

- [GitHub Issues](https://github.com/MissMyTime/twrp_device_sm8850/issues)
- [POCO F8 Ultra / Redmi K90 Pro Max](https://xdaforums.com/t/twrp-3-7-1-for-poco-f8-ultra-redmi-k90-pro-max-myron-android-16-fbe-decrypt.4795272/)
- [Xiaomi 17 Ultra](https://xdaforums.com/t/twrp-3-7-1-for-xiaomi-17-ultra-nezha-android-16-fbe-decrypt.4795275/)
- [realme Neo8](https://xdaforums.com/t/twrp-3-7-1-for-realme-neo8-re6402l1-android-16-fbe-decrypt.4795276/)
- [realme Neo8 discussion on 4PDA](https://4pda.to/forum/index.php?showtopic=1109949)

## Contributing

Keep shared changes separate from per-device implementations and run:

```bash
scripts/check-patch-isolation.sh
```

## Credits

- TeamWin Recovery Project
- Android Open Source Project
- Qualcomm open-source projects
