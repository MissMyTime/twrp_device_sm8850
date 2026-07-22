# patches/myron — 红米 K90 Pro Max

本机**不需要** `system/vold` 补丁。此目录映射四个已验证的 recovery init 脚本，并包含构建期 CTS 版本白名单补丁；后者只允许已验证镜像使用的 `99.87.36` 版本值通过 Android 16 构建检查，不进入 recovery 运行时。

原因：myron 的默认 KeyMint 使用 QTI 服务，StrongBox/Weaver 使用 NXP 后端。KeyMint 环境值（OS 版本 / 安全补丁级别 / vendor 补丁级别）取自 vendor 属性，recovery 侧伪装的版本号不会进入默认 KeyMint，解密时不会触发密钥升级。6 月基线（原版 vold + Weaver1.cpp）已长期验证稳定。

注意：请勿把 `patches/nezha` 或 `patches/neo8` 的 vold 文件混入本机构建。那套环境切换代码在本机只会编造出不一致的环境，触发 KeyMint 密钥升级，严重时可导致回系统后无法解密。
