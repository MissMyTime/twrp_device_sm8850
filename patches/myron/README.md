# Myron 专属补丁

本目录只保存 Redmi K90 Pro Max / POCO F8 Ultra (`myron`) 的 recovery 源码覆盖与增量补丁。

## 内容

- `mtp_composite.patch`：使用 Myron 专属 `twrp_mtp_adb` configfs 组合，保证 MTP 开启时 ADB 保持在线。
- `mtp_autostart_after_decrypt.patch`：解密成功后单次启动 MTP；未加密 Data 进入主页后直接启动，不改写用户保存的开关。
- `format_data_guard_ui.patch`：把 Virtual A/B 状态检查和实际 Format Data 拆成两个 GUI 阶段，并按 `none`、`merging` 和需二次确认的状态执行保护。
- `fastbootd_ui.patch`：重启菜单明确显示 Fastbootd，并通过设备脚本写入、复核 BCB 请求。
- `evox_android17_fscrypt_policy.patch`：仅在 Evolution X 17 且现有 fscrypt 策略完全匹配时接受已存在目录。
- `files/.../splash.xml` 与 `splashkoi.png`：Myron 专属双鱼开屏。
- `source-files.map`：把 Myron 的 init 文件映射到 recovery 源码目录，防止构建阶段被上游同名文件覆盖。

设备树中的 WLAN 模块选择、DHCP、FBE 启动链、USB 角色恢复、F2FS、温度读取、EvoX 时间恢复和格式化守卫脚本由 `device/xiaomi/myron` 提供。

## 隔离要求

- 不得复制 Neo8 或 Nezha 的 `Decrypt.cpp`、`KeyStorage.cpp`、Weaver、KeyMint 环境覆盖或启动脚本。
- Myron 保持 QTI KeyMint + NXP StrongBox/Weaver 路线。
- EvoX 兼容不得放宽到其他系统，也不得写回或升级加密密钥。
- Format Data 不得在 recovery 主线程中无超时等待 BootControl 服务。
- Myron 专属 GUI、MTP、Fastbootd 和开屏修改不得进入公共补丁集。
