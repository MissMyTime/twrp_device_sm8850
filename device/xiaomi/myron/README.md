# Redmi K90 Pro Max / POCO F8 Ultra (myron)

本设备树用于 Myron 的 TWRP 3.7.1 Android 16 构建，目标系统为 HyperOS 3 / Android 16，支持 FBE、动态分区和 Virtual A/B。

## 当前状态

- Recovery：独立 A/B recovery 分区，镜像不包含内核。
- 解密：QTI KeyMint、NXP StrongBox/Weaver、Android 16 FBE。
- 存储：Data/Metadata 使用 F2FS，内部存储按 `/data/media` 处理。
- 连接：ADB、MTP、ADB Sideload、WLAN。
- 硬件：触摸、亮度、振动。
- 刷机：传统 update-binary、官方 A/B OTA、动态分区镜像。

## 2026-07-28 至 2026-07-29 修复

### 解密与存储

- 调整 NXP KeyMint/Weaver 启动顺序，降低官方系统和 AOSP 系统偶发卡解密、密码类型误判的概率。
- 解密成功后直接建立内部存储映射，避免递归扫描 `/data` 导致首页等待。
- 移除重复 USB-OTG 定义，避免内部存储被误显示为 USB-OTG。
- 区分 Data、Internal Storage、Dalvik/ART Cache 等虚拟项目；文件系统操作必须选择真实 Data 分区。
- 保留 Data、Metadata 的 F2FS 检查、修复和格式化工具。

### 安装、动态分区与格式化

- 补齐 `/sbin/sh`、`/sbin/bash`、`/sbin/bas`、`/sbin/getprop` 兼容路径。
- 修复官方 A/B 包成功前提前切换/准备动态分区的问题。
- 安装官方包前后校验 LP 元数据容量；仅对安全的单 Super 布局执行扩容并复核写入结果。
- 刷写 Super 镜像前先解除逻辑分区映射。
- Format Data 先在独立页面检查 Virtual A/B 快照状态，检查线程结束后再由用户确认格式化，避免黑屏和界面锁死。
- 删除重复 Sideload USB 状态触发，避免首次进入 Sideload 时 ADB 连接立即关闭。
- 安装阶段可切换性能策略，结束后恢复默认调度。

### WLAN、显示与振动

- WLAN 优先从当前槽位的 `system_dlkm`、`vendor_dlkm` 加载匹配模块，并保留 recovery 内置模块作为回退。
- DHCP 正确配置 IPv4、默认路由、DNS，并生成 `/tmp/recovery/wifi-dhcp.lease`。
- 修复首次点击异常振动及振动只生效一次的问题。
- 亮度节点使用 `panel0-backlight`，最大值保持真机验证的 `16383`。
- 简体中文界面下 Czech、Greek、Ukrainian 使用稳定英文显示名，语言内容不变。
- 增加 Myron 专属双鱼开屏图标。

## 构建

```bash
cd /root/twrp16
source build/envsetup.sh
lunch twrp_myron-myron-eng
m recoveryimage
```

输出文件：

```text
out/target/product/myron/recovery.img
```

也可以使用仓库脚本：

```bash
scripts/build.sh myron
```

## 刷入

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

当前槽位为 `b` 时，把 `--slot=b` 改为 `--slot=a`。本镜像为 ramdisk-only recovery，不支持 `fastboot boot recovery.img`。

## 维护边界

- Myron 使用 QTI + NXP 安全服务链，禁止套用 Neo8、Nezha 的 vold、KeyMint、Weaver 或启动脚本。
- Format Data 的 Virtual A/B 检查必须保持为独立 GUI 阶段，不能在 recovery 主线程中无限等待 BootControl 服务。
- 更新固件安全补丁级别后，应重新验证 KeyMint、Weaver、WLAN 模块和 FBE 解密。
