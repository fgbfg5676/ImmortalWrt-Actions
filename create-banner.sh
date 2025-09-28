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
         "$CUSTOM_PKG_DIR/root/etc/uci-defaults" \
         "$CUSTOM_PKG_DIR/root/usr/bin" \
         "$CUSTOM_PKG_DIR/po/zh-cn"
log_info "优化版插件文件夹已创建: $CUSTOM_PKG_DIR"

# -------------------- UCI默认配置（包含自动更新） --------------------
cat > "$CUSTOM_PKG_DIR/root/etc/config/banner" <<'EOF'
config banner 'banner'
	option text '🎉 欢迎使用定制OpenWrt固件！\n📱 技术支持请联系作者\n💬 专业固件定制服务'
	option color '#FF0000'
	option enabled '1'
	option remote_update '1'
	option update_url 'https://cdn.jsdelivr.net/gh/fgbfg5676/openwrt-banner@main/banner.json'
	option update_interval '3600'
	option last_update '0'
	option author_mode '0'
	option admin_password_hash 'e3afed0047b08059d0fada10f400c1e5'
	option auto_update_enabled '1'
	option first_boot '1'
EOF
log_success "UCI默认配置已创建（包含GitHub自动更新）"

# -------------------- UCI Defaults脚本（启动时自动更新） --------------------
cat > "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner" <<'EOF'
#!/bin/sh
# 优化版UCI初始化脚本 - 支持首次启动自动更新
if ! uci -q get banner.banner >/dev/null 2>&1; then
	uci -q batch <<-EOT >/dev/null 2>&1
		set banner.banner=banner
		set banner.banner.text='🎉 欢迎使用定制OpenWrt固件！\n📱 技术支持请联系作者\n💬 专业固件定制服务'
		set banner.banner.color='#FF0000'
		set banner.banner.enabled='1'
		set banner.banner.remote_update='1'
		set banner.banner.update_url='https://cdn.jsdelivr.net/gh/fgbfg5676/openwrt-banner@main/banner.json'
		set banner.banner.update_interval='3600'
		set banner.banner.last_update='0'
		set banner.banner.author_mode='0'
		set banner.banner.admin_password_hash='e3afed0047b08059d0fada10f400c1e5'
		set banner.banner.auto_update_enabled='1'
		set banner.banner.first_boot='1'
		commit banner
	EOT
fi

# 添加自动更新的cron任务
if [ ! -f /etc/cron.d/banner_auto_update ]; then
	echo "*/10 * * * * root /usr/bin/banner_auto_update.sh >/dev/null 2>&1" > /etc/cron.d/banner_auto_update
fi

# 添加首次启动更新任务（延迟5分钟执行，确保网络就绪）
if [ ! -f /etc/cron.d/banner_first_update ]; then
	echo "@reboot root sleep 300 && /usr/bin/banner_first_update.sh >/dev/null 2>&1" > /etc/cron.d/banner_first_update
fi

exit 0
EOF
chmod +x "$CUSTOM_PKG_DIR/root/etc/uci-defaults/99-banner"
log_success "UCI defaults脚本已创建（包含自动启动更新）"

# -------------------- 自动更新脚本 --------------------
cat > "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'EOF'
#!/bin/sh

# 自动横幅更新脚本 - 针对GitHub + jsDelivr优化
UCI_CONFIG="banner"
LOCK_FILE="/var/lock/banner_update.lock"
LOG_FILE="/var/log/banner_update.log"
MAX_LOG_SIZE=5120  # 5KB

# 日志轮转
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
    tail -n 30 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

# 防重复执行
[ -f "$LOCK_FILE" ] && exit 0
touch "$LOCK_FILE"
cleanup() { rm -f "$LOCK_FILE"; }
trap cleanup EXIT

# 日志函数
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AUTO] $*" >> "$LOG_FILE"
}

