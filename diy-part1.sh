#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 1. 建立存放外部插件的自定義目錄
mkdir -p package/others

# 2. 拉取大包源（100%保留原版路徑，用 clone 代替 submodule）
if [ ! -d "package/others/my_packages" ]; then
    git clone --depth 1 https://github.com/Gzxhwq/openwrt-packages.git package/others/my_packages
fi

# 3. 拉取 PassWall2 核心源碼（100%保留原版路徑，用 clone 代替 submodule）
if [ ! -d "package/others/luci-app-passwall2" ]; then
    git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/others/luci-app-passwall2
fi
