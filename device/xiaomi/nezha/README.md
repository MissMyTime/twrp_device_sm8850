# Xiaomi 17 Ultra / nezha TWRP 设备树改动说明

本设备树用于 Xiaomi 17 Ultra / nezha 的 TWRP 3.7.1 Android 16 适配。

## 当前状态

- 基础功能：可启动 TWRP，触摸、亮度、解密、MTP、ADB、振动均已适配。
- 分区形态：独立 A/B recovery 分区。
- 目标系统：HyperOS 3 / Android 16，FBE metadata 加密，动态分区，Virtual A/B。
- 保留 2026-07-15 的 Nezha 最终解密修复：双路线启动时序、Goodix/Thales 组件、ST54 支持和密钥升级写回保护。
- 保留 2026-07-15 的 MTP RC-only 修复：不在组合模式切换时清除 MTP FunctionFS 就绪状态，并将 `mtp`、`twrp_mtp_adb` 统一到 `mtp,adb`。

## 构建说明

在 `~/android/twrp` 下执行：

```bash
source build/envsetup.sh
lunch twrp_nezha-bp2a-eng
m recoveryimage
```

输出文件：

```text
out/target/product/nezha/recovery.img
```

## 注意事项

- 刷入命令应使用：

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

如果当前槽位为 `a`，请将 `--slot=b` 改为 `--slot=a`。
