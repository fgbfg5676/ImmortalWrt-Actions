#!/bin/bash

# --- 嚴格模式 ---
set -e

# -------------------- 日志函数 --------------------
log_info()    { echo -e "[$(date +'%H:%M:%S')] \033[34mℹ️  $*\033[0m"; }
log_error()   { echo -e "[$(date +'%H:%M:%S')] \033[31m❌ $*\033[0m"; exit 1; }
log_success() { echo -e "[$(date +'%H:%M:%S')] \033[32m✅ $*\033[0m"; }

# -------------------- 确定源码根目录 --------------------
if [ -f "scripts/feeds" ]; then
    ROOT_DIR=$(pwd)
else
    ROOT_DIR=$(find . -maxdepth 2 -name feeds -type f | head -n1 | xargs dirname | xargs dirname)
fi
cd "$ROOT_DIR" || log_error "源码根目录找不到"
log_info "源码根目录：$(pwd)"

# =================================================================
# =================== 预编译配置 ==================
# =================================================================
log_info "===== 開始執行預編譯配置 ====="

ARCH="armv7"
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
DTS_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
CUSTOM_PLUGINS_DIR="package/custom"
BOARD_DIR="target/linux/ipq40xx/base-files/etc/board.d"

# -------------------- 创建必要目录 --------------------
mkdir -p "$DTS_DIR" "$CUSTOM_PLUGINS_DIR" "$BOARD_DIR"
log_success "必要目录创建完成"

# -------------------- 寫入DTS文件 --------------------
log_info "步驟 3：正在寫入100%正確的DTS文件..."
cat > "$DTS_FILE" <<'EOF'
/dts-v1/;
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

#include "qcom-ipq4019.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/soc/qcom,tcsr.h>

/ {
	model = "MobiPromo CM520-79F";
	compatible = "mobipromo,cm520-79f";

	aliases {
		led-boot = &led_sys;
		led-failsafe = &led_sys;
		led-running = &led_sys;
		led-upgrade = &led_sys;
	};

	chosen {
		bootargs-append = " ubi.block=0,1 root=/dev/ubiblock0_1";
	};

	soc {
		rng@22000 {
			status = "okay";
		};
		mdio@90000 {
			status = "okay";
			pinctrl-0 = <&mdio_pins>;
			pinctrl-names = "default";
			reset-gpios = <&tlmm 47 GPIO_ACTIVE_LOW>;
			reset-delay-us = <1000>;
		};
		ess-psgmii@98000 {
			status = "okay";
		};
		tcsr@1949000 {
			compatible = "qcom,tcsr";
			reg = <0x1949000 0x100>;
			qcom,wifi_glb_cfg = <TCSR_WIFI_GLB_CFG>;
		};
		tcsr@194b000 {
			compatible = "qcom,tcsr";
			reg = <0x194b000 0x100>;
			qcom,usb-hsphy-mode-select = <TCSR_USB_HSPHY_HOST_MODE>;
		};
		ess_tcsr@1953000 {
			compatible = "qcom,tcsr";
			reg = <0x1953000 0x1000>;
			qcom,ess-interface-select = <TCSR_ESS_PSGMII>;
		};
		tcsr@1957000 {
			compatible = "qcom,tcsr";
			reg = <0x1957000 0x100>;
			qcom,wifi_noc_memtype_m0_m2 = <TCSR_WIFI_NOC_MEMTYPE_M0_M2>;
		};
		usb2@60f8800 {
			status = "okay";
			dwc3@6000000 {
				#address-cells = <1>;
				#size-cells = <0>;
				usb2_port1: port@1 {
					reg = <1>;
					#trigger-source-cells = <0>;
				};
			};
		};
		usb3@8af8800 {
			status = "okay";
			dwc3@8a00000 {
				#address-cells = <1>;
				#size-cells = <0>;
				usb3_port1: port@1 {
					reg = <1>;
					#trigger-source-cells = <0>;
				};
				usb3_port2: port@2 {
					reg = <2>;
					#trigger-source-cells = <0>;
				};
			};
		};
		crypto@8e3a000 {
			status = "okay";
		};
		watchdog@b017000 {
			status = "okay";
		};
		ess-switch@c000000 {
			status = "okay";
		};
		edma@c080000 {
			status = "okay";
		};
	};

	led_spi {
		compatible = "spi-gpio";
		#address-cells = <1>;
		#size-cells = <0>;
		sck-gpios = <&tlmm 40 GPIO_ACTIVE_HIGH>;
		mosi-gpios = <&tlmm 36 GPIO_ACTIVE_HIGH>;
		num-chipselects = <0>;
		led_gpio: led_gpio@0 {
			compatible = "fairchild,74hc595";
			reg = <0>;
			gpio-controller;
			#gpio-cells = <2>;
			registers-number = <1>;
			spi-max-frequency = <1000000>;
		};
	};

	leds {
		compatible = "gpio-leds";
		usb {
			label = "blue:usb";
			gpios = <&tlmm 10 GPIO_ACTIVE_HIGH>;
			linux,default-trigger = "usbport";
			trigger-sources = <&usb3_port1>, <&usb3_port2>, <&usb2_port1>;
		};
		led_sys: can {
			label = "blue:can";
			gpios = <&tlmm 11 GPIO_ACTIVE_HIGH>;
		};
		wan {
			label = "blue:wan";
			gpios = <&led_gpio 0 GPIO_ACTIVE_LOW>;
		};
		lan1 {
			label = "blue:lan1";
			gpios = <&led_gpio 1 GPIO_ACTIVE_LOW>;
		};
		lan2 {
			label = "blue:lan2";
			gpios = <&led_gpio 2 GPIO_ACTIVE_LOW>;
		};
		wlan2g {
			label = "blue:wlan2g";
			gpios = <&led_gpio 5 GPIO_ACTIVE_LOW>;
			linux,default-trigger = "phy0tpt";
		};
		wlan5g {
			label = "blue:wlan5g";
			gpios = <&led_gpio 6 GPIO_ACTIVE_LOW>;
			linux,default-trigger = "phy1tpt";
		};
	};

	keys {
		compatible = "gpio-keys";
		reset {
			label = "reset";
			gpios = <&tlmm 18 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};
};

&blsp_dma { status = "okay"; };
&blsp1_uart1 { status = "okay"; };
&blsp1_uart2 { status = "okay"; };
&cryptobam { status = "okay"; };

&gmac0 {
	status = "okay";
	nvmem-cells = <&macaddr_art_1006>;
	nvmem-cell-names = "mac-address";
};

&gmac1 {
	status = "okay";
	nvmem-cells = <&macaddr_art_5006>;
	nvmem-cell-names = "mac-address";
};

&nand {
	pinctrl-0 = <&nand_pins>;
	pinctrl-names = "default";
	status = "okay";
	nand@0 {
		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;
			partition@0 {
				label = "Bootloader";
				reg = <0x0 0xb00000>;
				read-only;
			};
			art: partition@b00000 {
				label = "ART";
				reg = <0xb00000 0x80000>;
				read-only;
				compatible = "nvmem-cells";
				#address-cells = <1>;
				#size-cells = <1>;
				precal_art_1000: precal@1000 { reg = <0x1000 0x2f20>; };
				macaddr_art_1006: macaddr@1006 { reg = <0x1006 0x6>; };
				precal_art_5000: precal@5000 { reg = <0x5000 0x2f20>; };
				macaddr_art_5006: macaddr@5006 { reg = <0x5006 0x6>; };
			};
			partition@b80000 {
				label = "rootfs";
				reg = <0xb80000 0x7480000>;
			};
		};
	};
};

