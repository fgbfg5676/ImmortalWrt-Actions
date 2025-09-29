#!/bin/bash
set -e

# 导航插件完整编译脚本 v3.0
log_success() { echo -e "\033[32m[SUCCESS] $*\033[0m"; }
log_error()   { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }
log_info()    { echo -e "\033[34m[INFO] $*\033[0m"; }

CUSTOM_PKG_DIR="openwrt/package/custom/luci-app-banner"
mkdir -p "$CUSTOM_PKG_DIR"
mkdir -p "$CUSTOM_PKG_DIR/luasrc/controller" \
         "$CUSTOM_PKG_DIR/luasrc/model/cbi" \
         "$CUSTOM_PKG_DIR/luasrc/view/banner" \
         "$CUSTOM_PKG_DIR/root/etc/config" \
         "$CUSTOM_PKG_DIR/root/etc/uci-defaults" \
         "$CUSTOM_PKG_DIR/root/usr/bin" \
         "$CUSTOM_PKG_DIR/po/zh-cn"

log_info "创建插件目录结构"

# ==================== UCI配置 ====================
cat > "$CUSTOM_PKG_DIR/root/etc/config/banner" <<'EOF'
config banner 'banner'
	option text '🎉 欢迎使用定制OpenWrt固件！\n📱 技术支持请联系作者'
	option color '#FF0000'
	option enabled '1'
	option update_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option update_interval '600'
	option last_update '0'
	option auto_update_enabled '1'
EOF

# ==================== UCI初始化脚本 ====================
cat > "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner" <<'EOF'
#!/bin/sh
if ! uci -q get banner.banner >/dev/null 2>&1; then
	uci -q batch <<-EOT
		set banner.banner=banner
		set banner.banner.text='🎉 欢迎使用定制OpenWrt固件！'
		set banner.banner.color='#FF0000'
		set banner.banner.enabled='1'
		set banner.banner.update_url='https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
		set banner.banner.update_interval='600'
		set banner.banner.last_update='0'
		set banner.banner.auto_update_enabled='1'
		commit banner
	EOT
fi

# 创建cron任务
if [ ! -f /etc/cron.d/banner_auto_update ]; then
	echo "*/10 * * * * root /usr/bin/banner_auto_update.sh >/dev/null 2>&1" > /etc/cron.d/banner_auto_update
fi

exit 0
EOF
chmod +x "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner"

# ==================== 自动更新脚本 ====================
cat > "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'EOF'
#!/bin/sh

LOG_FILE="/var/log/banner_update.log"
UPDATE_URL=$(uci -q get banner.banner.update_url || echo "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json")
TEMP_FILE="/tmp/banner_update.$$"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

AUTO_UPDATE=$(uci -q get banner.banner.auto_update_enabled 2>/dev/null || echo "1")
if [ "$AUTO_UPDATE" != "1" ]; then
    exit 0
fi

LAST_UPDATE=$(uci -q get banner.banner.last_update 2>/dev/null || echo "0")
UPDATE_INTERVAL=$(uci -q get banner.banner.update_interval 2>/dev/null || echo "600")
CURRENT_TIME=$(date +%s)

