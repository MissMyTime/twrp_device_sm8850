# patches/neo8 — realme Neo8 (RE6402L1)

本目录为 Neo8 **专用**的 `system/vold` 补丁，**禁止**混入其他设备构建。

背景：Neo8 使用高通 TMS/SPU strongbox + THN31 eSE，搭配 OPlus 自家 weaver 栈（`vendor.weaver_tms`）。其 KeyMint 环境取自 build 属性，而 recovery 出于 FBE 兼容伪装了平台版本（99.87.36 / 2099-12-31），解密 `begin()` 时环境比密钥 blob 新，会反复触发密钥升级。

原理：解密前把 KeyMint 环境（OS 版本 / OS 补丁 / vendor 补丁）压制为已安装系统的真实值（支持 `twrp.keymint.osver/ospatch/venpatch` 属性覆盖），使密钥环境保持一致，不再触发不必要的升级。

本目录内容：

- `files/system/vold/Decrypt.cpp`：KeyMint 环境压制、persist 兼容挂载、TMS Weaver 重启与 keystore2 同步。
- `files/system/vold/KeyStorage.cpp`：`KM_TAG_FBE_ICE` 与升级写回保护。
- `files/bootable/recovery/`：Neo8 专用 DRM、init 与主题构建覆盖。
- MTP 使用公共补丁中的标准 `mtp,adb` configfs 路径，不加载 Myron 的专用组合模式。
- `patches/bootable_recovery/ui_device_overrides.patch`：Neo8 的直接重启、槽位属性回填、WLAN 布局和动态 system 大小规则。
- `patches/system_vold/key_storage_recovery_safety.patch`：KeyStorage 改动的 diff 形式。

这些文件只由 `RE6402L1` / `neo8` 构建应用，不进入 myron、annibale 或 nezha。
