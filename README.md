# Qualcomm SM8750 / SM8850 Android 16 TWRP 设备树与源码补丁

> 面向 Xiaomi 与 realme 新平台设备的 TWRP 3.7.1 / Android 16 适配仓库

[![Patch isolation](https://github.com/MissMyTime/twrp_device_sm8850/actions/workflows/patch-isolation.yml/badge.svg)](https://github.com/MissMyTime/twrp_device_sm8850/actions/workflows/patch-isolation.yml)
[![酷安](./.github/assets/coolapk.svg)](https://www.coolapk.com/u/4327352)
[![反馈](./.github/assets/discuss.svg)](https://github.com/MissMyTime/twrp_device_sm8850/issues)

本仓库包含四台设备的完整设备树，以及适配 Android 16 / API 36 / BP2A 所需的 TWRP 源码修改。设备专属的解密、启动和图形栈改动已分开维护，构建时只应用公共补丁与目标机型补丁。

[English documentation](./README_EN.md)

## 支持设备

| 厂商 | 设备 | 代号 | 平台 | Lunch target | 安全后端 | 状态 |
|---|---|---|---|---|---|---|
| Xiaomi | Redmi K90 | `annibale` | `sun` | `twrp_annibale-bp2a-eng` | QTI KeyMint + NXP StrongBox/Weaver | 已适配 |
| Xiaomi | Redmi K90 Pro Max | `myron` | `sm8850 / canoe` | `twrp_myron-myron-eng` | QTI KeyMint + NXP StrongBox/Weaver | 已适配 |
| Xiaomi | Xiaomi 17 Ultra | `nezha` | `sm8850 / canoe` | `twrp_nezha-bp2a-eng` | QTI KeyMint + Thales/Goodix 组件 | 已适配 |
| realme | realme Neo8 | `RE6402L1` | `canoe` | `twrp_RE6402L1-bp2a-eng` | QTI KeyMint + TMS/SPU Weaver | 已适配 |

所有设备均使用 A/B recovery 分区。生成的 `recovery.img` 为 ramdisk-only 镜像，应按当前槽位刷入 `recovery`，不建议使用 `fastboot boot recovery.img` 临时启动。

## 快速开始

### 1. 初始化 TWRP 源码

完整环境准备见 [构建指南](docs/BUILD.md)。以下命令假设 TWRP 源码位于 `~/android/twrp`。

### 2. 将本仓库克隆到 TWRP 源码根目录

```bash
cd ~/android/twrp
git clone https://github.com/MissMyTime/twrp_device_sm8850.git
```

### 3. 同步目标设备树

手动构建时，将目标设备树同步到源码根目录的标准路径：

```bash
cd ~/android/twrp
mkdir -p device/xiaomi/myron
rsync -a twrp_device_sm8850/device/xiaomi/myron/ device/xiaomi/myron/
```

其他设备请将厂商目录和代号替换为表格中的对应值。

### 4. 应用对应机型的源码修改

```bash
cd ~/android/twrp
twrp_device_sm8850/scripts/apply-patches.sh . myron
```

第二个参数支持 `myron`、`annibale`、`nezha`、`RE6402L1` 和 `neo8`。脚本先应用 `patches/common`，再应用目标机型目录，不会加载其他设备的专属修改。

### 5. 编译

手动编译：

```bash
cd ~/android/twrp
source build/envsetup.sh
lunch twrp_myron-myron-eng
m recoveryimage
```

或使用统一脚本。脚本会自动识别厂商目录、同步目标设备树、应用对应补丁并开始编译：

```bash
cd ~/android/twrp
twrp_device_sm8850/scripts/build.sh myron
```

如需显式指定 lunch target，可设置 `LUNCH_TARGET`：

```bash
LUNCH_TARGET=twrp_myron-myron-eng twrp_device_sm8850/scripts/build.sh myron
```

## 刷入

刷入前请确认设备代号正确、Bootloader 已解锁，并备份重要数据。

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot --slot=b flash recovery recovery.img
fastboot reboot recovery
```

示例中的当前槽位为 `b`；如果查询结果为 `a`，请将 `--slot=b` 改为 `--slot=a`。建议先只刷当前槽位，另一槽保留作回退。

不同机型的输出路径为 `out/target/product/<codename>/recovery.img`。

## 仓库结构

```text
twrp_device_sm8850/
├── README.md
├── README_EN.md
├── device/
│   ├── xiaomi/
│   │   ├── annibale/
│   │   ├── myron/
│   │   └── nezha/
│   └── realme/
│       └── RE6402L1/
├── patches/
│   ├── common/              # 全机型公共修改
│   ├── annibale/            # Redmi K90 说明与专属修改
│   ├── myron/               # Redmi K90 Pro Max 说明与专属修改
│   ├── nezha/               # Xiaomi 17 Ultra 解密修改
│   └── neo8/                # realme Neo8 专属 recovery/vold 修改
├── docs/
│   ├── BUILD.md
│   ├── PATCHES.md
│   ├── xiaomi-annibale.md
│   ├── xiaomi-myron.md
│   ├── xiaomi-nezha.md
│   └── realme-neo8.md
└── scripts/
    ├── apply-patches.sh
    ├── build.sh
    └── check-patch-isolation.sh
```

## 补丁划分

- `patches/common`：公共 recovery 框架、分区处理、界面、重启和 Weaver 扩展点。
- `patches/myron`：只包含 Myron 的 MTP 组合模式与密钥升级拒绝保护；不替换完整 vold 文件，不访问系统 keystore 数据库。
- `patches/annibale`：保留 stock vold，不应用其他设备的 KeyMint 环境切换。
- `patches/nezha`：Xiaomi 17 Ultra 的 KeyMint 环境与密钥存储保护。
- `patches/neo8`：realme Neo8 的 TMS/SPU、OPlus Weaver、DRM、init 与 KeyMint 修改。

详细内容见 [补丁说明](docs/PATCHES.md)。仓库的 Patch isolation workflow 会检查公共补丁和各设备目录之间是否出现不应存在的交叉引用。

## 主要功能

- Android 16 FBE 与 metadata encryption 解密
- Weaver、Gatekeeper、KeyMint/StrongBox 支持
- Virtual A/B、动态分区和 A/B recovery 分区
- 刷入 ROM 后自动恢复 TWRP
- MTP、ADB、触摸、亮度、振动和 Wi-Fi 适配
- 解密前等待、失败重试和重启清理钩子

## 设备文档

- [Redmi K90 / annibale](docs/xiaomi-annibale.md)
- [Redmi K90 Pro Max / myron](docs/xiaomi-myron.md)
- [Xiaomi 17 Ultra / nezha](docs/xiaomi-nezha.md)
- [realme Neo8 / RE6402L1](docs/realme-neo8.md)

## 救砖

如果系统能进桌面、但所有应用提示"重启后需等待应用响应"（锁屏钥匙失效导致 /data 解不开），先别急着格式化 data。试试 [spblob-rescue](https://github.com/MissMyTime/spblob-rescue)：在 recovery 里跑一下，把锁屏钥匙切到备用的那把，重启输原来的密码就能解开，数据都在。

## 讨论与反馈

- XDA: [POCO F8 Ultra / Redmi K90 Pro Max (myron)](https://xdaforums.com/t/twrp-3-7-1-for-poco-f8-ultra-redmi-k90-pro-max-myron-android-16-fbe-decrypt.4795272/)
- XDA: [Xiaomi 17 Ultra (nezha)](https://xdaforums.com/t/twrp-3-7-1-for-xiaomi-17-ultra-nezha-android-16-fbe-decrypt.4795275/)
- XDA: [realme Neo8 (RE6402L1)](https://xdaforums.com/t/twrp-3-7-1-for-realme-neo8-re6402l1-android-16-fbe-decrypt.4795276/)
- 4PDA: [realme Neo8 讨论帖](https://4pda.to/forum/index.php?showtopic=1109949)
- GitHub: [Issues](https://github.com/MissMyTime/twrp_device_sm8850/issues)

## 贡献

1. 将完整设备树放入 `device/<vendor>/<codename>/`。
2. 在 `docs/` 增加对应设备说明。
3. 公共源码修改放入 `patches/common/`，设备专属修改放入 `patches/<device>/`。
4. 更新支持设备表，并运行 `scripts/check-patch-isolation.sh`。

## 致谢

- TeamWin Recovery Project
- Android Open Source Project
- Qualcomm 开源项目
