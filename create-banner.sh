#!/bin/bash
set -e

# 福利导航插件编译脚本 v2.0
# 功能：双源自动切换、滚动效果、日志显示、远程更新

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
         "$CUSTOM_PKG_DIR/root/usr/bin"

log_info "创建插件目录结构"

# ==================== UCI默认配置 ====================
cat > "$CUSTOM_PKG_DIR/root/etc/config/banner" <<'EOF'
config banner 'banner'
	option text '🎉 欢迎使用定制固件！📱 专业技术支持'
	option color '#FF0000'
	option enabled '1'
	option auto_update_enabled '1'
	option update_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option backup_url 'https://gitee.com/fgbfg5676/openwrt-banner/raw/master/banner.json'
	option update_interval '600'
	option last_update '0'
EOF
log_success "UCI默认配置已创建"

# ==================== UCI初始化脚本 ====================
cat > "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner" <<'EOF'
#!/bin/sh
if ! uci -q get banner.banner >/dev/null 2>&1; then
	uci -q batch <<-EOT
		set banner.banner=banner
		set banner.banner.text='🎉 欢迎使用定制固件！📱 专业技术支持'
		set banner.banner.color='#FF0000'
		set banner.banner.enabled='1'
		set banner.banner.auto_update_enabled='1'
		set banner.banner.update_url='https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
		set banner.banner.backup_url='https://gitee.com/fgbfg5676/openwrt-banner/raw/master/banner.json'
		set banner.banner.update_interval='600'
		set banner.banner.last_update='0'
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
log_success "UCI初始化脚本已创建"

# ==================== 自动更新脚本 ====================
cat > "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'EOF'
#!/bin/sh
LOG_FILE="/var/log/banner_update.log"
TEMP_FILE="/tmp/banner_update.$$"
MAX_LOG_LINES=50

if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_LINES ]; then
    tail -n $MAX_LOG_LINES "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

MANUAL_MODE="$1"

AUTO_UPDATE=$(uci -q get banner.banner.auto_update_enabled 2>/dev/null || echo "1")
[ "$AUTO_UPDATE" != "1" ] && [ "$MANUAL_MODE" != "manual" ] && exit 0

LAST_UPDATE=$(uci -q get banner.banner.last_update 2>/dev/null || echo "0")
UPDATE_INTERVAL=$(uci -q get banner.banner.update_interval 2>/dev/null || echo "600")
CURRENT_TIME=$(date +%s)

