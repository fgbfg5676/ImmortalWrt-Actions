#!/bin/bash
set -e

# -------------------- 步驟 0：日誌函數 --------------------
log_info() { echo -e "[$(date +'%H:%M:%S')] \033[34mℹ️  $*\033[0m"; }
log_error() { echo -e "[$(date +'%H:%M:%S')] \033[31m❌ $*\033[0m"; exit 1; }
log_success() { echo -e "[$(date +'%H:%M:%S')] \033[32m✅ $*\033[0m"; }

# =================================================================
# =================== 預編譯配置階段 (Pre-Compile) ==================
# =================================================================

log_info "===== 開始執行預編譯配置 ====="

# -------------------- 步驟 1：基礎變量定義 --------------------
log_info "步驟 1：定義基礎變量..."
ARCH="armv7"
DTS_DIR="target/linux/ipq40xx/files/arch/arm/boot/dts"
DTS_FILE="$DTS_DIR/qcom-ipq4019-cm520-79f.dts"
GENERIC_MK="target/linux/ipq40xx/image/generic.mk"
CUSTOM_PLUGINS_DIR="package/custom"
PARTE_EXP_DIR="$CUSTOM_PLUGINS_DIR/luci-app-partexp"
log_success "基礎變量定義完成。"
mkdir -p "$CUSTOM_PLUGINS_DIR"
log_info "自定义插件目录已创建：$CUSTOM_PLUGINS_DIR"

# -------------------- 步驟 2：創建必要的目錄 --------------------
log_info "步驟 2：創建必要的目錄..."
mkdir -p "$DTS_DIR" "$CUSTOM_PLUGINS_DIR" 
log_success "目錄創建完成。"

# -------------------- 步驟 3：寫入DTS文件 --------------------
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

# -------------------- 步驟 4：創建網絡配置文件 --------------------
log_info "步驟 4：創建針對 CM520-79F 的網絡配置文件..."
BOARD_DIR="target/linux/ipq40xx/base-files/etc/board.d"
mkdir -p "$BOARD_DIR"
cat > "$BOARD_DIR/02_network" <<EOF
#!/bin/sh
. /lib/functions/system.sh
ipq40xx_board_detect() {
	local machine
	machine=\$(board_name)
	case "\$machine" in
	"mobipromo,cm520-79f")
		ucidef_set_interfaces_lan_wan "eth1" "eth0"
		;;
	esac
}
boot_hook_add preinit_main ipq40xx_board_detect
EOF
log_success "網絡配置文件創建完成。"

# -------------------- 步驟 5：配置設備規則 --------------------
log_info "步驟 5：配置設備規則..."
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
    log_success "设备规则添加完成。"
else
    sed -i 's/IMAGE_SIZE := 32768k/IMAGE_SIZE := 81920k/' "$GENERIC_MK"
    log_info "设备规则已存在，更新IMAGE_SIZE。"
fi
# =================================================================
# 0️⃣ 修改默认 IP
OLD_IP="192.168.1.1"
NEW_IP="192.168.3.1"
CONFIG_FILE="package/base-files/files/bin/config_generate"

# 文件存在检查
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在：$CONFIG_FILE"
fi

# 修改 IP
sed -i "s/${OLD_IP}/${NEW_IP}/g" "$CONFIG_FILE"

# 输出日志
if grep -q "${NEW_IP}" "$CONFIG_FILE"; then
    log_success "默认 IP 修改成功：${NEW_IP}"
else
    log_error "默认 IP 修改失败，请检查 $CONFIG_FILE"
fi

# -------------------- 集成 sirpdboy 插件 --------------------
log_info "===== 集成 sirpdboy 插件 ====="

CUSTOM_PLUGINS_DIR="package/custom"
PARTE_EXP_DIR="$CUSTOM_PLUGINS_DIR/luci-app-partexp"

# 创建目录
mkdir -p "$CUSTOM_PLUGINS_DIR"

# 克隆插件（如果不存在）
if [ ! -d "$PARTE_EXP_DIR/.git" ]; then
    log_info "sirpdboy 插件不存在，开始克隆..."
    if git clone --depth 1 https://github.com/sirpdboy/luci-app-partexp.git "$PARTE_EXP_DIR"; then
        log_success "sirpdboy 插件克隆成功"
    else
        log_error "sirpdboy 插件克隆失败"
    fi
else
    log_info "sirpdboy 插件已存在，跳过克隆"
fi

# 自动启用插件
if ! grep -q "CONFIG_PACKAGE_luci-app-partexp=y" .config; then
    echo "CONFIG_PACKAGE_luci-app-partexp=y" >> .config
    log_success "sirpdboy 插件已自动启用"
else
    log_info "sirpdboy 插件已启用，无需重复操作"
fi


# -------------------- 步骤 8：更新 feeds 并安装 --------------------
log_info "更新 feeds 并安装..."
./scripts/feeds update -a
./scripts/feeds install -a
log_success "feeds 更新完成"

# =================================================================
# AdGuardHome 官方源码编译
AGH_DIR="feeds/my_packages/adguardhome"
OUTPUT_DIR="package/custom/AdGuardHome/files/usr/bin"

log_info "===== 编译官方 AdGuardHome 源码 ====="

# 清理旧目录
rm -rf "$AGH_DIR"
git clone --depth 1 https://github.com/AdguardTeam/AdGuardHome.git "$AGH_DIR"

# 检查 go.mod 和 main.go 是否存在
if [ ! -f "$AGH_DIR/go.mod" ] || [ ! -f "$AGH_DIR/main.go" ]; then
    log_error "go.mod 或 main.go 文件不存在，目录不完整：$AGH_DIR"
fi

# 设置交叉编译环境
export GOOS=linux
export GOARCH=arm
export GOARM=7
export CGO_ENABLED=0

# 编译
cd "$AGH_DIR"
go mod tidy
if go build -v -o AdGuardHome main.go; then
    log_success "AdGuardHome 编译成功"
else
    log_error "AdGuardHome 编译失败"
fi

# 拷贝到 OpenWrt package 目录
mkdir -p "$OUTPUT_DIR"
cp AdGuardHome "$OUTPUT_DIR/"
log_success "AdGuardHome 已集成到 OpenWrt package！"

# =================================================================
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

