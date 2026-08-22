# Redmi K90 / annibale TWRP 设备树改动说明

本设备树用于 Redmi K90 / annibale 的 TWRP 3.7.1 Android 16 适配。

## 当前状态

- 基础功能：可启动 TWRP，触摸、亮度、解密、MTP、ADB、振动均已适配。
- 分区形态：独立 A/B recovery 分区。
- 目标系统：HyperOS 3 / Android 16，FBE metadata 加密，动态分区，Virtual A/B。

## 本地编译

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_annibale-bp2a-eng
m recoveryimage
```

输出文件：

```text
out/target/product/annibale/recovery.img
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
