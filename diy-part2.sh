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
PLUGIN_LIST=("luci-app-partexp")
PLUGIN_REPOS=("https://github.com/sirpdboy/luci-app-partexp.git")

for i in "${!PLUGIN_LIST[@]}"; do
    PLUGIN_NAME="${PLUGIN_LIST[$i]}"
    PLUGIN_URL="${PLUGIN_REPOS[$i]}"
    PLUGIN_PATH="$CUSTOM_PLUGINS_DIR/$PLUGIN_NAME"

    if [ ! -d "$PLUGIN_PATH/.git" ]; then
        log_info "Cloning $PLUGIN_NAME..."
        git clone --depth 1 "$PLUGIN_URL" "$PLUGIN_PATH" || log_error "Failed to clone $PLUGIN_NAME"
        log_success "Plugin $PLUGIN_NAME cloned successfully"
    else
        log_info "$PLUGIN_NAME already exists, skipping clone"
    fi

    if [ ! -d "package/$PLUGIN_NAME" ]; then
        cp -r "$PLUGIN_PATH" package/
        log_success "Plugin $PLUGIN_NAME copied to package/"
    fi

    if ! grep -q "CONFIG_PACKAGE_$PLUGIN_NAME=y" .config 2>/dev/null; then
        echo "CONFIG_PACKAGE_$PLUGIN_NAME=y" >> .config
        log_success "$PLUGIN_NAME enabled"
    else
        log_info "$PLUGIN_NAME already enabled, skipping"
    fi
done

# 1. 注入你需要的插件配置
echo "CONFIG_PACKAGE_luci-app-partexp=y" >> .config
echo "CONFIG_PACKAGE_luci-app-passwall2=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y" >> .config

# 2. 【核心】在源码包下载完成并开始编译前，强行在插件目录里创建 core 文件夹
mkdir -p package/feeds/luci/luci-app-openclash/root/etc/openclash/core

# 3. 【核心】从官方下载对应你路由器的 armv7 独立二进制内核，直接重命名放入该目录
# 注意：这一步直接使用 -f 参数。如果网络断开或 404，GitHub Actions 会在这一行直接明明白白报错，绝不扯到别的插件上。
curl -fL -o package/feeds/luci/luci-app-openclash/root/etc/openclash/core/clash_meta https://raw.githubusercontent.com/vernesong/OpenClash/master/core-latest/meta/clash_meta-linux-armv7

# 4. 强行赋予编译树中的内核可执行权限，确保打包进固件后可以直接运行
chmod +x package/feeds/luci/luci-app-openclash/root/etc/openclash/core/clash_meta
