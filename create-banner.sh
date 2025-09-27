#!/bin/bash
set -e

# -------------------- 日志函数 --------------------
log_success() { echo -e "\033[32m[SUCCESS] $*\033[0m"; }
log_error()   { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }
log_info()    { echo -e "\033[34m[INFO] $*\033[0m"; }

# -------------------- 目录定义 --------------------
CUSTOM_PKG_DIR="openwrt/package/custom/luci-app-banner"
mkdir -p "$CUSTOM_PKG_DIR"
mkdir -p "$CUSTOM_PKG_DIR/luasrc/controller" \
         "$CUSTOM_PKG_DIR/luasrc/model/cbi" \
         "$CUSTOM_PKG_DIR/luasrc/view/banner" \
         "$CUSTOM_PKG_DIR/htdocs/banner" \
         "$CUSTOM_PKG_DIR/htdocs/banner/css" \
         "$CUSTOM_PKG_DIR/root/etc/config" \
         "$CUSTOM_PKG_DIR/root/etc/uci-defaults"
log_info "Plugin folder created: $CUSTOM_PKG_DIR"

# -------------------- 下载二维码 --------------------
QR_URL="https://raw.githubusercontent.com/fgbfg5676/ImmortalWrt-Actions/main/qr-code.png"
QR_FILE="$CUSTOM_PKG_DIR/htdocs/banner/qr-code.png"
wget -q -O "$QR_FILE" "$QR_URL" || log_error "Failed to download QR code"
log_success "QR code downloaded to $QR_FILE"

# -------------------- 默认 CSS --------------------
cat > "$CUSTOM_PKG_DIR/htdocs/banner/css/banner.css" <<'EOF'
.banner-preview { font-weight:bold; font-size:1.2em; color:#000000; }
EOF

# -------------------- UCI默认配置 --------------------
cat > "$CUSTOM_PKG_DIR/root/etc/config/banner" <<'EOF'
config banner 'banner'
	option text 'Welcome to OpenWrt'
	option color '#000000'
EOF
log_success "UCI default config created"

# -------------------- UCI Defaults脚本 --------------------
cat > "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner" <<'EOF'
#!/bin/sh
# 初始化banner配置
uci -q batch <<-EOT
	delete ucitrack.@banner[-1]
	add ucitrack banner
	set ucitrack.@banner[-1].init=banner
	commit ucitrack
EOT

# 如果banner配置不存在，创建默认配置
if ! uci -q get banner.banner >/dev/null 2>&1; then
	uci -q batch <<-EOT
		set banner.banner=banner
		set banner.banner.text='Welcome to OpenWrt'
		set banner.banner.color='#000000'
		commit banner
	EOT
fi

exit 0
EOF
chmod +x "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner"
log_success "UCI defaults script created"

# -------------------- Makefile --------------------
cat > "$CUSTOM_PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=niwo5507 <niwo5507@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=Banner plugin
  DEPENDS:=+luci-compat +luci-base
  PKGARCH:=all
endef

define Package/luci-app-banner/description
  Simple LuCI Banner plugin with text and static QR code display. Supports dynamic text, color, multi-language.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/banner.lua $(1)/usr/lib/lua/luci/controller/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/banner
	$(INSTALL_DATA) ./luasrc/model/cbi/banner.lua $(1)/usr/lib/lua/luci/model/cbi/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DATA) ./luasrc/view/banner/banner.htm $(1)/usr/lib/lua/luci/view/banner/banner.htm

	$(INSTALL_DIR) $(1)/www/luci-static/banner/css
	$(INSTALL_DATA) ./htdocs/banner/qr-code.png $(1)/www/luci-static/banner/qr-code.png
	$(INSTALL_DATA) ./htdocs/banner/css/banner.css $(1)/www/luci-static/banner/css/banner.css

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/99-banner $(1)/etc/uci-defaults/99-banner
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	( . /etc/uci-defaults/99-banner ) && rm -f /etc/uci-defaults/99-banner
}
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF
log_success "Enhanced Makefile generated"

# -------------------- Controller --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/banner") then
        return
    end

    entry({"admin", "system", "banner"}, cbi("banner/banner"), _("Banner"), 50).dependent = false
    entry({"admin", "overview", "banner"}, call("show_banner"), nil, 10)
end

function show_banner()
    local uci = require "luci.model.uci".cursor()
    local template = require "luci.template"
    local fs = require "nixio.fs"
    local util = require "luci.util"
    
    local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
    local banner_color = uci:get("banner", "banner", "color") or "#000000"
    local qr_file = "/luci-static/banner/qr-code.png"
    
    template.render("banner/banner", { 
        banner_text = util.pcdata(banner_text), 
        banner_color = banner_color, 
        qr_file = qr_file 
    })
end
EOF
log_success "Enhanced Controller generated"

# -------------------- Model (CBI) --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
local m, s, o

m = Map("banner", translate("Banner Settings"), translate("Configure banner text and appearance"))
m.apply_on_parse = true

s = m:section(TypedSection, "banner", translate("Banner Configuration"))
s.addremove = false
s.anonymous = true

o = s:option(Value, "text", translate("Banner Text"))
o.placeholder = "Welcome to OpenWrt"
o.default = "Welcome to OpenWrt"
o.rmempty = false

o = s:option(Value, "color", translate("Text Color"), translate("Hex color code (e.g., #FF0000 for red)"))
o.placeholder = "#000000"
o.default = "#000000"
o.rmempty = false

function o.validate(self, value, section)
    if value and not value:match("^#[0-9A-Fa-f]{6}$") then
        return nil, translate("Invalid hex color code")
    end
    return value
end

return m
EOF
log_success "Enhanced Model (CBI) generated"

# -------------------- View --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/banner.htm" <<'EOF'
<%+header%>

<div class="cbi-map">
    <h2 name="content"><%:Banner Display%></h2>
    
    <div class="cbi-section">
        <div class="cbi-section-node">
            <h3><%:Current Banner%></h3>
            <div class="banner-preview" style="color:<%=banner_color%>; padding: 10px; border: 1px solid #ccc; margin: 10px 0;">
                <%=banner_text%>
            </div>
            
            <h3><%:Contact Information%></h3>
            <p>
                <strong>Telegram:</strong> 
                <a href="https://t.me/fgnb111999" target="_blank" rel="noopener">https://t.me/fgnb111999</a>
            </p>
            
            <h3><%:QR Code%></h3>
            <div style="text-align: left; margin: 10px 0;">
                <img src="<%=qr_file%>" alt="QR Code" style="max-width:200px; border: 1px solid #ddd; padding: 5px;"/>
            </div>
        </div>
    </div>
</div>

<%+footer%>
EOF
log_success "Enhanced View generated"

# -------------------- 检查编译依赖 --------------------
log_info "Checking if banner package can be found in build system..."
if [ -d "openwrt" ]; then
    cd openwrt
    if ./scripts/feeds list | grep -q "luci-app-banner"; then
        log_success "luci-app-banner found in feeds"
    else
        log_info "luci-app-banner not in feeds (this is normal for custom packages)"
    fi
    
    # 检查包是否存在
    if [ -d "package/custom/luci-app-banner" ]; then
        log_success "Custom package directory exists and ready for compilation"
        log_info "Package structure:"
        find package/custom/luci-app-banner -type f | head -10
    fi
    cd ..
fi

log_success "Banner plugin setup completed successfully!"
log_info "Make sure your .config includes: CONFIG_PACKAGE_luci-app-banner=y"
