#!/bin/bash
set -e

# -------------------- 日志函数 --------------------
log_success() { echo -e "\033[32m[SUCCESS] $*\033[0m"; }
log_error()   { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }
log_info()    { echo -e "\033[34m[INFO] $*\033[0m"; }

# -------------------- 基础变量 --------------------
WGET_OPTS="-q --timeout=30 --tries=3 --retry-connrefused --connect-timeout 10"
ARCH="armv7"
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
BOARD_DIR="$PWD/board"
CUSTOM_PLUGINS_DIR="$PWD/package/custom"
mkdir -p "$DTS_DIR" "$BOARD_DIR" "$CUSTOM_PLUGINS_DIR"

# -------------------- DTS补丁 --------------------
DTS_PATCH_URL="https://git.ix.gs/mptcp/openmptcprouter/commit/a66353a01576c5146ae0d72ee1f8b24ba33cb88e.patch"
DTS_PATCH_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts.patch"
TARGET_DTS="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"

log_info "Downloading DTS patch..."
wget $WGET_OPTS -O "$DTS_PATCH_FILE" "$DTS_PATCH_URL" || log_error "Failed to download DTS patch"

if [ ! -f "$TARGET_DTS" ]; then
    log_info "Applying DTS patch..."
    patch -p1 < "$DTS_PATCH_FILE" || log_error "Failed to apply DTS patch"
    log_success "DTS patch applied successfully"
else
    log_info "Target DTS already exists, skipping patch"
fi

# -------------------- 设备规则 --------------------
if ! grep -q "define Device/mobipromo_cm520-79f" "$GENERIC_MK"; then
    log_info "Adding CM520-79F device rule..."
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
    log_success "Device rule added successfully"
else
    log_info "Device rule already exists, skipping"
fi

# -------------------- 网络配置 --------------------
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
log_success "Network configuration file created"


# Modify default IP
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
# -------------------- 主机名修改 --------------------
NEW_HOSTNAME="CM520-79F"
SYSTEM_FILE="package/base-files/files/etc/config/system"
log_info "Setting hostname to $NEW_HOSTNAME..."
if [ ! -f "$SYSTEM_FILE" ]; then
    mkdir -p "$(dirname "$SYSTEM_FILE")"
    cat <<EOF > "$SYSTEM_FILE"
config system
    option hostname '$NEW_HOSTNAME'
EOF
    log_success "System config created with hostname $NEW_HOSTNAME"
else
    if grep -q "option hostname" "$SYSTEM_FILE"; then
        sed -i "s/^\(\s*option hostname\s*\).*$/\1'$NEW_HOSTNAME'/" "$SYSTEM_FILE"
        log_success "Hostname updated to $NEW_HOSTNAME in existing system config"
    else
        awk -v hn="$NEW_HOSTNAME" '
            BEGIN { added=0 }
            /^config system/ && added==0 { print; print "    option hostname \x27" hn "\x27"; added=1; next }
            { print }
        ' "$SYSTEM_FILE" > "$SYSTEM_FILE.tmp" && mv "$SYSTEM_FILE.tmp" "$SYSTEM_FILE"
        log_success "Hostname added as $NEW_HOSTNAME in system config"
    fi
fi

# -------------------- 插件处理 --------------------
PLUGIN_LIST=("luci-app-partexp" "luci-app-advancedplus")
PLUGIN_REPOS=("https://github.com/sirpdboy/luci-app-partexp.git" "https://github.com/sirpdboy/luci-app-advancedplus.git")

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

# -------------------- PassWall2 --------------------
if ! grep -q "CONFIG_PACKAGE_luci-app-passwall2=y" .config 2>/dev/null; then
    echo "CONFIG_PACKAGE_luci-app-passwall2=y" >> .config
    log_success "PassWall2 enabled"
else
    log_info "PassWall2 already enabled, skipping"
fi

# -------------------- Golang 更新 --------------------
log_info "Updating Golang package..."
TMP_DIR=$(mktemp -d)
git clone -b master --single-branch --depth 1 https://github.com/immortalwrt/packages.git "$TMP_DIR" || log_error "Failed to clone packages repo"
rm -rf ./feeds/packages/lang/golang
mv "$TMP_DIR/lang/golang" ./feeds/packages/lang/ || log_error "Failed to update Golang"
rm -rf "$TMP_DIR"
log_success "Golang package updated successfully"


