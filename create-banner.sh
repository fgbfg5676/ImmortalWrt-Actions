#!/bin/bash
# OpenWrt 横幅福利导航插件 - 云编译打包完整版
# 版本: v2.1 完整整合
# 用途: 一键生成 LuCI 横幅插件包

set -e

echo "=========================================="
echo "OpenWrt 横幅插件云编译打包"
echo "版本: v2.1 完整版"
echo "=========================================="

# 确定包目录位置
if [ -n "$GITHUB_WORKSPACE" ]; then
    PKG_DIR="$GITHUB_WORKSPACE/openwrt/package/custom/luci-app-banner"
elif [ -d "openwrt/package" ]; then
    PKG_DIR="$(pwd)/openwrt/package/custom/luci-app-banner"
else
    PKG_DIR="./luci-app-banner"
fi

echo "包目录: $PKG_DIR"

# 清理并创建目录结构
echo "[1/8] 创建包目录结构..."
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/root"/{usr/{lib/lua/luci/{controller,view/banner},bin},www/luci-static/banner,etc/{config,cron.d,init.d}}

# -----------------------------
# 2. Makefile
# -----------------------------
echo "[2/8] 创建 Makefile..."
cat > "$PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.1
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your@email.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for Banner Navigation
  DEPENDS:=+curl +jsonfilter +luci-base
  PKGARCH:=all
endef

define Package/luci-app-banner/description
  LuCI web interface for OpenWrt banner navigation with background images
endef

