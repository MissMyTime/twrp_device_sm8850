# Redmi K100 Pro Max (songyuan) TWRP

独立的 Redmi K100 Pro Max / `songyuan` TWRP 设备树，基于官方
OS3.0.306.0.WGNCNXM Android 16 固件整理。设备平台为 SM8850/canoe，使用
官方的 Thales Weaver、StrongBox KeyMint、QTI KeyMint/Gatekeeper 和
`focaltech_touch_3685g_1.ko`，不复用其他设备的触摸或解密服务。

## 编译

```bash
source build/envsetup.sh
lunch twrp_songyuan-bp2a-eng
mka recoveryimage
```

输出文件：`out/target/product/songyuan/recovery.img`

## 分区与功能

- 独立 recovery 分区、Virtual A/B 和动态分区。
- Android 16 FBE metadata 加密布局，`/data` 使用官方 f2fs 参数。
- 保留官方 vendor/ODM 安全服务、触摸模块、Wi-Fi 和 USB 相关文件。
- 支持内部存储、metadata、persist、USB-OTG、ADB、MTP 与 fastbootd。

设备刷写前请确认 bootloader 状态、当前槽位和 recovery 分区布局，并保留官方线刷包以便恢复。
