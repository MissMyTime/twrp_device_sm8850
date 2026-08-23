# Redmi K90 Pro Max / POCO F8 Ultra (myron)

## Device information

| Parameter | Value |
|---|---|
| Product | Redmi K90 Pro Max / POCO F8 Ultra |
| Codename | `myron` |
| Product platform | `canoe` |
| Board platform | `sm8850` |
| Architecture | arm64 |
| Shipping API | 36 |
| Display | 1200 × 2608, 480 dpi |
| Recovery partition | 104857600 bytes (100 MiB), A/B |
| Super partition | 14495514624 bytes (13.5 GiB) |
| Userdata / metadata | F2FS |
| Build target | `twrp_myron-myron-eng` |

## Encryption

Myron uses QTI KeyMint with NXP StrongBox and Weaver services. The recovery tree preserves this device-specific chain and does not use the Neo8 or Nezha vold implementations.

The recovery starts the secure-element services in the verified order, avoids an early default-password attempt before the Data mapping exists, and creates the media bind only after successful FBE decryption. These changes improve official HyperOS and AOSP compatibility without writing recovery-generated KeyMint upgrades back to user data.

The QTI support libraries and service identities are taken from the official Myron Global vendor image. Evolution X 17 compatibility is limited to accepting an existing fscrypt policy only when the kernel reports an exact byte-for-byte match; it does not replace policies or persist upgraded key blobs.

## Storage and flashing

- Data and Metadata include F2FS check, repair and format tools.
- Internal Storage and Dalvik/ART Cache are treated as virtual wipe entries, not standalone block devices.
- The USB-OTG wildcard parent is hidden while real removable child volumes remain selectable, so multi-partition drives work without an empty storage entry.
- Legacy installers receive `/sbin/sh`, `/sbin/bash`, `/sbin/bas` and `/sbin/getprop` compatibility paths.
- Official A/B packages only prepare the new slot after a successful install.
- LP metadata capacity is checked before and after an OTA. Repair is limited to an undersized, single-device Super layout and is refused while a Virtual A/B update is active.
- Raw Super flashing unmaps dynamic partitions before opening the physical block device.
- Format Data uses a bounded userspace snapshot check followed by a separate explicit confirmation. `none` permits formatting, `merging` always blocks it, and `snapshotted`, `cancelled`, `unknown` or an unrecognized state require the custom-ROM force confirmation.

## Connectivity and hardware

- MTP and ADB use the Myron-only `twrp_mtp_adb` composite mode. MTP starts once after successful decryption, or immediately when Data is not encrypted, without changing the saved user preference.
- Removing an OTG drive restores peripheral mode and rebinds the previous ADB/MTP composition.
- Duplicate Sideload USB property handlers are removed to avoid the first-session disconnect.
- WLAN mounts the active slot's `system_dlkm` and `vendor_dlkm`, loads matching runtime modules when available, and falls back to recovery modules.
- DHCP configures IPv4, the default route and DNS, then publishes a lease state file.
- Brightness uses `/sys/class/backlight/panel0-backlight/brightness` with a verified maximum of `16383`.
- Force-feedback effects are recreated for every vibration request and no unsolicited first-touch probe is emitted.
- CPU temperature uses the verified `thermal_zone68` node.
- Evolution X 17 recovery time is restored from its persisted ATS offset after decryption.
- The Fastbootd menu writes and verifies the recovery BCB request before rebooting to userspace fastboot.
- Fastbootd resolves and labels the current UFS targets at runtime, so flashing `init_boot` does not depend on unstable `/dev/block/sd*` assignments.
- The recovery fstab includes the optional `mi_product` logical partition used by newer HyperOS layouts.
- The Myron theme includes stable language labels and the device-specific koi splash.

## Build

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_myron-myron-eng
m recoveryimage
```

or:

```bash
scripts/build.sh myron
```

## Flash

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

Use `--slot=a` when the active slot is `b`. `fastboot boot recovery.img` is not supported because the image is ramdisk-only.
