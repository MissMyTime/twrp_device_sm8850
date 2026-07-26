# realme Neo8（RE6402L1 / RMX8899）

本目录为 realme Neo8 的 TWRP 设备树。平台为 Qualcomm SM8850（canoe），构建目标为 `twrp_RE6402L1-bp2a-eng`。

## 设备专属配置

- 镜像刷入列表直接使用 `boot_a` / `boot_b`、`recovery_a` / `recovery_b` 等物理 A/B 分区节点，不依赖无后缀槽位别名。
- `super` 与逻辑分区继续使用 TWRP 的标准动态分区映射流程，`twrp.flags` 不重复创建 `super` 项。
- 支持 `rannki` F2FS 虚拟 SD 卡，存在时挂载到 `/SDKa`。
- 当 recovery 后端没有写入 `tw_active_slot` 时，从 `ro.boot.slot_suffix` 或 `ro.boot.slot` 回填当前槽位。
- WLAN 加载器为 WCN7750/WPSS 冷启动等待最多 45 秒，并在 Android 构建系统将预编译文件权限压成 `0644` 时恢复 `neo8_wifi_hal_client` 的执行权限。
- 保留 Neo8 专属的 QTI KeyMint、TMS/SPU Weaver、OPlus 兼容层、DRM、触摸与 recovery init 配置。

## 镜像分区

`recovery/root/system/etc/twrp.flags` 显示以下物理 A/B 镜像目标：

- `boot_a` / `boot_b`
- `init_boot_a` / `init_boot_b`
- `vendor_boot_a` / `vendor_boot_b`
- `recovery_a` / `recovery_b`
- `dtbo_a` / `dtbo_b`
- `vbmeta_a` / `vbmeta_b`
- `vbmeta_system_a` / `vbmeta_system_b`
- `vbmeta_vendor_a` / `vbmeta_vendor_b`

## 构建

```bash
./scripts/apply-patches.sh /path/to/twrp-source RE6402L1

cd /path/to/twrp-source
source build/envsetup.sh
lunch twrp_RE6402L1-bp2a-eng
m recoveryimage
```

生成文件位于 `out/target/product/RE6402L1/recovery.img`。

详细的设备参数、解密链和刷入说明见 [Neo8 设备文档](../../../docs/realme-neo8.md)。