# 检查功能是否启用
AUTO_UPDATE=$(uci -q get banner.banner.auto_update_enabled 2>/dev/null || echo "1")
REMOTE_UPDATE=$(uci -q get banner.banner.remote_update 2>/dev/null || echo "1")
[ "$AUTO_UPDATE" != "1" ] || [ "$REMOTE_UPDATE" != "1" ] && exit 0

# 获取配置
UPDATE_URL=$(uci -q get banner.banner.update_url 2>/dev/null || echo "")
UPDATE_INTERVAL=$(uci -q get banner.banner.update_interval 2>/dev/null || echo "3600")
LAST_UPDATE=$(uci -q get banner.banner.last_update 2>/dev/null || echo "0")

# 检查URL
if [ -z "$UPDATE_URL" ] || [ "$UPDATE_URL" = "https://cdn.jsdelivr.net/gh/your-username/openwrt-banner@main/banner.json" ]; then
    # 使用默认URL
    UPDATE_URL="https://cdn.jsdelivr.net/gh/fgbfg5676/openwrt-banner@main/banner.json"
    uci set banner.banner.update_url="$UPDATE_URL"
    uci commit banner
fi

# 检查更新间隔
CURRENT_TIME=$(date +%s)
if [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$UPDATE_INTERVAL" ]; then
    exit 0
fi

log_msg "开始自动更新，URL: $UPDATE_URL"

# 多重下载机制
TEMP_FILE="/tmp/banner_update.$$"
download_success=0

for retry in 1 2 3; do
    # 优先使用wget
    if command -v wget >/dev/null 2>&1; then
        if wget -q -T 20 -t 1 --user-agent="OpenWrt-Banner/2.0" -O "$TEMP_FILE" "$UPDATE_URL" 2>/dev/null; then
            download_success=1
            break
        fi
    fi
    
    # 备用curl
    if command -v curl >/dev/null 2>&1; then
        if curl -s -L --max-time 20 --user-agent "OpenWrt-Banner/2.0" -o "$TEMP_FILE" "$UPDATE_URL" 2>/dev/null; then
            download_success=1
            break
        fi
    fi
    
    [ $retry -lt 3 ] && sleep 10
done

if [ $download_success -eq 0 ]; then
    log_msg "下载失败，所有重试均失败"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 验证下载内容
if [ ! -s "$TEMP_FILE" ]; then
    log_msg "下载文件为空"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 解析JSON（兼容性解析）
if command -v jq >/dev/null 2>&1; then
    NEW_TEXT=$(jq -r '.text // empty' "$TEMP_FILE" 2>/dev/null)
    NEW_COLOR=$(jq -r '.color // empty' "$TEMP_FILE" 2>/dev/null)
else
    # 使用sed解析（更好的兼容性）
    NEW_TEXT=$(grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    NEW_COLOR=$(grep -o '"color"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEMP_FILE" | sed 's/.*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
fi

# 验证解析结果
if [ -z "$NEW_TEXT" ] || [ -z "$NEW_COLOR" ]; then
    log_msg "JSON解析失败"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 验证颜色格式
if ! echo "$NEW_COLOR" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
    log_msg "颜色格式无效: $NEW_COLOR"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 检查内容变化
CURRENT_TEXT=$(uci -q get banner.banner.text 2>/dev/null || echo "")
CURRENT_COLOR=$(uci -q get banner.banner.color 2>/dev/null || echo "")

if [ "$NEW_TEXT" = "$CURRENT_TEXT" ] && [ "$NEW_COLOR" = "$CURRENT_COLOR" ]; then
    log_msg "内容无变化，跳过更新"
    rm -f "$TEMP_FILE"
    exit 0
fi

# 更新配置
uci set banner.banner.text="$NEW_TEXT"
uci set banner.banner.color="$NEW_COLOR" 
uci set banner.banner.last_update="$CURRENT_TIME"

if uci commit banner 2>/dev/null; then
    log_msg "横幅内容已自动更新: $(echo "$NEW_TEXT" | cut -c1-30)..., 颜色: $NEW_COLOR"
else
    log_msg "UCI提交失败"
fi

rm -f "$TEMP_FILE"
EOF
chmod +x "$CUSTOM_PKG_DIR/root/usr/bin/banner_auto_update.sh"

# -------------------- 首次启动更新脚本 --------------------
cat > "$CUSTOM_PKG_DIR/root/usr/bin/banner_first_update.sh" <<'EOF'
#!/bin/sh

# 首次启动更新脚本 - 确保新固件立即获取最新内容
LOG_FILE="/var/log/banner_update.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FIRST] $*" >> "$LOG_FILE"
}

# 检查是否首次启动
FIRST_BOOT=$(uci -q get banner.banner.first_boot 2>/dev/null || echo "0")
if [ "$FIRST_BOOT" != "1" ]; then
    exit 0
fi

log_msg "检测到首次启动，开始初始化横幅更新..."

# 等待网络就绪
for i in $(seq 1 12); do
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_msg "网络连接正常"
        break
    fi
    [ $i -eq 12 ] && { log_msg "网络连接超时"; exit 1; }
    sleep 10
done

# 强制执行首次更新
/usr/bin/banner_auto_update.sh

# 标记已完成首次启动
uci set banner.banner.first_boot='0'
uci commit banner

# 移除首次启动任务
rm -f /etc/cron.d/banner_first_update
/etc/init.d/cron restart >/dev/null 2>&1

log_msg "首次启动更新完成"
EOF
chmod +x "$CUSTOM_PKG_DIR/root/usr/bin/banner_first_update.sh"

# -------------------- 中文翻译文件 --------------------
cat > "$CUSTOM_PKG_DIR/po/zh-cn/banner.po" <<'EOF'
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\n"
"Language: zh_CN\n"

msgid "Banner"
msgstr "横幅广告"

msgid "Banner Settings"
msgstr "横幅设置"

msgid "Configure banner text and appearance"
msgstr "配置横幅文字和外观"

msgid "Banner Configuration"
msgstr "横幅配置"

msgid "Banner Text"
msgstr "横幅文字"

msgid "Text Color"
msgstr "文字颜色"

msgid "Black"
msgstr "黑色"

msgid "Red"
msgstr "红色"

msgid "Green"
msgstr "绿色"

msgid "Blue"
msgstr "蓝色"

msgid "Orange"
msgstr "橙色"

msgid "Purple"
msgstr "紫色"

msgid "Banner Display"
msgstr "横幅显示"

msgid "Contact Information"
msgstr "联系信息"

msgid "Author Settings"
msgstr "作者设置"

msgid "Enable Banner"
msgstr "启用横幅"

msgid "Password"
msgstr "密码"

msgid "Enter admin password to modify settings"
msgstr "输入管理员密码以修改设置"

msgid "Auto Update Settings"
msgstr "自动更新设置"

msgid "Enable Auto Update"
msgstr "启用自动更新"

msgid "Update URL"
msgstr "更新地址"

msgid "Update Interval (seconds)"
msgstr "更新间隔（秒）"

msgid "GitHub Repository URL for banner content"
msgstr "横幅内容的GitHub仓库地址"

msgid "Invalid password!"
msgstr "密码错误！"

msgid "Settings saved successfully!"
msgstr "设置保存成功！"

msgid "Auto update status"
msgstr "自动更新状态"

msgid "Last update time"
msgstr "最后更新时间"

msgid "Network connection required"
msgstr "需要网络连接"
EOF
log_success "中文翻译文件已创建"

# -------------------- 优化的Makefile --------------------
cat > "$CUSTOM_PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.1
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=fgbfg5676 <niwo5507@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
	SECTION:=luci
	CATEGORY:=LuCI
	TITLE:=Auto-Update Banner System
	DEPENDS:=+luci-base +luci-compat +wget +coreutils-md5sum
	PKGARCH:=all
endef

define Package/luci-app-banner/description
	Enhanced Banner plugin with auto-update, password protection and Chinese interface.
	Features: GitHub integration, automatic updates, contact information display.
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
	$(INSTALL_DATA) ./luasrc/view/banner/password_form.htm $(1)/usr/lib/lua/luci/view/banner/password_form.htm

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/banner

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/99-banner $(1)/etc/uci-defaults/99-banner

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/banner_auto_update.sh $(1)/usr/bin/banner_auto_update.sh
	$(INSTALL_BIN) ./root/usr/bin/banner_first_update.sh $(1)/usr/bin/banner_first_update.sh

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./po/zh-cn/banner.po $(1)/usr/lib/lua/luci/i18n/banner.zh-cn.po
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
	( . /etc/uci-defaults/99-banner ) && rm -f /etc/uci-defaults/99-banner
	# 重启cron服务加载定时任务
	/etc/init.d/cron restart >/dev/null 2>&1 || true
	# 立即触发首次更新（如果是首次安装）
	if [ "$(uci -q get banner.banner.first_boot 2>/dev/null)" = "1" ]; then
		nohup sh -c 'sleep 60 && /usr/bin/banner_first_update.sh' >/dev/null 2>&1 &
	fi
}
exit 0
endef

define Package/luci-app-banner/prerm
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
	# 清理定时任务
	rm -f /etc/cron.d/banner_auto_update
	rm -f /etc/cron.d/banner_first_update
	/etc/init.d/cron restart >/dev/null 2>&1 || true
	# 清理日志文件
	rm -f /var/log/banner_update.log
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF
log_success "优化的Makefile已创建（支持自动更新）"

# -------------------- 增强的Controller --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/banner") then
		return
	end
	
	entry({"admin", "system", "banner"}, cbi("banner"), _("横幅设置"), 50).dependent = false
	entry({"admin", "status", "banner_display"}, call("show_banner_page"), _("横幅显示"), 99)
	entry({"admin", "system", "banner", "auth"}, call("check_password"), nil).leaf = true
	entry({"admin", "system", "banner", "status"}, call("update_status"), nil).leaf = true
end

function show_banner_page()
	local template = require "luci.template"
	local uci = require "luci.model.uci".cursor()
	
	-- 检查是否启用
	local enabled = uci:get("banner", "banner", "enabled") or "1"
	if enabled ~= "1" then
		return
	end
	
	local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
	local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
	
	template.render("banner/display", {
		banner_text = banner_text,
		banner_color = banner_color
	})
end

function check_password()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	
	local password = http.formvalue("password")
	local stored_hash = uci:get("banner", "banner", "admin_password_hash") or "e3afed0047b08059d0fada10f400c1e5"
	
	if password then
		local input_hash = util.exec("echo -n '" .. password .. "' | md5sum | cut -d' ' -f1"):gsub("%s+", "")
		
		if input_hash == stored_hash then
			uci:set("banner", "banner", "author_mode", "1")
			uci:commit("banner")
			http.header("Content-Type", "application/json")
			http.write('{"success": true, "message": "验证成功，正在加载设置界面..."}')
		else
			http.header("Content-Type", "application/json")
			http.write('{"success": false, "message": "密码错误！请联系作者获取正确密码"}')
		end
	else
		http.header("Content-Type", "application/json")
		http.write('{"success": false, "message": "请输入密码"}')
	end
end

function update_status()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local sys = require "luci.sys"
	
	-- 获取更新状态信息
	local last_update = uci:get("banner", "banner", "last_update") or "0"
	local auto_enabled = uci:get("banner", "banner", "auto_update_enabled") or "1"
	local update_url = uci:get("banner", "banner", "update_url") or ""
	
	-- 读取日志
	local log_content = sys.exec("tail -n 10 /var/log/banner_update.log 2>/dev/null || echo '暂无日志'")
	
	http.header("Content-Type", "application/json")
	http.write(string.format([[{
		"last_update": %s,
		"auto_enabled": "%s",
		"update_url": "%s",
		"log": "%s"
	}]], last_update, auto_enabled, update_url, log_content:gsub('"', '\\"'):gsub('\n', '\\n')))
end
EOF
log_success "增强的Controller已生成（支持状态查询）"

# -------------------- 带密码保护的CBI模型 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/model/cbi/banner.lua" <<'EOF'
local m, s, o
local uci = require "luci.model.uci".cursor()

-- 检查作者模式
local author_mode = uci:get("banner", "banner", "author_mode") or "0"
local is_author = (author_mode == "1")

m = Map("banner", translate("横幅设置"), translate("自动更新横幅管理系统 - 基于GitHub + jsDelivr"))

-- 密码验证界面
if not is_author then
	local auth_section = m:section(SimpleSection, translate("作者验证"))
	auth_section.template = "banner/password_form"
	return m
end

-- 基本配置
s = m:section(TypedSection, "banner", translate("横幅配置"))
s.addremove = false
s.anonymous = true

o = s:option(Flag, "enabled", translate("启用横幅显示"))
o.default = "1"

o = s:option(Value, "text", translate("横幅文字"))
o.placeholder = "🎉 欢迎使用定制OpenWrt固件！"
o.default = "🎉 欢迎使用定制OpenWrt固件！\n📱 技术支持请联系作者"
o.rmempty = false
o.description = translate("支持\\n换行符和emoji表情")

-- 颜色选择
o = s:option(ListValue, "color", translate("文字颜色"))
o:value("#000000", translate("黑色"))
o:value("#FF0000", translate("红色"))
o:value("#00FF00", translate("绿色"))
o:value("#0000FF", translate("蓝色"))
o:value("#FF6600", translate("橙色"))
o:value("#800080", translate("紫色"))
o.default = "#FF0000"

-- 自动更新设置
local update_section = m:section(TypedSection, "banner", translate("自动更新设置"))
update_section.addremove = false
update_section.anonymous = true

o = update_section:option(Flag, "auto_update_enabled", translate("启用自动更新"))
o.default = "1" 
o.description = translate("关闭后将停止从GitHub自动获取更新")

o = update_section:option(Flag, "remote_update", translate("启用远程更新"))
o.default = "1"
o:depends("auto_update_enabled", "1")

o = update_section:option(Value, "update_url", translate("GitHub jsDelivr地址"))
o.default = "https://cdn.jsdelivr.net/gh/fgbfg5676/openwrt-banner@main/banner.json"
o:depends("remote_update", "1")
o.description = translate("默认使用作者仓库，可以修改为你的GitHub地址")

o = update_section:option(Value, "update_interval", translate("更新间隔（秒）"))
o.default = "3600"  -- 1小时
o.datatype = "uinteger"
o:depends("remote_update", "1")
o.description = translate("3600=1小时, 86400=24小时, 建议不少于1小时")

-- 状态显示
local status_section = m:section(SimpleSection, translate("更新状态"))
status_section.template = "cbi/nullsection"

local status_display = status_section:option(DummyValue, "_status", "")
status_display.template = "banner/status_display"

-- 预览区域
local preview_section = m:section(SimpleSection, translate("预览效果"))
preview_section.template = "banner/preview_simple"

-- 退出作者模式
function m.on_after_save(self)
	uci:set("banner", "banner", "author_mode", "0")
	uci:commit("banner")
end

return m
EOF
log_success "带密码保护的CBI模型已生成"

# -------------------- 密码表单模板 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/password_form.htm" <<'EOF'
<style>
.banner-auth {
	max-width: 500px;
	margin: 20px auto;
	padding: 30px;
	background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
	border-radius: 12px;
	color: white;
	text-align: center;
	box-shadow: 0 8px 25px rgba(0,0,0,0.15);
}
.auth-card {
	background: rgba(255,255,255,0.1);
	padding: 25px;
	border-radius: 8px;
	backdrop-filter: blur(10px);
}
.password-input {
	padding: 12px;
	font-size: 16px;
	border: none;
	border-radius: 6px;
	width: 100%;
	max-width: 250px;
	margin: 15px 0;
}
.auth-btn {
	padding: 12px 25px;
	font-size: 16px;
	background: #4CAF50;
	color: white;
	border: none;
	border-radius: 6px;
	cursor: pointer;
	margin: 10px;
}
.auth-btn:hover { background: #45a049; }
.message {
	margin: 15px 0;
	padding: 10px;
	border-radius: 4px;
}
.success { background: rgba(76, 175, 80, 0.8); }
.error { background: rgba(244, 67, 54, 0.8); }
.info-box {
	margin: 20px 0;
	padding: 15px;
	background: rgba(255,255,255,0.1);
	border-radius: 6px;
	font-size: 0.9em;
}
</style>

<div class="banner-auth">
	<h2>🔐 横幅管理系统</h2>
	<div class="auth-card">
		<h3>作者验证</h3>
		<div id="message" class="message" style="display: none;"></div>
		<form id="auth-form" onsubmit="return checkPassword(event);">
			<input type="password" id="admin-password" class="password-input" 
				   placeholder="输入管理员密码" required>
			<br>
			<button type="submit" class="auth-btn">🚀 进入管理</button>
		</form>
		
		<div class="info-box">
			<h4>🎯 系统特性</h4>
			<p>✅ 自动更新：编译后立即生效</p>
			<p>✅ GitHub集成：免费CDN加速</p>
			<p>✅ 密码保护：防止客户修改</p>
			<p>✅ 中文界面：完全本地化</p>
			
			<h4>📞 技术支持</h4>
			<p>📱 Telegram: <a href="https://t.me/fgnb111999" style="color: #FFD700;">https://t.me/fgnb111999</a></p>
			<p>💬 QQ: <span style="color: #FFD700;">183452852</span></p>
			
			<p style="margin-top: 15px; font-size: 0.8em; opacity: 0.8;">
				默认密码: hello
			</p>
		</div>
	</div>
</div>

<script>
function checkPassword(event) {
	event.preventDefault();
	
	const password = document.getElementById('admin-password').value;
	const messageDiv = document.getElementById('message');
	
	const xhr = new XMLHttpRequest();
	xhr.open('POST', '<%=url("admin/system/banner/auth")%>', true);
	xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
	
	xhr.onreadystatechange = function() {
		if (xhr.readyState === 4) {
			try {
				const response = JSON.parse(xhr.responseText);
				messageDiv.style.display = 'block';
				messageDiv.textContent = response.message;
				
				if (response.success) {
					messageDiv.className = 'message success';
					setTimeout(() => {
						window.location.reload();
					}, 1500);
				} else {
					messageDiv.className = 'message error';
				}
			} catch (e) {
				messageDiv.style.display = 'block';
				messageDiv.className = 'message error';
				messageDiv.textContent = '网络连接错误';
			}
		}
	};
	
	xhr.send('password=' + encodeURIComponent(password));
	return false;
}
</script>
EOF

# -------------------- 状态显示模板 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/status_display.htm" <<'EOF'
<%
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

local auto_enabled = uci:get("banner", "banner", "auto_update_enabled") or "1"
local last_update = uci:get("banner", "banner", "last_update") or "0"
local update_url = uci:get("banner", "banner", "update_url") or ""
local first_boot = uci:get("banner", "banner", "first_boot") or "0"
%>

<div style="background: #f8f9fa; padding: 15px; border-radius: 6px; margin: 10px 0;">
	<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
		<div style="text-align: center;">
			<div style="font-size: 1.2em; color: <%= auto_enabled == '1' and '#4CAF50' or '#999' %>;">
				<%= auto_enabled == '1' and '🟢 已启用' or '⭕ 已禁用' %>
			</div>
			<div style="font-size: 0.9em; color: #666;">自动更新状态</div>
		</div>
		
		<div style="text-align: center;">
			<div style="font-size: 1.2em; color: #666;">
				<% if last_update == "0" then %>
					⏳ 等待首次更新
				<% else %>
					📅 <%=os.date("%m-%d %H:%M", tonumber(last_update))%>
				<% end %>
			</div>
			<div style="font-size: 0.9em; color: #666;">最后更新时间</div>
		</div>
		
		<div style="text-align: center;">
			<div style="font-size: 1.2em; color: <%= first_boot == '1' and '#FF6600' or '#4CAF50' %>;">
				<%= first_boot == '1' and '🚀 初始化中' or '✅ 运行正常' %>
			</div>
			<div style="font-size: 0.9em; color: #666;">系统状态</div>
		</div>
	</div>
	
	<% if update_url ~= "" then %>
	<div style="margin-top: 10px; padding: 8px; background: #e9ecef; border-radius: 4px; font-size: 0.85em;">
		<strong>📡 更新源:</strong> <%=pcdata(update_url:gsub("https://cdn.jsdelivr.net/gh/", "GitHub: "):gsub("@main/banner.json", ""))%>
	</div>
	<% end %>
</div>
EOF

# -------------------- 增强的预览模板 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/preview_simple.htm" <<'EOF'
<%
local uci = require "luci.model.uci".cursor()
local enabled = uci:get("banner", "banner", "enabled") or "1"
local banner_text = uci:get("banner", "banner", "text") or "Welcome to OpenWrt"
local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
local auto_update = uci:get("banner", "banner", "auto_update_enabled") or "1"
%>

<div class="cbi-value">
	<div style="margin: 10px 0; padding: 20px; border: 2px solid <%= enabled == '1' and '#4CAF50' or '#999' %>; background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border-radius: 8px;">
		<% if enabled == "1" then %>
			<div style="text-align: center; margin-bottom: 15px;">
				<strong style="color: <%=banner_color%>; font-size: 1.4em; line-height: 1.4;">
					<%=pcdata(banner_text:gsub("\\n", "<br>"))%>
				</strong>
			</div>
			
			<div style="text-align: center; margin: 15px 0; padding: 12px; border: 1px solid #ddd; border-radius: 5px; background: rgba(255,255,255,0.8);">
				<div style="margin: 5px 0;">
					<strong>📱 Telegram:</strong> 
					<a href="https://t.me/fgnb111999" target="_blank" style="color: #0088cc;">https://t.me/fgnb111999</a>
				</div>
				<div style="margin: 5px 0;">
					<strong>💬 QQ:</strong> 
					<span style="color: #666;">183452852</span>
				</div>
			</div>
			
			<% if auto_update == "1" then %>
			<div style="text-align: center; font-size: 0.8em; color: #4CAF50; margin-top: 10px;">
				🔄 自动更新已启用 - 内容将定期同步
			</div>
			<% else %>
			<div style="text-align: center; font-size: 0.8em; color: #FF6600; margin-top: 10px;">
				⏸️ 自动更新已暂停
			</div>
			<% end %>
		<% else %>
			<div style="text-align: center; color: #999;">
				<h3>❌ 横幅显示已禁用</h3>
				<p>勾选上方"启用横幅显示"以显示内容</p>
			</div>
		<% end %>
	</div>
</div>
EOF

# -------------------- 增强的显示页面 --------------------
cat > "$CUSTOM_PKG_DIR/luasrc/view/banner/display.htm" <<'EOF'
<%+header%>

<h2 name="content"><%:横幅显示%></h2>

<%
local uci = require "luci.model.uci".cursor()
local enabled = uci:get("banner", "banner", "enabled") or "1"
local banner_text = uci:get("banner", "banner", "text") or "🎉 欢迎使用定制OpenWrt固件！"
local banner_color = uci:get("banner", "banner", "color") or "#FF0000"
local last_update = uci:get("banner", "banner", "last_update") or "0"
%>

<div class="cbi-map">
	<div class="cbi-section">
		<% if enabled == "1" then %>
		<div style="text-align: center; margin: 20px 0; padding: 30px; border: 3px solid #4CAF50; border-radius: 15px; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); box-shadow: 0 4px 15px rgba(0,0,0,0.1);">
			<h1 style="color: <%=banner_color%>; margin: 0 0 20px 0; font-size: 2.2em; text-shadow: 2px 2px 4px rgba(0,0,0,0.1); line-height: 1.3;">
				<%=pcdata(banner_text:gsub("\\n", "<br>"))%>
			</h1>
			
			<div style="margin: 25px 0; padding: 20px; border: 2px solid #ddd; border-radius: 10px; background: rgba(255,255,255,0.9);">
				<h3 style="color: #2c3e50; margin: 0 0 15px 0;">📞 <%:联系信息%></h3>
				<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
					<div style="padding: 10px;">
						<strong>📱 Telegram</strong><br>
						<a href="https://t.me/fgnb111999" target="_blank" style="color: #0088cc; text-decoration: none; font-weight: bold; font-size: 1.1em;">
							https://t.me/fgnb111999
						</a>
					</div>
					<div style="padding: 10px;">
						<strong>💬 QQ</strong><br>
						<span style="color: #666; font-weight: bold; font-size: 1.1em;">183452852</span>
					</div>
				</div>
			</div>
			
			<div style="margin-top: 20px; font-size: 0.9em; color: #666; opacity: 0.8;">
				<div>⚡ 基于GitHub + jsDelivr自动更新技术</div>
				<% if last_update ~= "0" then %>
				<div>🔄 最后更新: <%=os.date("%Y-%m-%d %H:%M:%S", tonumber(last_update))%></div>
				<% else %>
				<div>🚀 内容自动同步中...</div>
				<% end %>
			</div>
		</div>
		<% else %>
		<div style="text-align: center; margin: 20px 0; padding: 30px; border: 2px solid #ddd; border-radius: 8px; background: #f8f8f8;">
			<h2 style="color: #999; margin: 0;">❌ 横幅功能已禁用</h2>
			<p style="color: #666; margin: 10px 0;">请联系系统管理员启用横幅显示功能</p>
		</div>
		<% end %>
	</div>
</div>

<%+footer%>
EOF

log_success "增强的显示页面已生成"

# -------------------- 验证文件结构 --------------------
log_info "优化版插件文件结构:"
find "$CUSTOM_PKG_DIR" -type f | sort

log_success "🎉 基于成功脚本的优化版Banner插件生成完成！"
log_info ""
log_info "🚀 新增核心特性："
log_info "✅ 编译后自动生效 - 无需手动干预"
log_info "✅ 首次启动更新 - 5分钟后自动获取最新内容"
log_info "✅ 定期自动同步 - 每10分钟检查更新"
log_info "✅ 中文完整界面 - 所有文字本地化"
log_info "✅ 密码保护机制 - 客户无法修改设置"
log_info "✅ GitHub集成优化 - 智能重试和容错"
log_info "✅ 状态实时监控 - 可视化更新状态"
log_info ""
log_info "🎯 自动化流程："
log_info "1. 固件编译完成后，包含所有必要组件"
log_info "2. 路由器首次启动后5分钟自动联网更新"
log_info "3. 之后每10分钟检查一次GitHub内容更新"
log_info "4. 客户只能查看，无法修改任何设置"
log_info ""
log_info "📋 GitHub配置步骤："
log_info "1. 在GitHub创建仓库: openwrt-banner"
log_info "2. 上传banner.json文件:"
log_info '   {"text":"🎉 最新广告内容","color":"#FF0000"}'
log_info "4. 编译固件，客户使用时会自动获取最新内容"
log_info ""
log_info "🔧 管理方式："
log_info "• 作者: 修改GitHub仓库中的banner.json文件"
log_info "• 客户: 只能查看，无法修改（密码保护）"
log_info "• 更新: 完全自动化，无需任何手动操作"

