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
         "$CUSTOM_PKG_DIR/luasrc/view/banner"

log_info "Plugin folder created: $CUSTOM_PKG_DIR"

# -------------------- Makefile --------------------
cat > "$CUSTOM_PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=Banner plugin
  DEPENDS:=+luci-compat
endef

define Package/luci-app-banner/description
  Simple LuCI Banner plugin
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
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF

log_success "Makefile generated"

# -------------------- Controller --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
    entry({"admin", "system", "banner"}, cbi("banner/banner"), "Banner", 50).dependent = true
end
EOF

# -------------------- Model (CBI) --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
m = Map("banner", "Banner Settings")

s = m:section(TypedSection, "banner", "Banner Configuration")
s.addremove = false
s.anonymous = true

o = s:option(Value, "text", "Banner Text")
o.default = "Welcome to OpenWrt"
o.rmempty = false

return m
EOF

# -------------------- View --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/banner.htm" <<'EOF'
<h2>Banner Settings</h2>
<form class="cbi-form" method="post" action="<%= apply %>">
  <div class="cbi-section">
    <div class="cbi-value">
      <label for="cbi-banner-text">Banner Text:</label>
      <input id="cbi-banner-text" type="text" name="<%= o:formvalue() %>" value="<%= o:formvalue() or o.default %>" />
    </div>
  </div>
  <div class="cbi-section">
    <input type="submit" value="Save & Apply" />
  </div>
</form>
EOF

log_success "Controller, Model, View files generated"

# -------------------- 写入 .config --------------------
CONFIG_FILE="openwrt/.config"
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
fi

if ! grep -q "CONFIG_PACKAGE_luci-app-banner=y" "$CONFIG_FILE"; then
    echo "CONFIG_PACKAGE_luci-app-banner=y" >> "$CONFIG_FILE"
    log_success "luci-app-banner enabled in .config"
else
    log_info "luci-app-banner already enabled in .config"
fi

log_success "create-banner.sh finished successfully"