if [ "$LAST_UPDATE" != "0" ] && [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$UPDATE_INTERVAL" ]; then
    exit 0
fi

log_msg "开始更新，URL: $UPDATE_URL"

if wget -q -T 30 -O "$TEMP_FILE" "$UPDATE_URL" 2>/dev/null; then
    if [ -s "$TEMP_FILE" ]; then
        NEW_TEXT=$(grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
        NEW_COLOR=$(grep -o '"color"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
        
        if [ -n "$NEW_TEXT" ] && [ -n "$NEW_COLOR" ]; then
            mkdir -p /tmp/banner_cache
            cp "$TEMP_FILE" /tmp/banner_cache/nav_data.json
            
            uci set banner.banner.text="$NEW_TEXT"
            uci set banner.banner.color="$NEW_COLOR"
            uci set banner.banner.last_update="$CURRENT_TIME"
            uci commit banner
            
            log_msg "更新成功"
        else
            log_msg "JSON解析失败"
        fi
    fi
else
    log_msg "下载失败"
fi

rm -f "$TEMP_FILE"
EOF
chmod +x "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh"

# ==================== Controller ====================
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
	entry({"admin", "system", "banner"}, cbi("banner"), "横幅设置", 60)
	entry({"admin", "status", "welfare_nav"}, call("show_banner_page"), "福利导航", 99)
end

function show_banner_page()
	local template = require "luci.template"
	local uci = require "luci.model.uci".cursor()
	
	local enabled = uci:get("banner", "banner", "enabled") or "1"
	if enabled ~= "1" then
		return
	end
	
	local banner_text = uci:get("banner", "banner", "text") or "Welcome"
	local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
	
	template.render("banner/display", {
		banner_text = banner_text,
		banner_color = banner_color
	})
end
EOF

# ==================== CBI模型 ====================
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
m = Map("banner", "横幅设置", "导航横幅配置")

s = m:section(TypedSection, "banner", "基本设置")
s.addremove = false
s.anonymous = true

enabled = s:option(Flag, "enabled", "启用横幅")
enabled.default = "1"

text = s:option(Value, "text", "横幅文字")
text.default = "欢迎使用OpenWrt"

color = s:option(ListValue, "color", "文字颜色")
color:value("#FF0000", "红色")
color:value("#0000FF", "蓝色")
color:value("#00FF00", "绿色")
color.default = "#FF0000"

update_section = m:section(TypedSection, "banner", "自动更新设置")
update_section.addremove = false
update_section.anonymous = true

auto_enabled = update_section:option(DummyValue, "auto_update_enabled", "启用自动更新")
auto_enabled.description = "从GitHub自动获取最新内容"
auto_enabled.cfgvalue = function(self, section)
    local value = m.uci:get("banner", section, "auto_update_enabled") or "1"
    return value == "1" and "已启用" or "已禁用"
end

update_url = update_section:option(DummyValue, "update_url", "更新地址")
update_url.description = "GitHub Raw地址"

update_interval = update_section:option(DummyValue, "update_interval", "更新间隔(秒)")
update_interval.description = "600=10分钟"

status_section = m:section(TypedSection, "banner", "更新状态")
status_section.addremove = false
status_section.anonymous = true

last_update = status_section:option(DummyValue, "last_update", "最后更新时间")
last_update.cfgvalue = function(self, section)
    local timestamp = m.uci:get("banner", section, "last_update") or "0"
    if timestamp == "0" then
        return "从未更新"
    else
        return os.date("%Y-%m-%d %H:%M:%S", tonumber(timestamp))
    end
end

manual_update = status_section:option(Button, "_manual_update", "手动更新")
manual_update.title = "立即从GitHub获取最新内容"
manual_update.inputtitle = "立即更新"
manual_update.inputstyle = "apply"

function manual_update.write(self, section)
    local sys = require "luci.sys"
    m.uci:set("banner", "banner", "last_update", "0")
    m.uci:commit("banner")
    sys.exec("/usr/bin/banner_auto_update.sh >/dev/null 2>&1")
    m.uci:load("banner")
end

return m
EOF

# ==================== 显示页面模板 ====================
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/display.htm" <<'EOF'
<%+header%>

<h2>福利导航</h2>

<%
local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"
local fs = require "nixio.fs"

local enabled = uci:get("banner", "banner", "enabled") or "1"
local banner_text = uci:get("banner", "banner", "text") or "Welcome"
local banner_color = uci:get("banner", "banner", "color") or "#FF0000"

local nav_data = nil
local nav_file = fs.readfile("/tmp/banner_cache/nav_data.json")
if nav_file then
    nav_data = jsonc.parse(nav_file)
end
%>

<style>
.nav-tabs {
    display: flex;
    border-bottom: 2px solid #ddd;
    margin: 20px 0 0 0;
    padding: 0;
    list-style: none;
    background: #f8f9fa;
}
.nav-tabs li {
    margin-right: 2px;
}
.nav-tabs a {
    display: block;
    padding: 12px 25px;
    background: #e9ecef;
    border: 1px solid #ddd;
    border-bottom: none;
    border-radius: 8px 8px 0 0;
    text-decoration: none;
    color: #495057;
    font-weight: 500;
    transition: all 0.3s;
}
.nav-tabs a:hover {
    background: #dee2e6;
}
.nav-tabs a.active {
    background: white;
    color: #007bff;
    border-color: #ddd #ddd white;
}
.tab-content {
    display: none;
    padding: 25px;
    border: 1px solid #ddd;
    background: white;
    min-height: 300px;
}
.tab-content.active {
    display: block;
}
.link-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 15px;
    margin-top: 15px;
}
.link-card {
    padding: 20px 15px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 10px;
    text-align: center;
    transition: all 0.3s;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}
.link-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 5px 15px rgba(0,0,0,0.2);
}
.link-card a {
    color: white;
    text-decoration: none;
    font-weight: 600;
    font-size: 14px;
}
.banner-box {
    text-align: center;
    margin: 20px 0;
    padding: 30px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 15px;
    color: white;
    box-shadow: 0 5px 20px rgba(0,0,0,0.15);
}
.contact-info {
    margin: 20px 0;
    padding: 20px;
    background: rgba(255,255,255,0.95);
    border-radius: 10px;
    display: flex;
    justify-content: center;
    gap: 30px;
    flex-wrap: wrap;
}
.contact-item {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #495057;
}
</style>

<div class="cbi-map">
    <div class="cbi-section">
        <% if enabled == "1" then %>
        <div class="banner-box">
            <div style="font-size: 1.8em; font-weight: bold; margin-bottom: 15px; text-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
                <%=pcdata(banner_text:gsub("\\n", "<br>"))%>
            </div>
            
            <div class="contact-info">
                <div class="contact-item">
                    <strong>📱 Telegram:</strong> 
                    <a href="https://t.me/fgnb111999" target="_blank" style="color: #007bff;">@fgnb111999</a>
                </div>
                <div class="contact-item">
                    <strong>💬 QQ:</strong> 
                    <span>183452852</span>
                </div>
            </div>
        </div>
        
        <% if nav_data and nav_data.nav_tabs then %>
        <div style="margin: 30px 0;">
            <h3 style="margin-bottom: 15px; color: #333;">🚀 快速导航</h3>
            
            <ul class="nav-tabs">
                <% for i, tab in ipairs(nav_data.nav_tabs) do %>
                <li>
                    <a href="#tab<%=i%>" onclick="showTab(<%=i%>); return false;" class="<%=i==1 and 'active' or ''%>" id="tab-link-<%=i%>">
                        <%=pcdata(tab.title)%>
                    </a>
                </li>
                <% end %>
            </ul>
            
            <% for i, tab in ipairs(nav_data.nav_tabs) do %>
            <div id="tab<%=i%>" class="tab-content <%=i==1 and 'active' or ''%>">
                <div class="link-grid">
                    <% for _, link in ipairs(tab.links) do %>
                    <div class="link-card">
                        <a href="<%=pcdata(link.url)%>" target="_blank"><%=pcdata(link.name)%></a>
                    </div>
                    <% end %>
                </div>
            </div>
            <% end %>
        </div>
        <% end %>
        
        <% else %>
        <div style="text-align: center; padding: 50px; color: #999;">
            <h2>横幅功能已禁用</h2>
        </div>
        <% end %>
    </div>
</div>

<script>
function showTab(tabIndex) {
    var contents = document.querySelectorAll('.tab-content');
    var links = document.querySelectorAll('.nav-tabs a');
    
    contents.forEach(function(content) {
        content.classList.remove('active');
    });
    
    links.forEach(function(link) {
        link.classList.remove('active');
    });
    
    document.getElementById('tab' + tabIndex).classList.add('active');
    document.getElementById('tab-link-' + tabIndex).classList.add('active');
}
</script>

<%+footer%>
EOF

# ==================== Makefile ====================
cat > "$CUSTOM_PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=3.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
	SECTION:=luci
	CATEGORY:=LuCI
	TITLE:=Navigation Banner System
	DEPENDS:=+luci-base +luci-compat +wget
	PKGARCH:=all
endef

define Package/luci-app-banner/description
	Remote-controlled navigation banner with GitHub integration
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
	$(INSTALL_DATA) ./luasrc/view/banner/display.htm $(1)/usr/lib/lua/luci/view/banner/display.htm

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/99-banner $(1)/etc/uci-defaults/99-banner

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/banner_auto_update.sh $(1)/usr/bin/banner_auto_update.sh
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
	( . /etc/uci-defaults/99-banner ) && rm -f /etc/uci-defaults/99-banner
	/etc/init.d/cron restart >/dev/null 2>&1 || true
}
exit 0
endef

