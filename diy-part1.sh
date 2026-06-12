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

# 1. 清理重置原有的大包源，防止衝突
sed -i '/my_packages/d' feeds.conf.default
sed -i '$a src-git my_packages https://github.com/Gzxhwq/openwrt-packages' feeds.conf.default

# 2. 【核心找回】移除官方內置不帶 2 的舊版 Passwall 源，防止編譯名衝突
sed -i '/passwall/d' feeds.conf.default

# 3. 用最標準的 feeds 方式強行注入官方全新的 Passwall2 獨立源
# 這樣在 make download 和編譯時，日誌裡絕對會單獨出現你熟悉的 passwall2
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

# 4. 輔助清理：保證沒有殘留的本地錯位目錄干擾編譯
rm -rf package/others/luci-app-passwall2
rm -rf package/others/luci-app-passwall
