<img width="1920" height="1020" alt="image" src="https://github.com/user-attachments/assets/f8e12059-08cb-4aeb-aa86-d1be8d82380a" /># Qualcomm SM8750 / SM8850 Android 16 TWRP

> 面向 Xiaomi 与 realme 新平台设备的 TWRP 3.7.1 / Android 16 设备树与源码补丁

[![反馈](./.github/assets/discuss.svg)](https://github.com/MissMyTime/twrp_device_sm8850/issues)

本仓库提供完整设备树、公共源码修改和按机型隔离的专属补丁。构建时只应用公共补丁与目标设备补丁，避免不同厂商、不同安全后端的解密和启动配置互相混用。
爱发电自愿打赏：https://www.ifdian.net/a/MissMyTime

## 支持设备

| 设备 | 代号 / 构建参数 | 设备文档 |
| --- | --- | --- |
| Redmi K90 | `annibale` | [查看](docs/xiaomi-annibale.md) |
| Redmi K90 Pro Max / POCO F8 Ultra | `myron` | [查看](docs/xiaomi-myron.md) |
| Xiaomi 17 Ultra | `nezha` | [查看](docs/xiaomi-nezha.md) |
| realme Neo8 | `RE6402L1` / `neo8` | [查看](docs/realme-neo8.md) |

以上设备均使用 A/B recovery 分区。生成的 `recovery.img` 为 ramdisk-only 镜像，应刷入当前槽位的 `recovery` 分区，不建议使用 `fastboot boot recovery.img` 临时启动。

## 快速构建

完整环境要求和手动构建方法见 [构建指南](docs/BUILD.md)。以下命令假设 TWRP 源码位于 `~/android/twrp`：

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/twrp_device_sm8850.git
twrp_device_sm8850/scripts/build.sh myron
```

将 `myron` 替换为目标设备的构建参数。脚本会同步对应设备树，先应用 `patches/common`，再应用目标设备补丁并开始编译。

如需指定 Lunch target：

```bash
LUNCH_TARGET=twrp_myron-myron-eng twrp_device_sm8850/scripts/build.sh myron
```

## 刷入

刷入前请确认设备代号、Bootloader 解锁状态和当前槽位，并提前备份重要数据。

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=a flash recovery recovery.img
fastboot reboot recovery
```

示例使用槽位 `a`；请根据 `current-slot` 的实际结果修改。建议先只刷当前槽位，保留另一槽位用于回退。

## 仓库内容

- Android 16 FBE 与 metadata encryption 适配；
- Weaver、Gatekeeper、KeyMint 和 StrongBox 接口支持；
- Virtual A/B、动态分区与 A/B recovery 支持；
- MTP、ADB、触摸、亮度、振动、Wi-Fi 和重启流程适配；
- 公共补丁与设备专属补丁隔离检查。

具体实现、适用范围和设备差异见：

- [构建指南](docs/BUILD.md)
- [补丁说明](docs/PATCHES.md)
- [Redmi K90 / annibale](docs/xiaomi-annibale.md)
- [Redmi K90 Pro Max / myron](docs/xiaomi-myron.md)
- [Xiaomi 17 Ultra / nezha](docs/xiaomi-nezha.md)
- [realme Neo8 / RE6402L1](docs/realme-neo8.md)

## 数据救援

如果系统能够进入桌面，但所有应用持续提示重启后等待响应，请先不要格式化 Data。可参考 [spblob-rescue](https://github.com/MissMyTime/spblob-rescue) 判断是否属于 Synthetic Password protector 失效问题。

## 讨论与反馈

- [GitHub Issues](https://github.com/MissMyTime/twrp_device_sm8850/issues)
- [POCO F8 Ultra / Redmi K90 Pro Max](https://xdaforums.com/t/twrp-3-7-1-for-poco-f8-ultra-redmi-k90-pro-max-myron-android-16-fbe-decrypt.4795272/)
- [Xiaomi 17 Ultra](https://xdaforums.com/t/twrp-3-7-1-for-xiaomi-17-ultra-nezha-android-16-fbe-decrypt.4795275/)
- [realme Neo8](https://xdaforums.com/t/twrp-3-7-1-for-realme-neo8-re6402l1-android-16-fbe-decrypt.4795276/)
- [realme Neo8 4PDA 讨论帖](https://4pda.to/forum/index.php?showtopic=1109949)

## 贡献

新增或修改设备时，请保持公共补丁和设备专属补丁边界，并运行：

```bash
scripts/check-patch-isolation.sh
```

## 致谢

- TeamWin Recovery Project
- Android Open Source Project
- Qualcomm 开源项目
