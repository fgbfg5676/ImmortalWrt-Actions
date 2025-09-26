#!/bin/bash
set -e

# -------------------- 日志函数 --------------------
log_success() { echo -e "\033[32m[SUCCESS] $*\033[0m"; }
log_error()   { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }
log_info()    { echo -e "\033[34m[INFO] $*\033[0m"; }

# -------------------- 验证 Go 环境 --------------------
if ! command -v go >/dev/null 2>&1 || [ "$(go version | grep -o 'go1.25.0')" != "go1.25.0" ]; then
    log_error "Go 1.25.0 is required but not found or incorrect version: $(go version 2>/dev/null || echo 'Go not installed')"
fi
log_info "Go version: $(go version)"

# -------------------- 基础变量 --------------------
WGET_OPTS="-q --timeout=30 --tries=3 --retry-connrefused --connect-timeout 10"
ARCH="armv7"
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
BOARD_DIR="$PWD/board"
CUSTOM_PLUGINS_DIR="$PWD/package/custom"

mkdir -p "$DTS_DIR" "$BOARD_DIR" "$CUSTOM_PLUGINS_DIR"

# -------------------- /var/partexp 目录准备 --------------------
PARTEEXP_DIR="files/var/partexp"
mkdir -p "$PARTEEXP_DIR"

# 输出目录权限和状态
log_info "Checking $PARTEEXP_DIR permissions..."
ls -ld "$PARTEEXP_DIR" || log_error "Failed to access $PARTEEXP_DIR"
log_info "Directory $PARTEEXP_DIR ready with permissions:"
stat "$PARTEEXP_DIR"
log_success "$PARTEEXP_DIR is ready for use"

# -------------------- 检查 uci.sh 文件 --------------------
UCI_FILE="/usr/share/openclash/uci.sh"
if [ ! -f "$UCI_FILE" ]; then
    log_info "Warning: $UCI_FILE not found. If OpenClash requires it, make sure it's copied or installed."
else
    log_success "$UCI_FILE exists"
fi

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

# -------------------- luci-app-partexp --------------------
PLUGIN_PATH="$CUSTOM_PLUGINS_DIR/luci-app-partexp"
if [ ! -d "$PLUGIN_PATH/.git" ]; then
    log_info "Cloning luci-app-partexp..."
    git clone --depth 1 https://github.com/sirpdboy/luci-app-partexp.git "$PLUGIN_PATH" || log_error "Failed to clone plugin"
    log_success "Plugin cloned successfully"
else
    log_info "Plugin already exists, skipping clone"
fi

if [ ! -d "package/luci-app-partexp" ]; then
    cp -r "$PLUGIN_PATH" package/
    log_success "Plugin copied to package/"
fi

if ! grep -q "CONFIG_PACKAGE_luci-app-partexp=y" .config 2>/dev/null; then
    echo "CONFIG_PACKAGE_luci-app-partexp=y" >> .config
    log_success "luci-app-partexp enabled"
else
    log_info "luci-app-partexp already enabled, skipping"
fi

# -------------------- PassWall2 --------------------
if ! grep -q "CONFIG_PACKAGE_luci-app-passwall2=y" .config 2>/dev/null; then
    echo "CONFIG_PACKAGE_luci-app-passwall2=y" >> .config
    log_success "PassWall2 enabled"
else
    log_info "PassWall2 already enabled, skipping"
fi

# -------------------- 中文包转换 --------------------
log_info "Converting zh-cn to zh_Hans..."
zh_cn_files=$(find feeds/luci package/custom -type f -name 'zh-cn.po' 2>/dev/null)
if [ -z "$zh_cn_files" ]; then
    log_info "No zh-cn.po files found, skipping conversion"
else
    for po in $zh_cn_files; do
        cp -f "$po" "$(dirname $po)/zh_Hans.po"
        log_info "Converted: $po"
    done
    log_success "All zh-cn -> zh_Hans conversion completed"
fi

# -------------------- 自动修正 zh_Hans 依赖为 zh-cn --------------------
log_info "Checking default-settings Makefile for zh_Hans dependencies..."
DEFAULT_MK="package/emortal/default-settings/Makefile"
if [ -f "$DEFAULT_MK" ]; then
    if grep -q "luci-i18n-.*-zh_Hans" "$DEFAULT_MK"; then
        log_info "Found zh_Hans dependency, replacing with zh-cn..."
        sed -i 's/\(luci-i18n-.*\)-zh_Hans/\1-zh-cn/g' "$DEFAULT_MK"
        log_success "Makefile zh_Hans dependencies replaced with zh-cn"
    else
        log_info "No zh_Hans dependency found, skipping"
    fi
else
    log_info "Default-settings Makefile not found, skipping"
fi

# -------------------- 版本文件生成 --------------------
VERSION_FILE="files/etc/firmware-release"
mkdir -p "$(dirname "$VERSION_FILE")"
echo -e "Firmware Release: $(date +'%Y-%m-%d %H:%M:%S')\n" > "$VERSION_FILE"

# PassWall2 版本
PW2_DIR="package/custom/luci-app-passwall2"
PW2_VER=$(awk -F'=' '/PKG_VERSION/ {print $2}' "$PW2_DIR/Makefile" 2>/dev/null | tr -d ' ' || echo "not found")
echo "PassWall2 version: $PW2_VER" >> "$VERSION_FILE"

# OpenClash 版本
OC_DIR="package/custom/luci-app-openclash"
OC_VER=$(awk -F'=' '/PKG_VERSION/ {print $2}' "$OC_DIR/Makefile" 2>/dev/null | tr -d ' ' || echo "not found")
echo "OpenClash version: $OC_VER" >> "$VERSION_FILE"

log_success "Version file generated at $VERSION_FILE"

log_success "DIY part2 script finished"
