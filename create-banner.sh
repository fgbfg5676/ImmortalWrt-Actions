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
         "$CUSTOM_PKG_DIR/htdocs/banner/css"
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
  DEPENDS:=+luci-compat
endef

define Package/luci-app-banner/description
  Simple LuCI Banner plugin with text and static QR code display. Supports dynamic text, color, multi-language.
endef

define Build/Compile
  true
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/banner.lua $(1)/usr/lib/lua/luci/controller/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/banner
	$(INSTALL_DATA) ./luasrc/model/cbi/banner.lua $(1)/usr/lib/lua/luci/model/cbi/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DATA) ./luasrc/view/banner/banner.htm $(1)/usr/lib/lua/luci/view/banner/banner.htm

	$(INSTALL_DIR) $(1)/www/luci-static/banner
	$(INSTALL_DATA) ./htdocs/banner/qr-code.png $(1)/www/luci-static/banner/qr-code.png
	$(INSTALL_DATA) ./htdocs/banner/css/banner.css $(1)/www/luci-static/banner/css/banner.css
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF
log_success "Makefile generated"

# -------------------- Controller --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)
local uci = require "luci.model.uci".cursor()
local tpl = require "luci.template"
local fs = require "nixio.fs"
local util = require "luci.util"

function index()
    entry({"admin", "system", "banner"}, cbi("banner/banner"), "Banner", 50).dependent = true
    entry({"admin", "overview", "banner"}, call("show_banner"), nil, 10)
end

function show_banner()
    local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
    local banner_color = uci:get("banner", "banner", "color") or "#000000"
    local qr_file = "/www/luci-static/banner/qr-code.png"
    if not fs.access(qr_file) then
        qr_file = "/www/luci-static/banner/default.png"
    end
    tpl.render("banner/banner", { banner_text = util.pcdata(banner_text), banner_color = banner_color, qr_file = qr_file })
end
EOF
log_success "Controller generated"

# -------------------- Model (CBI) --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
m = Map("banner", "Banner Settings")

s = m:section(TypedSection, "banner", "Banner Configuration")
s.addremove = false
s.anonymous = true

o = s:option(Value, "text", "Banner Text")
o.default = "Welcome to OpenWrt"
o.rmempty = false

c = s:option(Value, "color", "Text Color (Hex)")
c.default = "#000000"
c.rmempty = false

return m
EOF
log_success "Model (CBI) generated"

# -------------------- View --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/banner.htm" <<'EOF'
<h2>Banner Settings</h2>
<form class="cbi-form" method="post" action="<%= apply %>">
  <div class="cbi-section">
    <div class="cbi-value">
      <label for="cbi-banner-text">Banner Text:</label>
      <input id="cbi-banner-text" type="text" name="<%= o:formvalue() %>" value="<%= o:formvalue() or o.default %>" />
    </div>
    <div class="cbi-value">
      <label for="cbi-banner-color">Text Color (Hex):</label>
      <input id="cbi-banner-color" type="text" name="<%= c:formvalue() %>" value="<%= c:formvalue() or c.default %>" />
    </div>
  </div>
  <div class="cbi-section">
    <p>Banner Preview:</p>
    <p class="banner-preview" style="color:<%= banner_color %>;"><%= banner_text %></p>
    <p>Contact / Telegram:</p>
    <p><a href="https://t.me/fgnb111999" target="_blank">https://t.me/fgnb111999</a></p>
    <p>Scan QR Code:</p>
    <img src="<%= qr_file %>" alt="QR Code" style="max-width:200px;"/>
  </div>
  <div class="cbi-section">
    <input type="submit" value="Save & Apply" />
  </div>
</form>
EOF
log_success "View generated"

