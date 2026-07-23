# Qualcomm SM8750 / SM8850 Android 16 TWRP Device Trees and Source Patches

> TWRP 3.7.1 device trees for recent Xiaomi and realme platforms

[![Patch isolation](https://github.com/MissMyTime/twrp_device_sm8850/actions/workflows/patch-isolation.yml/badge.svg)](https://github.com/MissMyTime/twrp_device_sm8850/actions/workflows/patch-isolation.yml)
[![Issues](https://img.shields.io/github/issues/MissMyTime/twrp_device_sm8850)](https://github.com/MissMyTime/twrp_device_sm8850/issues)

This repository contains four complete device trees and the TWRP source changes required for Android 16 / API 36 / BP2A. Device-specific decryption, startup and graphics changes are isolated so each build receives only the common patch set and its own device patch set.

[中文说明](./README.md)

## Supported devices

| Vendor | Device | Codename | Platform | Lunch target | Security backend | Status |
|---|---|---|---|---|---|---|
| Xiaomi | Redmi K90 | `annibale` | `sun` | `twrp_annibale-bp2a-eng` | QTI KeyMint + NXP StrongBox/Weaver | Supported |
| Xiaomi | Redmi K90 Pro Max | `myron` | `sm8850 / canoe` | `twrp_myron-myron-eng` | QTI KeyMint + NXP StrongBox/Weaver | Supported |
| Xiaomi | Xiaomi 17 Ultra | `nezha` | `sm8850 / canoe` | `twrp_nezha-bp2a-eng` | QTI KeyMint + Thales/Goodix components | Supported |
| realme | realme Neo8 | `RE6402L1` | `canoe` | `twrp_RE6402L1-bp2a-eng` | QTI KeyMint + TMS/SPU Weaver | Supported |

All four devices use A/B recovery partitions. The generated `recovery.img` is ramdisk-only and should be flashed to `recovery` for the current slot; temporary boot with `fastboot boot recovery.img` is not recommended.

## Quick start

### 1. Prepare the TWRP source tree

See the full [build guide](docs/BUILD.md). The commands below assume the source tree is located at `~/android/twrp`.

### 2. Clone this repository into the TWRP source root

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/twrp_device_sm8850.git
```

### 3. Synchronize the target device tree

For a manual build, copy the selected tree into its standard path under the source root:

```bash
cd ~/android/twrp
mkdir -p device/xiaomi/myron
rsync -a twrp_device_sm8850/device/xiaomi/myron/ device/xiaomi/myron/
```

Replace the vendor directory and codename for other devices.

### 4. Apply the source changes for one device

```bash
cd ~/android/twrp
twrp_device_sm8850/scripts/apply-patches.sh . myron
```

The device argument accepts `myron`, `annibale`, `nezha`, `RE6402L1` and `neo8`. The script applies `patches/common` first and then only the selected device set.

### 5. Build

Manual build:

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_myron-myron-eng
m recoveryimage
```

Or use the unified build script. It detects the vendor directory, synchronizes the selected device tree, applies the matching patches and starts the build:

```bash
cd ~/android/twrp
twrp_device_sm8850/scripts/build.sh myron
```

Set `LUNCH_TARGET` to select the lunch target explicitly:

```bash
LUNCH_TARGET=twrp_myron-myron-eng twrp_device_sm8850/scripts/build.sh myron
```

## Flashing

Verify the device codename, unlock the bootloader and back up important data before flashing.

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

The example assumes slot `b`. Use `--slot=a` when `current-slot` reports `a`. Flashing only the current slot leaves the other slot available as a fallback.

Build output is written to `out/target/product/<codename>/recovery.img`.

## Repository layout

```text
twrp_device_sm8850/
├── README.md
├── README_EN.md
├── device/
│   ├── xiaomi/
│   │   ├── annibale/
│   │   ├── myron/
│   │   └── nezha/
│   └── realme/
│       └── RE6402L1/
├── patches/
│   ├── common/              # Shared recovery changes
│   ├── annibale/            # Redmi K90 notes and device changes
│   ├── myron/               # Redmi K90 Pro Max notes and device changes
│   ├── nezha/               # Xiaomi 17 Ultra decryption changes
│   └── neo8/                # realme Neo8 recovery/vold changes
├── docs/
│   ├── BUILD.md
│   ├── PATCHES.md
│   ├── xiaomi-annibale.md
│   ├── xiaomi-myron.md
│   ├── xiaomi-nezha.md
│   └── realme-neo8.md
└── scripts/
    ├── apply-patches.sh
    ├── build.sh
    └── check-patch-isolation.sh
```

## Patch scope

- `patches/common`: shared recovery framework, partition handling, UI, reboot and Weaver extension points.
- `patches/myron`: Myron-only MTP composite handling and a fail-closed key-upgrade guard; no complete vold replacement or persistent keystore access.
- `patches/annibale`: stock vold; no KeyMint environment switching from another device.
- `patches/nezha`: Xiaomi 17 Ultra KeyMint environment and key-storage protection.
- `patches/neo8`: realme Neo8 TMS/SPU, OPlus Weaver, DRM, init and KeyMint changes.

See [PATCHES.md](docs/PATCHES.md) for details. The Patch isolation workflow checks that common and per-device directories do not acquire cross-device implementations.

## Main features

- Android 16 FBE and metadata-encryption decryption
- Weaver, Gatekeeper and KeyMint/StrongBox support
- Virtual A/B, dynamic partitions and A/B recovery partitions
- Automatic TWRP restore after a ROM flash
- MTP, ADB, touch, brightness, vibration and Wi-Fi adaptations
- Pre-decrypt waiting, failure retry and reboot-cleanup hooks

## Device documentation

- [Redmi K90 / annibale](docs/xiaomi-annibale.md)
- [Redmi K90 Pro Max / myron](docs/xiaomi-myron.md)
- [Xiaomi 17 Ultra / nezha](docs/xiaomi-nezha.md)
- [realme Neo8 / RE6402L1](docs/realme-neo8.md)

## Unbricking

If the system boots to the launcher but every app says "not responding, wait after reboot" (the lock-screen key blob is dead and /data cannot be decrypted), don't wipe data yet. Try [spblob-rescue](https://github.com/MissMyTime/spblob-rescue): run it in recovery to switch the lock-screen key to the backup one, reboot, unlock once with your normal password and your data is back.

## Discussion and feedback

- XDA: [POCO F8 Ultra / Redmi K90 Pro Max (myron)](https://xdaforums.com/t/twrp-3-7-1-for-poco-f8-ultra-redmi-k90-pro-max-myron-android-16-fbe-decrypt.4795272/)
- XDA: [Xiaomi 17 Ultra (nezha)](https://xdaforums.com/t/twrp-3-7-1-for-xiaomi-17-ultra-nezha-android-16-fbe-decrypt.4795275/)
- XDA: [realme Neo8 (RE6402L1)](https://xdaforums.com/t/twrp-3-7-1-for-realme-neo8-re6402l1-android-16-fbe-decrypt.4795276/)
- 4PDA: [realme Neo8 discussion thread](https://4pda.to/forum/index.php?showtopic=1109949)
- GitHub: [Issues](https://github.com/MissMyTime/twrp_device_sm8850/issues)

## Contributing

1. Add the complete device tree under `device/<vendor>/<codename>/`.
2. Add its device document under `docs/`.
3. Put shared changes in `patches/common/` and device-specific changes in `patches/<device>/`.
4. Update the supported-device table and run `scripts/check-patch-isolation.sh`.

## Credits

- TeamWin Recovery Project
- Android Open Source Project
- Qualcomm open-source projects
