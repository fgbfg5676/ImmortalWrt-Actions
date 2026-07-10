#!/bin/bash
set -e

# -------------------- 基礎變量 --------------------
WGET_OPTS="-q --timeout=30 --tries=3 --retry-connrefused --connect-timeout 10"
ARCH="armv7"
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
BOARD_DIR="$PWD/board"
CUSTOM_PLUGINS_DIR="$PWD/package/custom"
mkdir -p "$DTS_DIR" "$BOARD_DIR" "$CUSTOM_PLUGINS_DIR"

# -------------------- DTS補丁 --------------------
DTS_PATCH_URL="https://git.ix.gs/mptcp/openmptcprouter/commit/a66353a01576c5146ae0d72ee1f8b24ba33cb88e.patch"
DTS_PATCH_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts.patch"
TARGET_DTS="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"

wget $WGET_OPTS -O "$DTS_PATCH_FILE" "$DTS_PATCH_URL"

if [ ! -f "$TARGET_DTS" ]; then
    patch -p1 < "$DTS_PATCH_FILE"
fi

# -------------------- 設備規則 --------------------
if ! grep -q "define Device/mobipromo_cm520-79f" "$GENERIC_MK"; then
    cat <<EOF >> "$GENERIC_MK"

define Device/mobipromo_cm520-79f
  \$(call Device/FitImage)
  DEVICE_VENDOR := MobiPromo
  DEVICE_MODEL := CM520-79F
  DEVICE_DTS := qcom-ipq4019-cm520-79f
  KERNEL_SIZE := 4096k
  KERNEL_LOADADDR := 0x80208000
  ROOTFS_SIZE := 26624k
  IMAGE_SIZE := 32768k
  DEVICE_PACKAGES := \\
    ath10k-firmware-qca4019-ct \\
    kmod-ath10k-ct-smallbuffers
  IMAGE/trx := append-kernel | pad-to \$(KERNEL_SIZE) | append-rootfs | trx-nand-edgecore-ecw5211 \\
    -F 0x524D424E -N 1000 -M 0x2 -C 0x2 -I 0x2 -V "U-Boot 2012.07" -e 0x80208000 -i /dev/mtd10 \\
    -a 0x80208000 -n "Kernel" -d /dev/mtd11 -c "Rootfs" | trx-header -s 16384 -o \$@
endef
TARGET_DEVICES += mobipromo_cm520-79f
EOF
fi

# -------------------- 網絡配置 --------------------
NETWORK_FILE="$BOARD_DIR/02_network"
cat > "$NETWORK_FILE" <<'EOF'
#!/bin/sh
. /lib/functions/system.sh
ipq40xx_board_detect() {
    local machine
    machine=$(board_name)
    case "$machine" in
        "mobipromo,cm520-79f")
            ucidef_set_interfaces_lan_wan "eth1" "eth0"
            ;;
    esac
}
boot_hook_add preinit_main ipq40xx_board_detect
EOF
chmod +x "$NETWORK_FILE"

# -------------------- 修改默認 LAN IP --------------------
NEW_LAN_IP="192.168.3.1"
CONFIG_GENERATE_FILE="package/base-files/files/bin/config_generate"

if [ -f "$CONFIG_GENERATE_FILE" ]; then
    sed -i "s/192\.168\.1\.1/$NEW_LAN_IP/g" "$CONFIG_GENERATE_FILE"
fi

# -------------------- 外圍應用處理 --------------------
# 确保 CUSTOM_PLUGINS_DIR 有默认值
CUSTOM_PLUGINS_DIR="${CUSTOM_PLUGINS_DIR:-package/custom}"

PLUGIN_LIST=("luci-app-partexp")
PLUGIN_REPOS=("https://github.com/sirpdboy/luci-app-partexp.git")

for i in "${!PLUGIN_LIST[@]}"; do
    PLUGIN_NAME="${PLUGIN_LIST[$i]}"
    PLUGIN_URL="${PLUGIN_REPOS[$i]}"
    PLUGIN_PATH="$CUSTOM_PLUGINS_DIR/$PLUGIN_NAME"

    if [ ! -d "$PLUGIN_PATH/.git" ]; then
        echo "INFO: Cloning $PLUGIN_NAME..."
        # 彻底移除末尾的 log_error 函数，改用 Linux 标准的报错退出机制
        git clone --depth=1 "$PLUGIN_URL" "$PLUGIN_PATH"
        echo "SUCCESS: Plugin $PLUGIN_NAME cloned successfully"
    else
        echo "INFO: $PLUGIN_NAME already exists, skipping clone"
    fi

    if [ ! -d "package/$PLUGIN_NAME" ]; then
        cp -r "$PLUGIN_PATH" package/
        echo "SUCCESS: Plugin $PLUGIN_NAME copied to package/"
    fi

    if ! grep -q "CONFIG_PACKAGE_$PLUGIN_NAME=y" .config 2>/dev/null; then
        echo "CONFIG_PACKAGE_$PLUGIN_NAME=y" >> .config
        echo "SUCCESS: $PLUGIN_NAME enabled"
    else
        echo "INFO: $PLUGIN_NAME already enabled, skipping"
    fi
done

# -------------------- OpenClash 内核硬核注入 --------------------
echo "INFO: Starting OpenClash core injection..."

# 1. 强行创建精准的内核存放缓存路径
mkdir -p package/feeds/luci/luci-app-openclash/root/etc/openclash/core

# 2. 动态抓取官方 Release 页面中最新发布的、实打实存在的压缩包名字和直链
# 不再写死任何 v0.xx 或是 alpha-xxx 版本号，彻底告别过时问题
echo "INFO: Fetching latest core link from GitHub..."
LATEST_URL=$(curl -s https://api.github.com/repos/vernesong/OpenClash/releases | grep "browser_download_url" | grep "clash-linux-armv7.tar.gz" | head -n 1 | cut -d '"' -f 4)

# 3. 安全断言：如果通过 API 拿到了链接才下载，拿不到则自动启动高可用备用方案
if [ -n "$LATEST_URL" ]; then
    echo "INFO: Downloading latest core from: $LATEST_URL"
    curl -fL -o package/feeds/luci/luci-app-openclash/root/etc/openclash/core/clash.tar.gz "$LATEST_URL"
else
    echo "WARNING: GitHub API limit reached, using direct master backup link..."
    curl -fL -o package/feeds/luci/luci-app-openclash/root/etc/openclash/core/clash.tar.gz "https://raw.githubusercontent.com/vernesong/OpenClash/master/core-latest/dev/clash-linux-armv7.tar.gz"
fi

# 4. 进入目录解压并正确重命名
cd package/feeds/luci/luci-app-openclash/root/etc/openclash/core/
tar -zxf clash.tar.gz

# 确保文件名最终叫 clash，完美适配 OpenClash 识别机制
if [ -f "clash-linux-armv7" ]; then
    mv clash-linux-armv7 clash
elif [ -f "clash" ]; then
    echo "INFO: Core filename is already 'clash'"
fi

rm -f clash.tar.gz
cd -

# 5. 强行赋予执行权限
chmod +x package/feeds/luci/luci-app-openclash/root/etc/openclash/core/*

echo "SUCCESS: OpenClash latest alpha/beta core injected successfully!"