[ "$LAST_UPDATE" != "0" ] && [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$UPDATE_INTERVAL" ] && [ "$MANUAL_MODE" != "manual" ] && exit 0

PRIMARY_URL=$(uci -q get banner.banner.update_url || echo "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json")
BACKUP_URL=$(uci -q get banner.banner.backup_url || echo "https://gitee.com/fgbfg5676/openwrt-banner/raw/master/banner.json")

MANUAL_SOURCE=""
if [ -f /tmp/banner_manual_source ]; then
    MANUAL_SOURCE=$(cat /tmp/banner_manual_source)
    rm -f /tmp/banner_manual_source
    log_msg "手动更新，指定源：$MANUAL_SOURCE"
fi

try_download() {
    local url=$1 name=$2
    log_msg "尝试从 $name 下载..."
    for retry in 1 2 3; do
        if wget -q -T 20 -t 1 -O "$TEMP_FILE" "$url" 2>/dev/null && [ -s "$TEMP_FILE" ]; then
            if grep -q '"text"' "$TEMP_FILE" && grep -q '"color"' "$TEMP_FILE"; then
                log_msg "✓ $name 下载成功"
                return 0
            fi
        fi
        [ $retry -lt 3 ] && sleep 3
    done
    log_msg "✗ $name 下载失败"
    return 1
}

download_success=0
current_source=""

if [ "$MANUAL_SOURCE" = "github" ]; then
    if try_download "$PRIMARY_URL" "GitHub"; then
        download_success=1
        current_source="GitHub"
    fi
elif [ "$MANUAL_SOURCE" = "gitee" ]; then
    if try_download "$BACKUP_URL" "Gitee"; then
        download_success=1
        current_source="Gitee"
    fi
else
    if try_download "$PRIMARY_URL" "GitHub"; then
        download_success=1
        current_source="GitHub"
    elif try_download "$BACKUP_URL" "Gitee"; then
        download_success=1
        current_source="Gitee"
        uci set banner.banner.update_url="$BACKUP_URL"
        uci set banner.banner.backup_url="$PRIMARY_URL"
        uci commit banner
        log_msg "已自动切换主源到Gitee"
    fi
fi

if [ $download_success -eq 0 ]; then
    log_msg "✗✗✗ 更新失败：所有数据源不可用 ✗✗✗"
    rm -f "$TEMP_FILE"
    exit 1
fi

NEW_TEXT=$(grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
NEW_COLOR=$(grep -o '"color"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)

if [ -n "$NEW_TEXT" ] && [ -n "$NEW_COLOR" ]; then
    mkdir -p /tmp/banner_cache
    cp "$TEMP_FILE" /tmp/banner_cache/nav_data.json
    uci set banner.banner.text="$NEW_TEXT"
    uci set banner.banner.color="$NEW_COLOR"
    uci set banner.banner.last_update="$CURRENT_TIME"
    uci commit banner
    log_msg "✓✓✓ 更新成功（数据源：$current_source）✓✓✓"
else
    log_msg "✗ JSON解析失败"
fi
rm -f "$TEMP_FILE"
EOF
chmod +x "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh"
log_success "自动更新脚本已创建"

# ==================== Makefile ====================
cat > "$CUSTOM_PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=fgbfg5676 <niwo5507@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
	SECTION:=luci
	CATEGORY:=LuCI
	TITLE:=Welfare Navigation Banner System
	DEPENDS:=+luci-base +luci-compat +wget
	PKGARCH:=all
endef

define Package/luci-app-banner/description
	Welfare navigation system with dual-source auto-update (GitHub/Gitee)
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
	$(INSTALL_DATA) ./luasrc/view/banner/update_log.htm $(1)/usr/lib/lua/luci/view/banner/update_log.htm

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
log_success "Makefile已创建"

# ==================== Controller ====================
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
	entry({"admin", "system", "banner"}, cbi("banner"), "横幅设置", 60)
	entry({"admin", "status", "banner_display"}, call("show_banner_page"), "福利导航", 99)
end

function show_banner_page()
	local template = require "luci.template"
	local uci = require "luci.model.uci".cursor()
	
	local banner_text = uci:get("banner", "banner", "text") or "欢迎访问"
	local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
	
	template.render("banner/display", {
		banner_text = banner_text,
		banner_color = banner_color
	})
end
EOF
log_success "Controller已创建"

# ==================== CBI模型 ====================
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
m = Map("banner", "横幅设置", "福利导航配置管理")

s = m:section(TypedSection, "banner", "基本设置")
s.addremove = false
s.anonymous = true

enabled = s:option(DummyValue, "enabled", "启用横幅")
enabled.cfgvalue = function(self, section)
    return "✓ 已启用（系统锁定）"
end

text = s:option(Value, "text", "横幅文字")
text.default = "欢迎访问福利导航"

color = s:option(ListValue, "color", "文字颜色")
color:value("#FF0000", "红色")
color:value("#0000FF", "蓝色")
color:value("#00FF00", "绿色")
color:value("#FF6600", "橙色")
color.default = "#FF0000"

update_section = m:section(TypedSection, "banner", "自动更新设置")
update_section.addremove = false
update_section.anonymous = true

auto_enabled = update_section:option(DummyValue, "auto_update_enabled", "启用自动更新")
auto_enabled.cfgvalue = function(self, section)
    return "✓ 已启用（系统锁定）"
end

current_source = update_section:option(DummyValue, "_current_source", "当前数据源")
current_source.cfgvalue = function(self, section)
    local url = m.uci:get("banner", section, "update_url") or ""
    if url:match("github") or url:match("githubusercontent") then
        return "GitHub"
    elseif url:match("gitee") then
        return "Gitee"
    else
        return "未知"
    end
end

update_interval = update_section:option(DummyValue, "update_interval", "更新间隔")
update_interval.cfgvalue = function(self, section)
    local interval = m.uci:get("banner", section, "update_interval") or "600"
    return interval .. "秒"
end

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

update_result = status_section:option(DummyValue, "_update_result", "更新结果")
update_result.cfgvalue = function(self, section)
    local sys = require "luci.sys"
    local last_line = sys.exec("tail -n 1 /var/log/banner_update.log 2>/dev/null")
    if last_line:match("更新成功") then
        return "✓ 更新成功"
    elseif last_line:match("失败") or last_line:match("不可用") then
        return "✗ 更新失败"
    else
        return "待更新"
    end
end

manual_source = status_section:option(ListValue, "_manual_source", "手动更新数据源")
manual_source:value("auto", "自动选择（先GitHub后Gitee）")
manual_source:value("github", "仅GitHub")
manual_source:value("gitee", "仅Gitee")
manual_source.default = "auto"

manual_update = status_section:option(Button, "_manual_update", "手动更新")
manual_update.inputtitle = "立即更新"
manual_update.inputstyle = "apply"

function manual_update.write(self, section)
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local selected_source = http.formvalue("cbid.banner.banner._manual_source") or "auto"
    
    if selected_source == "github" then
        sys.exec("echo 'github' > /tmp/banner_manual_source")
    elseif selected_source == "gitee" then
        sys.exec("echo 'gitee' > /tmp/banner_manual_source")
    else
        sys.exec("rm -f /tmp/banner_manual_source")
    end
    
    m.uci:set("banner", "banner", "last_update", "0")
    m.uci:commit("banner")
    sys.exec("/usr/bin/banner_auto_update.sh manual >/dev/null 2>&1 &")
    sys.exec("sleep 2")
    m.uci:load("banner")
end

log_section = m:section(TypedSection, "banner", "更新日志")
log_section.addremove = false
log_section.anonymous = true
log_section.template = "banner/update_log"

return m
EOF
log_success "CBI模型已创建"

# ==================== 显示页面 ====================
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/display.htm" <<'EOF'
<%+header%>
<h2>福利导航</h2>
<%
local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"
local fs = require "nixio.fs"
local banner_text = uci:get("banner", "banner", "text") or "欢迎访问福利导航"
local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
local nav_data = nil
local nav_file = fs.readfile("/tmp/banner_cache/nav_data.json")
if nav_file then nav_data = jsonc.parse(nav_file) end
%>
<style>
.nav-tabs{display:flex;border-bottom:2px solid #ddd;margin:20px 0 0;padding:0;list-style:none;background:#f8f9fa}
.nav-tabs li{margin-right:2px}
.nav-tabs a{display:block;padding:12px 25px;background:#e9ecef;border:1px solid #ddd;border-bottom:none;border-radius:8px 8px 0 0;text-decoration:none;color:#495057;font-weight:500;transition:all .3s}
.nav-tabs a:hover{background:#dee2e6}
.nav-tabs a.active{background:white;color:#007bff;border-color:#ddd #ddd white}
.tab-content{display:none;padding:25px;border:1px solid #ddd;background:white;min-height:300px}
.tab-content.active{display:block}
.link-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:15px;margin-top:15px}
.link-card{padding:20px 15px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);border-radius:10px;text-align:center;transition:all .3s;box-shadow:0 2px 5px rgba(0,0,0,.1)}
.link-card:hover{transform:translateY(-5px);box-shadow:0 5px 15px rgba(0,0,0,.2)}
.link-card a{color:white;text-decoration:none;font-weight:600}
.scroll-container{overflow:hidden;height:60px;line-height:60px}
.scroll-text{display:inline-block;white-space:nowrap;animation:scroll-left 20s linear infinite}
@keyframes scroll-left{0%{transform:translateX(100%)}100%{transform:translateX(-100%)}}
</style>
<div class="cbi-map"><div class="cbi-section">
<div style="text-align:center;margin:20px 0;padding:30px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);border-radius:15px;color:white;box-shadow:0 5px 20px rgba(0,0,0,.15)">
<div class="scroll-container">
<div class="scroll-text" style="color:<%=banner_color%>;font-size:1.8em;font-weight:bold">
<%=pcdata(banner_text:gsub("\\n"," · "))%>
</div>
</div>
<div style="margin:20px 0;padding:20px;background:rgba(255,255,255,.9);border-radius:10px;display:flex;justify-content:center;gap:20px;color:#495057;flex-wrap:wrap;font-size:0.95em">
<div>📱 Telegram: <a href="https://t.me/fgnb111999" target="_blank" style="color:#007bff">@fgnb111999</a></div>
<div>💬 QQ: 183452852</div>
<div>📧 Email: <a href="mailto:niwo5507@gmail.com" style="color:#007bff">niwo5507@gmail.com</a></div>
</div></div>
<% if nav_data and nav_data.nav_tabs then %>
<div style="margin:30px 0"><h3 style="margin-bottom:15px">🚀 快速导航</h3>
<ul class="nav-tabs">
<% for i,tab in ipairs(nav_data.nav_tabs) do %>
<li><a href="#tab<%=i%>" onclick="showTab(<%=i%>);return false" class="<%=i==1 and 'active' or ''%>" id="tab-link-<%=i%>"><%=pcdata(tab.title)%></a></li>
<% end %>
</ul>
<% for i,tab in ipairs(nav_data.nav_tabs) do %>
<div id="tab<%=i%>" class="tab-content <%=i==1 and 'active' or ''%>">
<div class="link-grid">
<% for _,link in ipairs(tab.links) do %>
<div class="link-card"><a href="<%=pcdata(link.url)%>" target="_blank"><%=pcdata(link.name)%></a></div>
<% end %>
</div></div>
<% end %>
</div>
<% end %>
</div></div>
<script>function showTab(i){document.querySelectorAll('.tab-content').forEach(c=>c.classList.remove('active'));document.querySelectorAll('.nav-tabs a').forEach(l=>l.classList.remove('active'));document.getElementById('tab'+i).classList.add('active');document.getElementById('tab-link-'+i).classList.add('active')}</script>
<%+footer%>
EOF
log_success "显示页面已创建"

# ==================== 日志模板 ====================
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/update_log.htm" <<'EOF'
<%
local sys = require "luci.sys"
local log_content = sys.exec("tail -n 30 /var/log/banner_update.log 2>/dev/null || echo '暂无日志记录'")
%>
<style>
.log-container{background:#1e1e1e;color:#d4d4d4;padding:15px;border-radius:5px;font-family:'Courier New',monospace;font-size:12px;max-height:400px;overflow-y:auto;white-space:pre-wrap}
</style>
<div class="cbi-section">
<div class="log-container"><%=pcdata(log_content)%></div>
</div>
EOF
log_success "日志模板已创建"

# ==================== 验证文件结构 ====================
log_info "插件文件结构:"
find "$CUSTOM_PKG_DIR" -type f | sort

log_success "======================================"
log_success "福利导航插件创建完成！"
log_success "======================================"
log_info "功能特性："
log_info "✓ 双源自动切换（GitHub/Gitee）"
log_info "✓ 滚动横幅效果"
log_info "✓ 手动更新支持源选择"
log_info "✓ 实时日志显示"
log_info "✓ 联系方式：Telegram/QQ/Email"
log_info "✓ 远程导航链接管理"
log_info ""
log_info "编译配置："
log_info "CONFIG_PACKAGE_luci-app-banner=y"
log_info ""
log_info "GitHub仓库配置："
log_info "1. 主源: https://github.com/fgbfg5676/openwrt-banner"
log_info "2. 备源: https://gitee.com/fgbfg5676/openwrt-banner"
log_info "3. 需要创建 banner.json 文件"
log_info ""
log_info "示例 banner.json:"
log_info '{"text":"🎉 欢迎访问！","color":"#FF0000","nav_tabs":[{"title":"常用工具","links":[{"name":"示例","url":"https://example.com/"}]}]}'