&qpic_bam { status = "okay"; };

&tlmm {
	mdio_pins: mdio_pinmux {
		mux_1 {
			pins = "gpio6";
			function = "mdio";
			bias-pull-up;
		};
		mux_2 {
			pins = "gpio7";
			function = "mdc";
			bias-pull-up;
		};
	};
	nand_pins: nand_pins {
		pullups {
			pins = "gpio52", "gpio53", "gpio58", "gpio59";
			function = "qpic";
			bias-pull-up;
		};
		pulldowns {
			pins = "gpio54", "gpio55", "gpio56", "gpio57", "gpio60", "gpio61", "gpio62", "gpio63", "gpio64", "gpio65", "gpio66", "gpio67", "gpio68", "gpio69";
			function = "qpic";
			bias-pull-down;
		};
	};
};

&usb3_ss_phy { status = "okay"; };
&usb3_hs_phy { status = "okay"; };
&usb2_hs_phy { status = "okay"; };
&wifi0 { status = "okay"; nvmem-cell-names = "pre-calibration"; nvmem-cells = <&precal_art_1000>; qcom,ath10k-calibration-variant = "CM520-79F"; };
&wifi1 { status = "okay"; nvmem-cell-names = "pre-calibration"; nvmem-cells = <&precal_art_5000>; qcom,ath10k-calibration-variant = "CM520-79F"; };
EOF
log_success "DTS文件寫入成功。"


# -------------------- 网络配置 --------------------
cat > "$BOARD_DIR/02_network" <<'EOF'
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
log_success "网络配置文件创建完成"

# -------------------- 设备规则 --------------------
if [ ! -f "$GENERIC_MK" ]; then
    log_info "generic.mk 不存在，已创建空文件兼容"
    mkdir -p "$(dirname "$GENERIC_MK")"
    touch "$GENERIC_MK"
fi

if ! grep -q "define Device/mobipromo_cm520-79f" "$GENERIC_MK"; then
    cat <<EOF >> "$GENERIC_MK"

define Device/mobipromo_cm520-79f
  DEVICE_VENDOR := MobiPromo
  DEVICE_MODEL := CM520-79F
  DEVICE_DTS := qcom-ipq4019-cm520-79f
  KERNEL_SIZE := 4096k
  ROOTFS_SIZE := 16384k
  IMAGE_SIZE := 81920k
  IMAGE/trx := append-kernel | pad-to \$(KERNEL_SIZE) | append-rootfs | trx -o \$@
