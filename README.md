# SM8850 TWRP Device Trees & Source Changes

TWRP device trees and source changes for Qualcomm SM8850 (canoe) platform devices.

**Android 16 / API 36 / BP2A / Virtual A/B**

## Devices

| Vendor | Device | Codename | Status |
|--------|--------|----------|--------|
| Xiaomi | Redmi K90 | annibale | Supported |
| Xiaomi | Redmi K90 Pro Max | myron | Supported |
| Xiaomi | Xiaomi 17 Ultra | nezha | Supported |
| realme | realme Neo8 | RE6402L1 | Supported |

## Repository Layout

```
TWRP-SM8850/
├── README.md                          # This file
├── docs/                              # Device-specific documentation
│   ├── BUILD.md                       # Build guide (WSL2, dependencies)
│   ├── PATCHES.md                     # Source change descriptions
│   ├── xiaomi-annibale.md
│   ├── xiaomi-myron.md
│   ├── xiaomi-nezha.md
│   └── realme-neo8.md
├── device/                            # Device trees
│   ├── qcom/
│   │   └── sm8850-common/             # (Future) Common SM8850 board config
│   ├── xiaomi/
│   │   ├── annibale/                  # Redmi K90 device tree
│   │   ├── myron/                     # Redmi K90 Pro Max device tree
│   │   └── nezha/                     # Xiaomi 17 Ultra device tree
│   └── realme/
│       └── RE6402L1/                  # realme Neo8 device tree
├── source_changes/                    # TWRP source modifications
│   ├── files/                         # Modified source files (full copies)
│   │   ├── bootable/recovery/...
│   │   └── system/vold/...
│   └── patches/                       # Git patches for upstream tracking
│       ├── bootable_recovery/
│       └── system_vold/
└── scripts/
    ├── apply-patches.sh               # Apply source changes to TWRP tree
    └── build.sh                       # Unified build entry script
```

## Quick Start

### Clone this repository alongside your TWRP source tree

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/TWRP-SM8850.git
```

### Apply source changes

```bash
cd ~/android/twrp
TWRP-SM8850/scripts/apply-patches.sh .
```

### Build for a specific device

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_RE6402L1-eng
mka recoveryimage
```

Or use the convenience script:

```bash
cd ~/android/twrp
TWRP-SM8850/scripts/build.sh RE6402L1 realme
```

## Build Requirements

- WSL2 + Ubuntu 24.04 (recommended)
- 64GB+ RAM or swap recommended
- 200GB+ free disk space
- See [docs/BUILD.md](docs/BUILD.md) for full environment setup.

## Source Changes Summary

See [docs/PATCHES.md](docs/PATCHES.md) for detailed descriptions.

### bootable/recovery
- **Slot detection fix** (`twinstall.cpp`): Corrects Virtual A/B slot detection logic.
- **Auto-reflash TWRP** (`action.cpp`): Backs up recovery before flashing ROM, restores to both slots after.
- **Bootloader message clear** (`twrp-functions.cpp`): Prevents bootloop by clearing bootloader message before reboot.
- **Fastboot reboot fix** (`twrp-functions.cpp`): Fixes `rb_fastboot` to use correct bootloader property.
- **UI/Theme adjustments**: Language strings, layout, status bar positioning for center punch-hole devices.
- **Partition handling**: Virtual A/B alias support, dynamic partition flashing fixes.
- **Wi-Fi support** (myron/Neo8): Recovery Wi-Fi framework, supplicant, DHCP client.
- **ST54 null pointer crash fix** (`partition.cpp`, `gui.cpp`): Fixes nullptr crash when initializing ST54 secure element on neZha (Xiaomi 17 Ultra) devices.
- **SELog guard fix**: Suppresses spurious SELinux denials for ST54 DAC access during recovery boot, prevents early boot hangs.

### system/vold
- **FBE / Weaver compatibility**: Android 16 FBE decryption and Weaver/Keymaster compatibility.
- **ST54 key storage safety patch** (`KeyStorage.cpp`, `Decrypt.cpp`): Adds null checks and safety guards for ST54 weaver key access, fixes decryption failures on neZha devices.
- **Thales weaver recovery support**: Adds userspace helper for Thales strongbox keymint/weaver service used on Xiaomi SM8850 neZha.

## Device-specific Notes

Each device has its own documentation in `docs/` covering:
- Partition table and sizes
- FBE / Keymaster / Weaver status
- Known issues and workarounds
- Prebuilt binary notes (keymint, weaver, touch, etc.)

## Contributing

When adding a new device:
1. Create `device/<vendor>/<codename>/` with the full device tree.
2. Add `docs/<vendor>-<codename>.md` with device parameters.
3. If new source changes are required, place them in `source_changes/`.
4. Update this `README.md` device table.

## License

See individual device trees and source files for their respective licenses.
