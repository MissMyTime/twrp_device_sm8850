# Source Changes (Patches) Reference

This document describes the purpose of each source modification under `patches/`.

Patches are grouped by scope:

- `patches/common/` — applied to **all four devices**. Recovery framework changes plus the Weaver retry adjustment.
- `patches/<device>/` — applied **only** when building that device. `neo8` contains its recovery framework and KeyMint overrides; `nezha` contains its KeyMint implementation; `myron` contains its MTP, Format Data UI guard and splash overrides; `annibale` keeps stock vold.

`scripts/apply-patches.sh <twrp-source> <codename>` always applies `common` first, then the codename's own directory.

## Common Patch Files (`patches/common/patches/`)

### `bootable_recovery/0002-nullptr-crash-fix.patch`

| File | Change Description |
|------|-------------------|
| `twrp-functions.cpp` | Null-pointer guard in `TWFunc::Init_Recovery` when the current storage partition is not found (avoids a crash on devices where the storage lookup fails early). |

### `bootable_recovery/language_display_names.patch`

Uses stable English display names for Czech, Greek and Ukrainian so the language list remains readable with the Simplified Chinese recovery font. Translation contents are unchanged.

### `system_vold/system_vold.patch`

| File | Change Description |
|------|-------------------|
| `Weaver1.cpp` | Android 16 FBE / Weaver compatibility adjustment. Fixes interaction with Qualcomm Keymaster/Weaver HAL for file-based encryption decryption in recovery. |

## Per-device Patch Files

### `patches/neo8/patches/bootable_recovery/ui_device_overrides.patch`

Neo8-only direct reboot flow, WLAN layout coordinates and dynamic system-size rule. The Neo8 DRM implementation, recovery init files and GUI build file are also stored under `patches/neo8/files/bootable/recovery/`.

### `patches/myron/patches/bootable_recovery/mtp_composite.patch`

Myron-only `twrp_mtp_adb` configfs switching, which keeps ADB online while MTP is enabled. Common recovery and the other devices use the standard `mtp,adb` path.

### `patches/myron/patches/bootable_recovery/format_data_guard_ui.patch`

Runs the bounded Virtual A/B snapshot check on an isolated GUI page and requires a second explicit confirmation before formatting Data. This avoids nesting Format Data in the command worker thread.

### `patches/myron/files/bootable/recovery/gui/theme/portrait_hdpi/`

Myron-only koi splash resources.

### `patches/neo8/patches/system_vold/key_storage_recovery_safety.patch`

| File | Change Description |
|------|-------------------|
| `KeyStorage.cpp` | Adds the `KM_TAG_FBE_ICE` tag required by QTI wrapped keys and recovery-side protection around key upgrade write-back. Part of the KeyMint environment fix for realme Neo8 (QCOM TMS/SPU + OPlus weaver stack). |

### `patches/nezha/patches/system_vold/key_storage_recovery_safety.patch`

Same content as the neo8 patch, for Xiaomi 17 Ultra (Thales/Goodix stack); the copy is kept separate so each device can evolve independently.

## Full File Copies

Each `patches/<set>/files/` directory contains complete modified source files intended to be copied directly over the upstream TWRP source tree. These are the same changes expressed as full file replacements rather than diffs.

### `patches/common/files/bootable/recovery/`

Contains the full modified recovery framework used by the supported SM8750/SM8850 devices, including:
- Core recovery logic (`partition.cpp`, `partitionmanager.cpp`, `twrp.cpp`, `twrp-functions.cpp`)
- GUI framework (`action.cpp`, `gui.cpp`, `theme/`)
- Build system extension points (`Android.mk`, `libguitwrp_defaults.go`)

Device-specific implementations are not stored in the common file set. Recovery invokes optional device scripts through the generic `twrp-pre-decrypt.sh`, `twrp-decrypt-retry.sh` and `twrp-reboot-cleanup.sh` names.

### `patches/common/files/system/vold/Weaver1.cpp`

Weaver HAL retry/wait adjustment, needed by all four devices regardless of secure-element stack.

### `patches/neo8/files/system/vold/` and `patches/nezha/files/system/vold/`

`Decrypt.cpp` + `KeyStorage.cpp`: before decryption, pin the KeyMint environment (OS version / OS patch level / vendor patch level) to the installed system's real values, so the recovery's spoofed platform version (`99.87.36` / `2099-12-31`) is not treated as a newer environment that would trigger a KeyMint key upgrade on every boot. Values can be overridden via `twrp.keymint.osver/ospatch/venpatch`.

**Do not apply these to myron/annibale.** Their default KeyMint services are QTI, while StrongBox/Weaver use NXP backends. Myron has its own non-switching safety baseline; Annibale retains its validated stock vold path.

## How to Apply

Use the provided script:
```bash
./scripts/apply-patches.sh /path/to/twrp-source <codename>
```

For each set, the script first copies its maintained full files to establish an exact baseline, then applies any incremental Git patches. The common set is completed before the selected device set.
