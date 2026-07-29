# SM8850 / SM8750 通用 recovery 补丁

本目录只保存所有受支持设备都能安全复用的 recovery 框架修改。设备专属的 KeyMint、Weaver、MTP、主题和启动逻辑必须放在 `patches/<device>/` 或对应设备树中。

## 通用 recovery 文件

`files/bootable/recovery/` 包含以下公共修复：

- Android 16 FBE、解密后存储映射和可选设备脚本钩子。
- Data、Metadata 的 F2FS 检查、修复与格式化支持。
- Internal Storage、Dalvik/ART Cache 等虚拟清除项目的文件系统操作保护。
- 传统安装器的 `/sbin/sh`、`bash`、`bas`、`getprop` 兼容路径。
- 官方 A/B 安装成功状态处理、LP/Super 容量检查与安全修复。
- 刷写 Super 镜像前解除动态分区映射。
- 安装阶段性能策略切换及结束后恢复。
- 通用 WLAN、ADB、MTP、亮度、振动和重启框架。

## 增量补丁

- `bootable_recovery/0002-nullptr-crash-fix.patch`：存储分区查找失败时的空指针保护。
- `bootable_recovery/language_display_names.patch`：Czech、Greek、Ukrainian 使用稳定英文显示名，避免简体中文字体缺字。
- `system_vold/system_vold.patch`：Android 16 Weaver 服务等待与重试。
- `external_*`、`system_extras`：recovery 工具的 Soong 命名空间和目标端构建规则。

## 设备隔离

公共 recovery 只调用以下固定名称的可选设备脚本：

- `/system/bin/twrp-pre-decrypt.sh`
- `/system/bin/twrp-decrypt-retry.sh`
- `/system/bin/twrp-reboot-cleanup.sh`

公共目录不得包含具体机型、厂商安全服务或专属分区规则。Myron 的 `twrp_mtp_adb`、Format Data 页面和双鱼开屏均位于 `patches/myron/`，不会影响其他设备。
