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

# Modify default IP
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
# sed -i 's/192.168.1.1/10.10.10.100/g' package/base-files/files/bin/config_generate

# Enable r8125 ASPM
# cp -f $GITHUB_WORKSPACE/010-config.patch package/kernel/r8125/patches/010-config.patch

#Apply the patches
# git apply $GITHUB_WORKSPACE/patches/*.patch

# Update mwan3helper's IP pools
# wget https://raw.githubusercontent.com/Gzxhwq/geoip/release/geoip-only-cn-private.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/all_cn.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/chinanet.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/chinatelecom.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/unicom.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/unicom_cnc.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/cmcc.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/cmcc.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/tietong.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/crtc.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/cernet.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/cernet.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/drpeng.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/gwbn.txt
# wget https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/cstnet.txt -O feeds/luci/applications/luci-app-mwan3helper/root/etc/mwan3helper/othernet.txt

# Change dnsproxy behavior
# sed -i 's/--cache --cache-min-ttl=3600/--cache --cache-min-ttl=600/g' ./feeds/luci/applications/luci-app-turboacc/root/etc/init.d/turboacc


# 1️⃣ 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 2️⃣ 转换中文语言包
curl -sSL https://build-scripts.immortalwrt.eu.org/convert_translation.sh | bash || echo "[WARN] zh-cn -> zh_Hans 转换失败"

# 3️⃣ 创建 LuCI ACL
curl -sSL https://build-scripts.immortalwrt.eu.org/create_acl_for_luci.sh | bash -s - -a || echo "[WARN] LuCI ACL 创建失败"

# 4️⃣ 删除临时文件
rm -rf ./tmp

# 5️⃣ 更新 Golang
rm -rf ./feeds/packages/lang/golang
mkdir -p ./feeds/packages/lang
git clone -b master --single-branch https://github.com/immortalwrt/packages.git packages_master
mv ./packages_master/lang/golang ./feeds/packages/lang/
echo "[INFO] Golang 更新完成"

# 6️⃣ turboacc 自动取消注释
TURBO_FILE="./feeds/luci/applications/luci-app-turboacc/root/etc/init.d/turboacc"
if [ -f "$TURBO_FILE" ]; then
    sed -i 's/^#\(.*turboacc\)/\1/' "$TURBO_FILE"
    echo "[INFO] turboacc 文件取消注释完成"
else
    echo "[WARN] turboacc 文件不存在，跳过 sed"
fi