define Build/Compile
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/www/luci-static/banner
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/cron.d
	$(INSTALL_DIR) $(1)/etc/init.d
	
	$(CP) ./root/* $(1)/
	chmod +x $(1)/usr/bin/*
	chmod +x $(1)/etc/init.d/*
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/banner enable
	/usr/bin/banner_manual_update.sh &
	sleep 2
	/usr/bin/banner_bg_loader.sh 1 &
	/etc/init.d/nginx restart 2>/dev/null || /etc/init.d/uhttpd restart 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
EOF

# -----------------------------
# 3. UCI 配置
# -----------------------------
echo "[3/8] 创建配置文件..."
cat > "$PKG_DIR/root/etc/config/banner" <<'EOF'
config banner 'banner'
	option text '🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行'
	option color 'rainbow'
	option opacity '50'
	option bg_group '1'
	option bg_enabled '1'
	option current_bg '0'
	option update_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option backup_url 'https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json'
	option update_interval '86400'
	option last_update '0'
	option banner_texts ''
EOF

# -----------------------------
# 4. 脚本: 手动更新 / 自动更新 / 背景加载
# -----------------------------
echo "[4/8] 创建更新与背景脚本..."
# banner_manual_update.sh
cat > "$PKG_DIR/root/usr/bin/banner_manual_update.sh" <<'EOF'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
mkdir -p "$CACHE"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
log "========== 手动更新开始 =========="
PRI=$(uci -q get banner.banner.update_url)
BAK=$(uci -q get banner.banner.backup_url)
for i in 1 2 3; do
  curl -sL --max-time 15 "$PRI" -o "$CACHE/banner_new.json" 2>/dev/null
  [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json" && cp "$CACHE/banner_new.json" "$CACHE/nav_data.json" && log "[√] GitHub 下载成功" && break
  log "[×] GitHub 第 $i 次失败"; sleep 2
done
if [ ! -s "$CACHE/nav_data.json" ]; then
  for i in 1 2 3; do
    curl -sL --max-time 15 "$BAK" -o "$CACHE/banner_new.json" 2>/dev/null
    [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json" && cp "$CACHE/banner_new.json" "$CACHE/nav_data.json" && log "[√] Gitee 下载成功" && break
    log "[×] Gitee 第 $i 次失败"; sleep 2
  done
fi
[ -s "$CACHE/nav_data.json" ] && {
  TEXT=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.text')
  COLOR=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.color')
  TEXTS=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.banner_texts[*]' | tr '\n' '|')
  [ -n "$TEXT" ] && uci set banner.banner.text="$TEXT" && uci set banner.banner.color="${COLOR:-rainbow}" && [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS" && uci set banner.banner.last_update=$(date +%s) && uci commit banner && log "[√] 手动更新成功"
} || log "[×] 所有源失败"
EOF

# banner_auto_update.sh
cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'EOF'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
LOCK="/tmp/banner_auto_update.lock"
mkdir -p "$CACHE"
[ -f "$LOCK" ] && exit 0
touch "$LOCK"; trap "rm -f $LOCK" EXIT
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
LAST=$(uci -q get banner.banner.last_update || echo 0)
NOW=$(date +%s)
INTERVAL=$(uci -q get banner.banner.update_interval || echo 86400)
[ $((NOW-LAST)) -lt $INTERVAL ] && exit 0
log "========== 自动更新开始 =========="
PRI="https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"
BAK="https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json"
for i in 1 2 3; do
  curl -sL --max-time 15 "$PRI" -o "$CACHE/banner_new.json" 2>/dev/null
  [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json" && cp "$CACHE/banner_new.json" "$CACHE/nav_data.json" && log "[√] GitHub 下载成功" && break
  log "[×] GitHub 第 $i 次失败"; sleep 3
done
if [ ! -s "$CACHE/nav_data.json" ]; then
  for i in 1 2 3; do
    curl -sL --max-time 15 "$BAK" -o "$CACHE/banner_new.json" 2>/dev/null
    [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json" && cp "$CACHE/banner_new.json" "$CACHE/nav_data.json" && log "[√] Gitee 下载成功" && break
    log "[×] Gitee 第 $i 次失败"; sleep 3
  done
fi
[ -s "$CACHE/nav_data.json" ] && {
  TEXT=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.text')
  COLOR=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.color')
  TEXTS=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.banner_texts[*]' | tr '\n' '|')
  [ -n "$TEXT" ] && uci set banner.banner.text="$TEXT" && uci set banner.banner.color="${COLOR:-rainbow}" && [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS" && uci set banner.banner.last_update=$(date +%s) && uci commit banner && log "[√] 自动更新成功"
} || log "[×] 所有源失败"
EOF

# banner_bg_loader.sh
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'EOF'
#!/bin/sh
BG_GROUP=${1:-1}
LOG="/tmp/banner_bg.log"
CACHE="/tmp/banner_cache"
WEB="/www/luci-static/banner"
mkdir -p "$CACHE" "$WEB"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
log "加载第 ${BG_GROUP} 组背景图..."
START_IDX=$(( (BG_GROUP-1)*3 +1 ))
JSON="$CACHE/nav_data.json"
[ ! -f "$JSON" ] && log "[×] 数据文件未找到" && exit 1
rm -f "$WEB"/bg*.jpg
for i in 0 1 2; do
  KEY="background_$((START_IDX+i))"
  URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
  [ -n "$URL" ] && curl -sL --max-time 15 "$URL" -o "$WEB/bg$i.jpg" 2>/dev/null && [ -s "$WEB/bg$i.jpg" ] && chmod 644 "$WEB/bg$i.jpg" && log "[√] bg$i.jpg" || log "[×] bg$i.jpg 失败"
done
cp "$WEB/bg0.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
log "[完成] 第 ${BG_GROUP} 组"
EOF

# -----------------------------
# 5. 定时任务 & init
# -----------------------------
cat > "$PKG_DIR/root/etc/cron.d/banner" <<'EOF'
0 * * * * root /usr/bin/banner_auto_update.sh
EOF

cat > "$PKG_DIR/root/etc/init.d/banner" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  /usr/bin/banner_auto_update.sh >/dev/null 2>&1 &
  sleep 2
  BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
  /usr/bin/banner_bg_loader.sh "$BG_GROUP" >/dev/null 2>&1 &
}
EOF

# -----------------------------
# 6. LuCI 控制器
# -----------------------------
echo "[6/8] 创建 LuCI 控制器..."
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)
function index()
    entry({"admin","status","banner"},alias("admin","status","banner","display"),_("福利导航"),98).dependent=false
    entry({"admin","status","banner","display"}, call("action_display"),_("首页展示"),1)
    entry({"admin","status","banner","settings"}, call("action_settings"),_("远程更新"),2)
    entry({"admin","status","banner","background"}, call("action_background"),_("背景设置"),3)
    entry({"admin","status","banner","do_update"}, post("action_do_update")).leaf=true
    entry({"admin","status","banner","do_set_bg"}, post("action_do_set_bg")).leaf=true
    entry({"admin","status","banner","do_clear_cache"}, post("action_do_clear_cache")).leaf=true
    entry({"admin","status","banner","do_load_group"}, post("action_do_load_group")).leaf=true
    entry({"admin","status","banner","do_set_opacity"}, post("action_do_set_opacity")).leaf=true
    entry({"admin","status","banner","do_upload_bg"}, post("action_do_upload_bg")).leaf=true
    entry({"admin","status","banner","do_apply_url"}, post("action_do_apply_url")).leaf=true
end
EOF

# -----------------------------
# 7. 视图文件
# -----------------------------
VIEW_DIR="$PKG_DIR/root/usr/lib/lua/luci/view/banner"
mkdir -p "$VIEW_DIR"

echo "[7/8] 创建视图文件..."
# global_style.htm
cat > "$VIEW_DIR/global_style.htm" <<'EOF'
<%
local uci=require"luci.model.uci".cursor()
local opacity=tonumber(uci:get("banner","banner","opacity") or "50")
local alpha=(100-opacity)/100
local bg_num=tonumber(uci:get("banner","banner","current_bg") or "0")
%>
<style>
html,body{background:linear-gradient(rgba(0,0,0,<%=alpha%>),rgba(0,0,0,<%=alpha%>)), url(/luci-static/banner/bg<%=bg_num%>.jpg?t=<%=os.time()%>) center/cover fixed !important;}
.banner-hero{background:rgba(0,0,0,0.3);backdrop-filter:blur(8px);border-radius:15px;padding:25px;margin:20px auto;max-width:1200px;color:white;text-align:center;}
.banner-scroll{text-align:center;font-weight:bold;font-size:20px;margin-bottom:50px;display:flex;justify-content:center;gap:10px;flex-wrap:wrap;}
.banner-contacts{display:flex;gap:25px;flex-wrap:wrap;justify-content:center;}
.contact-card{background:rgba(0,0,0,0.3);padding:15px;border-radius:10px;color:white;min-width:150px;text-align:center;}
</style>
EOF

# display.htm
cat > "$VIEW_DIR/display.htm" <<'EOF'
<%+header%>
<%+banner/global_style%>
<div class="banner-hero">
<h1><%=uci:get("banner","banner","text") or "🎉 欢迎使用福利导航 🎉"%></h1>
</div>
<div class="banner-scroll">
<% local texts=(uci:get("banner","banner","banner_texts") or ""):split("|") %>
<% for _, t in ipairs(texts) do %>
<div><%=t%></div>
<% end %>
</div>
EOF

# settings.htm
cat > "$VIEW_DIR/settings.htm" <<'EOF'
<%+header%>
<%+banner/global_style%>
<h2>远程更新设置</h2>
<form class="form" method="post" action="<%=luci.dispatcher.build_url("admin/status/banner/do_apply_url")%>">
<label>主更新地址</label>
<input type="text" name="update_url" value="<%=uci:get("banner","banner","update_url")%>" />
<label>备用更新地址</label>
<input type="text" name="backup_url" value="<%=uci:get("banner","banner","backup_url")%>" />
<label>更新间隔（秒）</label>
<input type="number" name="update_interval" value="<%=uci:get("banner","banner","update_interval")%>" />
<button type="submit">保存并应用</button>
</form>
<h3>手动更新</h3>
<form method="post" action="<%=luci.dispatcher.build_url("admin/status/banner/do_update")%>">
<button type="submit">立即更新</button>
</form>
EOF

# background.htm
cat > "$VIEW_DIR/background.htm" <<'EOF'
<%+header%>
<%+banner/global_style%>
<h2>横幅背景设置</h2>
<p>可选择背景组或上传自定义图片。</p>
<h3>选择背景组</h3>
<form method="post" action="<%=luci.dispatcher.build_url("admin/status/banner/do_load_group")%>">
<select name="bg_group">
<% for i=1,5 do %>
<option value="<%=i%>" <% if tonumber(uci:get("banner","banner","bg_group") or "1")==i then %>selected<% end %>>
背景组 <%=i%>
</option>
<% end %>
</select>
<button type="submit">应用背景组</button>
</form>
<h3>上传自定义背景</h3>
<form method="post" action="<%=luci.dispatcher.build_url("admin/status/banner/do_upload_bg")%>" enctype="multipart/form-data">
<input type="file" name="bg_file" accept="image/jpeg,image/png" />
<button type="submit">上传并应用</button>
</form>
<h3>调整透明度</h3>
<form method="post" action="<%=luci.dispatcher.build_url("admin/status/banner/do_set_opacity")%>">
<input type="range" name="opacity" min="0" max="100" value="<%=uci:get("banner","banner","opacity") or 50%>" />
<button type="submit">保存透明度</button>
</form>
EOF

echo "[8/8] 完成！luci-app-banner 插件已生成: $PKG_DIR"
