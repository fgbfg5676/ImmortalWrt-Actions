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
         "$CUSTOM_PKG_DIR/root/etc/config" \
         "$CUSTOM_PKG_DIR/root/etc/uci-defaults"
log_info "Plugin folder created: $CUSTOM_PKG_DIR"

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
# 安全的UCI初始化脚本
if ! uci -q get banner.banner >/dev/null 2>&1; then
	uci -q batch <<-EOT >/dev/null 2>&1
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

# -------------------- 使用传统的 Makefile --------------------
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
	TITLE:=Banner Configuration
	DEPENDS:=+luci-base +luci-compat
	PKGARCH:=all
endef

define Package/luci-app-banner/description
	Simple Banner plugin with contact information display.
endef

define Build/Prepare
	[ ! -d ./src/ ] || $(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/banner.lua $(1)/usr/lib/lua/luci/controller/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/banner.lua $(1)/usr/lib/lua/luci/model/cbi/banner.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DATA) ./luasrc/view/banner/preview_simple.htm $(1)/usr/lib/lua/luci/view/banner/preview_simple.htm
	$(INSTALL_DATA) ./luasrc/view/banner/display.htm $(1)/usr/lib/lua/luci/view/banner/display.htm

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/99-banner $(1)/etc/uci-defaults/99-banner
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
	( . /etc/uci-defaults/99-banner ) && rm -f /etc/uci-defaults/99-banner
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF
log_success "Makefile created using traditional format"

# -------------------- Controller --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/banner") then
		return
	end
	
	entry({"admin", "system", "banner"}, cbi("banner"), _("Banner"), 50).dependent = false
	entry({"admin", "status", "banner_display"}, call("show_banner_page"), _("Banner Display"), 99)
end

function show_banner_page()
	local template = require "luci.template"
	local uci = require "luci.model.uci".cursor()
	
	local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
	local banner_color = uci:get("banner", "banner", "color") or "#000000"
	
	template.render("banner/display", {
		banner_text = banner_text,
		banner_color = banner_color
	})
end
EOF
log_success "Controller generated"

# -------------------- Model (CBI) --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
local m, s, o

m = Map("banner", translate("Banner Settings"), translate("Configure banner text and appearance"))

s = m:section(TypedSection, "banner", translate("Banner Configuration"))
s.addremove = false
s.anonymous = true

o = s:option(Value, "text", translate("Banner Text"))
o.placeholder = "Welcome to OpenWrt"
o.default = "Welcome to OpenWrt"
o.rmempty = false

-- 简化的颜色选项 - 使用下拉选择避免验证问题
o = s:option(ListValue, "color", translate("Text Color"))
o:value("#000000", translate("Black"))
o:value("#FF0000", translate("Red"))
o:value("#00FF00", translate("Green"))
o:value("#0000FF", translate("Blue"))
o:value("#FF6600", translate("Orange"))
o:value("#800080", translate("Purple"))
o.default = "#000000"

-- 添加预览
local preview_section = m:section(SimpleSection)
preview_section.template = "banner/preview_simple"

return m
EOF
log_success "Model (CBI) generated"

# -------------------- 预览模板 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/preview_simple.htm" <<'EOF'
<%
local uci = require "luci.model.uci".cursor()
local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
local banner_color = uci:get("banner", "banner", "color") or "#000000"
%>

<div class="cbi-value">
    <div style="margin: 10px 0; padding: 15px; border: 1px solid #ddd; background: #f9f9f9; border-radius: 5px;">
        <div style="text-align: center; margin-bottom: 15px;">
            <strong style="color: <%=banner_color%>; font-size: 1.3em;"><%=pcdata(banner_text)%></strong>
        </div>
        
        <div style="text-align: center; margin: 10px 0;">
            <div style="margin: 5px 0;">
                <strong>Telegram:</strong> 
                <a href="https://t.me/fgnb111999" target="_blank" style="color: #0088cc;">https://t.me/fgnb111999</a>
            </div>
            <div style="margin: 5px 0;">
                <strong>QQ:</strong> 
                <span style="color: #666;">183452852</span>
            </div>
        </div>
    </div>
</div>
EOF
log_success "Preview template generated"

# -------------------- 独立显示页面 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/display.htm" <<'EOF'
<%+header%>

<h2 name="content"><%:Banner Display%></h2>

<div class="cbi-map">
    <div class="cbi-section">
        <div style="text-align: center; margin: 20px 0; padding: 20px; border: 2px solid #ddd; border-radius: 8px; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);">
            <h1 style="color: <%=banner_color%>; margin: 0 0 15px 0; font-size: 2em; text-shadow: 2px 2px 4px rgba(0,0,0,0.1);">
                <%=pcdata(banner_text)%>
            </h1>
            
            <div style="margin: 20px 0;">
                <p style="font-size: 1.2em; color: #666; margin: 15px 0;">
                    <strong><%:Contact Information%></strong>
                </p>
                <p style="margin: 8px 0; font-size: 1.1em;">
                    <strong>Telegram:</strong> 
                    <a href="https://t.me/fgnb111999" target="_blank" style="color: #0088cc; text-decoration: none;">
                        https://t.me/fgnb111999
                    </a>
                </p>
                <p style="margin: 8px 0; font-size: 1.1em; color: #666;">
                    <strong>QQ:</strong> 183452852
                </p>
            </div>
        </div>
    </div>
</div>

<%+footer%>
EOF
log_success "Display page template generated"

# -------------------- 验证文件结构 --------------------
log_info "Created package structure:"
find "$CUSTOM_PKG_DIR" -type f | sort

log_success "Banner plugin setup completed successfully!"
log_info "Features:"
log_info "- Banner settings page: System → Banner"
log_info "- Banner display page: Status → Banner Display"  
log_info "- Contact info: Telegram + QQ"
log_info "- No image dependencies"
log_info "- Safe color selection with dropdown"
log_info ""
log_info "Make sure your .config includes: CONFIG_PACKAGE_luci-app-banner=y"
