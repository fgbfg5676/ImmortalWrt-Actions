#!/bin/bash
set -e
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 0️⃣ 修改默认 IP
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate

# 1️⃣ 更新 feeds 并安装
./scripts/feeds update -a
./scripts/feeds install -a

# 1️⃣a 自动启用 PassWall2
sed -i 's/# CONFIG_PACKAGE_luci-app-passwall2 is not set/CONFIG_PACKAGE_luci-app-passwall2=y/' .config || echo 'CONFIG_PACKAGE_luci-app-passwall2=y' >> .config
make defconfig

# 2️⃣ 转换中文语言包 zh-cn -> zh_Hans
for po in $(find feeds/luci/modules -type f -name 'zh-cn.po'); do
    cp -f "$po" "$(dirname $po)/zh_Hans.po"
done
echo "[INFO] zh-cn -> zh_Hans 转换完成"

# 3️⃣ 创建 LuCI ACL
mkdir -p files/etc/config
cat > files/etc/config/luci_acl <<'EOF'
config internal "admin"
    option password ''
    option username 'admin'
    option read_only '0'
EOF
echo "[INFO] LuCI ACL 创建完成"

# 4️⃣ 删除临时文件
rm -rf ./tmp
echo "[INFO] 临时文件 tmp 已删除"

# 5️⃣ 更新 Golang
rm -rf ./feeds/packages/lang/golang
mkdir -p ./feeds/packages/lang
git clone -b master --single-branch https://github.com/immortalwrt/packages.git packages_master
mv ./packages_master/lang/golang ./feeds/packages/lang/
echo "[INFO] Golang 更新完成"

