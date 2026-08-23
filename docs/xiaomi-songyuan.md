# Redmi K100 Pro Max / songyuan

本设备树用于 Redmi K100 Pro Max 的 TWRP 3.7.1 Android 16 构建，基线固件为 `OS3.0.306.0.WGNCNXM`。

## 设备状态

- 独立 A/B recovery 分区，生成 ramdisk-only `recovery.img`。
- Android 16 FBE metadata 加密，支持图案、PIN 和密码识别。
- 使用 Songyuan 官方 QTI KeyMint、Gatekeeper、Thales StrongBox/Weaver 服务链。
- 使用官方 `focaltech_touch_3685g_1.ko` 与 148712 字节触摸固件，不使用 recovery 坐标翻转。
- 支持 ADB、MTP、WLAN、USB-OTG、Fastbootd、亮度和输入 FF 振动。
- 官方完整包中的 58 个 A/B OTA 分区已逐项写入 `AB_OTA_PARTITIONS`。
- 安全服务链就绪前不会尝试无锁屏默认凭据；无密码、图案、PIN 和密码路径使用同一套官方服务链。
- Fastbootd 可识别 `init_boot` 和 `pvmfw`，并按稳定的 by-name 路径为 UFS 分区设置标签。
- 旧版刷机脚本可使用 `/sbin/sh`、`/sbin/bash`、`/sbin/bas` 和 `/sbin/getprop`。
- USB-OTG 进入主机模式时会先释放 ADB/MTP gadget，避免大文件复制期间反复复位 U 盘。

## 构建

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/twrp_device_sm8850.git
twrp_device_sm8850/scripts/build.sh songyuan
```

手动构建：

```bash
source build/envsetup.sh
lunch twrp_songyuan-bp2a-eng
m recoveryimage
```

输出文件：

```text
out/target/product/songyuan/recovery.img
```

## 安全边界

- Recovery 头和构建属性使用系统真实的 Android 16 与安全补丁级别，不使用 `99.87.36` 或 `2099-12-31` 伪装。
- `KeyStorage.cpp` 拒绝接受和写回 KeyMint 返回的升级 blob，防止 recovery 改写系统 Synthetic Password 密钥链。
- Songyuan 的 `Decrypt.cpp`、`KeyStorage.cpp`、Weaver 等源码只位于 `patches/songyuan`，不得替换为 Neo8 或 Nezha 的实现。
- 更新底包后需要重新核对安全补丁级别、触摸固件、WLAN 模块和官方 OTA 分区清单。

## 刷入

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=a flash recovery recovery.img
fastboot reboot recovery
```

示例使用槽位 `a`；请按 `current-slot` 的实际结果修改。该镜像不建议使用 `fastboot boot recovery.img` 临时启动。
