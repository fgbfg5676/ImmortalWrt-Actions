#!/bin/bash
set -e

# 目标目录
TARGET_DIR="luci-app-banner"

# 创建目录结构
mkdir -p "$TARGET_DIR"/{luasrc/{controller,model/cbi,view/banner},htdocs/luci-static/resources/banner,root/etc/config}

# -------------------- Makefile --------------------
cat > "$TARGET_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=Custom Banner with QR Code
	PKGARCH:=all
	DEPENDS:=+luci-base
endef

define Package/luci-app-banner/description
	Custom banner with QR code display for LuCI interface
endef

define Build/Compile
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/*.lua $(1)/usr/lib/lua/luci/model/cbi/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DATA) ./luasrc/view/banner/*.htm $(1)/usr/lib/lua/luci/view/banner/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/banner
	$(INSTALL_DATA) ./htdocs/luci-static/resources/banner/* $(1)/www/luci-static/resources/banner/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF

# -------------------- controller --------------------
cat > "$TARGET_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
	entry({"admin", "system", "banner"}, cbi("banner"), _("Banner Settings"), 90)
end
EOF

# -------------------- model/cbi --------------------
cat > "$TARGET_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
local m, s, o

m = Map("banner", translate("Banner Settings"), translate("Configure custom banner and QR code display"))

s = m:section(TypedSection, "banner", translate("Banner Configuration"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable Banner"))
o.default = "1"

o = s:option(Value, "title", translate("Banner Title"))
o.default = "Custom Router Banner"
o.rmempty = false

o = s:option(TextValue, "description", translate("Banner Description"))
o.rows = 3
o.default = "Welcome to our custom router interface"

o = s:option(Flag, "show_qr", translate("Show QR Code"))
o.default = "1"

o = s:option(Value, "qr_text", translate("QR Code Content"))
o.default = "https://t.me/fgnb111999"
o.rmempty = false
o:depends("show_qr", "1")

o = s:option(Value, "contact_info", translate("Contact Information"))
o.default = "@FGNB1111999"
o.rmempty = false

return m
EOF

# -------------------- view/banner --------------------
cat > "$TARGET_DIR/luasrc/view/banner/banner.htm" <<'EOF'
<%
local uci = require "luci.model.uci".cursor()
local banner_config = uci:get_all("banner", "config") or {}
%>

<% if banner_config.enabled == "1" then %>
<div class="custom-banner">
	<link rel="stylesheet" type="text/css" href="<%=resource%>/banner/banner.css" />
	
	<div class="banner-container">
		<div class="banner-content">
			<div class="banner-text">
				<h2><%= banner_config.title or "Custom Router Banner" %></h2>
				<p><%= banner_config.description or "Welcome to our custom router interface" %></p>
				<div class="contact-info">
					<span>Contact: <%= banner_config.contact_info or "@FGNB1111999" %></span>
				</div>
			</div>
			
			<% if banner_config.show_qr == "1" then %>
			<div class="qr-container">
				<div class="qr-code" data-text="<%= banner_config.qr_text or 'https://t.me/fgnb111999' %>"></div>
				<div class="qr-text">
					<small><%= banner_config.qr_text or "https://t.me/fgnb111999" %></small>
				</div>
			</div>
			<% end %>
		</div>
	</div>
	
	<script src="<%=resource%>/banner/banner.js"></script>
</div>
<% end %>
EOF

# -------------------- banner.css --------------------
cat > "$TARGET_DIR/htdocs/luci-static/resources/banner/banner.css" <<'EOF'
.custom-banner {
	margin: 10px 0;
	background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	border-radius: 8px;
	box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	overflow: hidden;
}
.banner-container { padding: 20px; color: white; }
.banner-content { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; }
.banner-text { flex: 1; margin-right: 20px; }
.banner-text h2 { margin: 0 0 10px 0; font-size: 24px; font-weight: bold; }
.banner-text p { margin: 0 0 10px 0; font-size: 16px; line-height: 1.5; }
.contact-info { font-size: 14px; opacity: 0.9; }
.qr-container { display: flex; flex-direction: column; align-items: center; background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; backdrop-filter: blur(10px); }
.qr-code { width: 80px; height: 80px; background: white; border-radius: 4px; margin-bottom: 8px; display: flex; align-items: center; justify-content: center; font-size: 10px; text-align: center; color: #333; word-break: break-all; padding: 5px; cursor: pointer; transition: transform 0.3s ease; }
.qr-code:hover { transform: scale(1.05); }
.qr-text { text-align: center; }
.qr-text small { font-size: 11px; opacity: 0.8; word-break: break-all; }
.qr-modal { display: none; position: fixed; z-index: 9999; left:0; top:0; width:100%; height:100%; background-color: rgba(0,0,0,0.8); justify-content: center; align-items: center; }
.qr-modal-content { background:white; padding:20px; border-radius:8px; text-align:center; max-width:300px; }
.qr-modal .qr-code { width:200px; height:200px; margin:10px auto; }
.qr-close { color:#aaa; float:right; font-size:28px; font-weight:bold; cursor:pointer; position:absolute; top:10px; right:15px; }
@media (max-width:768px) { .banner-content { flex-direction: column; text-align: center; } .banner-text { margin-right:0; margin-bottom:20px; } .qr-container { width:100%; } }
EOF

# -------------------- banner.js --------------------
cat > "$TARGET_DIR/htdocs/luci-static/resources/banner/banner.js" <<'EOF'
document.addEventListener('DOMContentLoaded', function() {
	const qrElements = document.querySelectorAll('.qr-code[data-text]');
	qrElements.forEach(function(element){
		const text = element.getAttribute('data-text');
		const img = document.createElement('img');
		img.src = 'https://api.qrserver.com/v1/create-qr-code/?size=80x80&data='+encodeURIComponent(text);
		img.style.width='100%';
		img.style.height='100%';
		element.appendChild(img);
		element.addEventListener('click', function(){
			alert("Scan QR: "+text);
		});
	});
});
EOF

# -------------------- banner config --------------------
cat > "$TARGET_DIR/root/etc/config/banner" <<'EOF'
config banner 'config'
	option enabled '1'
	option title 'Custom Router Banner'
	option description 'Welcome to our custom router interface'
	option show_qr '1'
	option qr_text 'https://t.me/fgnb111999'
	option contact_info '@FGNB1111999'
EOF

echo "[SUCCESS] luci-app-banner folder created successfully at $TARGET_DIR"