endef
TARGET_DEVICES += mobipromo_cm520-79f
EOF
    log_success "设备规则添加完成"
else
    sed -i 's/IMAGE_SIZE := [0-9]*k/IMAGE_SIZE := 81920k/' "$GENERIC_MK"
    log_info "设备规则已存在，更新 IMAGE_SIZE"
fi

# -------------------- 修改默认 IP --------------------
CONFIG_FILE="package/base-files/files/bin/config_generate"
OLD_IP="192.168.1.1"
NEW_IP="192.168.3.1"
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s/${OLD_IP}/${NEW_IP}/g" "$CONFIG_FILE"
    grep -q "${NEW_IP}" "$CONFIG_FILE" && log_success "默认 IP 修改成功：${NEW_IP}" || log_error "默认 IP 修改失败"
else
    log_info "config_generate 不存在，跳过默认 IP 修改"
fi

# -------------------- 更新 Feeds --------------------
if [ -f "./scripts/feeds" ]; then
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    log_success "Feeds 更新和安装完成"
else
    log_info "scripts/feeds 不存在，跳过更新安装 feeds"
fi

# -------------------- Golang 更新 --------------------
NEED_NEW_GOLANG=("luci-app-passwall2" "luci-app-openclash" "v2ray-core" "xray-core")
UPDATE_GO=false
for pkg in "${NEED_NEW_GOLANG[@]}"; do
    if grep -q "CONFIG_PACKAGE_${pkg}=y" .config 2>/dev/null; then
        UPDATE_GO=true
        log_info "插件 $pkg 启用，需更新 Golang"
        break
    fi
done

if $UPDATE_GO; then
    log_info "更新 Golang..."
    [ -d ./feeds/packages/lang/golang ] && mv ./feeds/packages/lang/golang ./feeds/packages/lang/golang.bak
    git clone -b master --single-branch https://github.com/immortalwrt/packages.git packages_master
    mv ./packages_master/lang/golang ./feeds/packages/lang/
    rm -rf packages_master
    log_success "Golang 更新完成"
else
    log_info "未启用需最新 Golang 的插件，保持默认 Golang 版本"
fi

# -------------------- sirpdboy 插件 --------------------
if [ ! -d "$CUSTOM_PLUGINS_DIR/luci-app-partexp/.git" ]; then
    git clone --depth 1 https://github.com/sirpdboy/luci-app-partexp.git "$CUSTOM_PLUGINS_DIR/luci-app-partexp" \
        && log_success "sirpdboy 插件克隆成功" \
        || log_error "sirpdboy 插件克隆失败"
else
    log_info "sirpdboy 插件已存在，跳过克隆"
fi

# -------------------- 启用 PassWall2 --------------------
grep -q "CONFIG_PACKAGE_luci-app-passwall2=y" .config 2>/dev/null || echo "CONFIG_PACKAGE_luci-app-passwall2=y" >> .config
log_success "PassWall2 已启用"

# -------------------- zh-cn -> zh_Hans --------------------
for po in $(find feeds/luci/modules -type f -name 'zh-cn.po' 2>/dev/null); do
    cp -f "$po" "$(dirname $po)/zh_Hans.po"
done
log_success "zh-cn -> zh_Hans 转换完成"

# -------------------- LuCI ACL --------------------
mkdir -p files/etc/config
cat > files/etc/config/luci_acl <<'EOF'
config internal "admin"
    option password ''
    option username 'admin'
    option read_only '0'
EOF
log_success "LuCI ACL 创建完成"

# -------------------- 合并自定义配置 --------------------
CUSTOM_CONFIG=".config.custom"
rm -f "$CUSTOM_CONFIG"
cat >> "$CUSTOM_CONFIG" <<EOF
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_kmod-ubi=y
CONFIG_PACKAGE_kmod-ubifs=y
CONFIG_PACKAGE_trx=y
CONFIG_PACKAGE_kmod-ath10k-ct=y
CONFIG_PACKAGE_ath10k-firmware-qca4019-ct=y
CONFIG_PACKAGE_ipq-wifi-mobipromo_cm520-79f=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_TARGET_ROOTFS_NO_CHECK_SIZE=y
EOF

[ -x scripts/feeds/merge_config.sh ] && chmod +x scripts/feeds/merge_config.sh
if [ -x scripts/feeds/merge_config.sh ]; then
    bash scripts/feeds/merge_config.sh "$CUSTOM_CONFIG" && log_success "自定义配置合并完成"
else
    log_info "merge_config.sh 不存在，跳过配置合并"
fi
rm -f "$CUSTOM_CONFIG"

# -------------------- 生成最终 .config --------------------
make defconfig || log_error "make defconfig 失败"
log_success "最终配置文件生成完成"

# -------------------- 清理临时文件 --------------------
[ -d "./tmp" ] && rm -rf ./tmp && log_success "临时文件 tmp 已删除"

log_success "所有预编译步骤完成！"
log_info "接下来请执行 'make' 命令进行编译。"