define Package/luci-app-banner/prerm
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
	rm -f /etc/cron.d/banner_auto_update
	/etc/init.d/cron restart >/dev/null 2>&1 || true
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF

log_success "插件创建完成！"
log_info "插件位置: $CUSTOM_PKG_DIR"
log_info "GitHub JSON示例见下方"

# ==================== 示例JSON ====================
cat > "$CUSTOM_PKG_DIR/banner.json.example" <<'JSONEOF'
{
  "text": "🎉 欢迎使用定制固件！📱 专业技术支持",
  "color": "#FF0000",
  "nav_tabs": [
    {
      "title": "常用工具",
      "links": [
        {"name": "AI Bot", "url": "https://ai-bot.cn/"},
        {"name": "Claude AI", "url": "https://claude.ai/"}
      ]
    },
    {
      "title": "福利分享",
      "links": [
        {"name": "YouTube", "url": "https://youtube.com/"},
        {"name": "MediaFire", "url": "https://www.mediafire.com/"}
      ]
    },
    {
      "title": "防失联",
      "links": [
        {"name": "Telegram", "url": "https://t.me/fgnb111999"},
        {"name": "备用站", "url": "https://example.com/"}
      ]
    }
  ]
}
JSONEOF

log_info "JSON示例文件: $CUSTOM_PKG_DIR/banner.json.example"
