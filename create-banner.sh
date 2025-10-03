#!/bin/bash
# OpenWrt 横幅福利导航插件 - 云编译打包完整脚本
# 版本: v2.1 完整版
# 生成完整插件目录，可直接放入 OpenWrt package/custom/ 编译

set -e

echo "=========================================="
echo "OpenWrt 横幅插件云编译打包"
echo "版本: v2.1 完整版"
echo "=========================================="

# 包目录
if [ -n "$GITHUB_WORKSPACE" ]; then
    PKG_DIR="$GITHUB_WORKSPACE/openwrt/package/custom/luci-app-banner"
else
    PKG_DIR="$(pwd)/luci-app-banner"
fi

echo "包目录: $PKG_DIR"

# 清理并创建目录结构
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"/{root,etc/config,etc/cron.d,etc/init.d,root/usr/bin,luasrc/controller,luasrc/view/banner,www/luci-static/banner}

# -------------------- Makefile --------------------
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

	$(CP) ./luasrc/controller/* $(1)/usr/lib/lua/luci/controller/
	$(CP) ./luasrc/view/banner/* $(1)/usr/lib/lua/luci/view/banner/
	$(CP) ./root/usr/bin/* $(1)/usr/bin/
	$(CP) ./root/etc/config/* $(1)/etc/config/
	$(CP) ./root/etc/cron.d/* $(1)/etc/cron.d/
	$(CP) ./root/etc/init.d/* $(1)/etc/init.d/
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

# -------------------- root/etc/config/banner --------------------
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

# -------------------- root/etc/cron.d/banner --------------------
cat > "$PKG_DIR/root/etc/cron.d/banner" <<'EOF'
0 * * * * root /usr/bin/banner_auto_update.sh
EOF

# -------------------- root/etc/init.d/banner --------------------
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

# -------------------- root/usr/bin/banner_manual_update.sh --------------------
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
    log "GitHub 第 $i/3 次尝试..."
    curl -sL --max-time 15 "$PRI" -o "$CACHE/banner_new.json" 2>/dev/null
    if [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json"; then
        log "[√] GitHub 下载成功"
        cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
        break
    fi
    log "[×] GitHub 第 $i 次失败"
    sleep 2
done

if [ ! -s "$CACHE/nav_data.json" ]; then
    for i in 1 2 3; do
        log "Gitee 第 $i/3 次尝试..."
        curl -sL --max-time 15 "$BAK" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json"; then
            log "[√] Gitee 下载成功"
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            break
        fi
        log "[×] Gitee 第 $i 次失败"
        sleep 2
    done
fi

if [ -s "$CACHE/nav_data.json" ]; then
    TEXT=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.text' 2>/dev/null)
    COLOR=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.color' 2>/dev/null)
    TEXTS=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
    if [ -n "$TEXT" ]; then
        uci set banner.banner.text="$TEXT"
        uci set banner.banner.color="${COLOR:-rainbow}"
        [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
        uci set banner.banner.last_update=$(date +%s)
        uci commit banner
        log "[√] 手动更新成功"
    fi
else
    log "[×] 所有源失败"
fi
EOF

# -------------------- root/usr/bin/banner_auto_update.sh --------------------
cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'EOF'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
LOCK="/tmp/banner_auto_update.lock"
mkdir -p "$CACHE"

[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap "rm -f $LOCK" EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }

LAST=$(uci -q get banner.banner.last_update || echo 0)
NOW=$(date +%s)
INTERVAL=$(uci -q get banner.banner.update_interval || echo 86400)

[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0

log "========== 自动更新开始 =========="
PRI="https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"
BAK="https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json"

for i in 1 2 3; do
    log "GitHub 第 $i/3 次尝试..."
    curl -sL --max-time 15 "$PRI" -o "$CACHE/banner_new.json" 2>/dev/null
    if [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json"; then
        log "[√] GitHub 下载成功"
        cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
        break
    fi
    log "[×] GitHub 第 $i 次失败"
    sleep 3
done

if [ ! -s "$CACHE/nav_data.json" ]; then
    for i in 1 2 3; do
        log "Gitee 第 $i/3 次尝试..."
        curl -sL --max-time 15 "$BAK" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ] && grep -q '"text"' "$CACHE/banner_new.json"; then
            log "[√] Gitee 下载成功"
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            break
        fi
        log "[×] Gitee 第 $i 次失败"
        sleep 3
    done
fi

if [ -s "$CACHE/nav_data.json" ]; then
    TEXT=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.text' 2>/dev/null)
    COLOR=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.color' 2>/dev/null)
    TEXTS=$(jsonfilter -i "$CACHE/nav_data.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
    if [ -n "$TEXT" ]; then
        uci set banner.banner.text="$TEXT"
        uci set banner.banner.color="${COLOR:-rainbow}"
        [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
        uci set banner.banner.last_update=$(date +%s)
        uci commit banner
        log "[√] 自动更新成功"
    fi
else
    log "[×] 所有源失败"
fi
EOF

# -------------------- root/usr/bin/banner_bg_loader.sh --------------------
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'EOF'
#!/bin/sh
BG_GROUP=${1:-1}
LOG="/tmp/banner_bg.log"
CACHE="/tmp/banner_cache"
WEB="/www/luci-static/banner"
mkdir -p "$CACHE" "$WEB"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }

log "加载第 ${BG_GROUP} 组背景图..."
START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))
JSON="$CACHE/nav_data.json"

[ ! -f "$JSON" ] && log "[×] 数据文件未找到" && exit 1

IMG_URLS=$(jsonfilter -i "$JSON" -e "@.backgrounds[${START_IDX}].url")
COUNT=0
for url in $IMG_URLS; do
    [ -z "$url" ] && continue
    NAME=$(basename "$url")
    curl -sL --max-time 15 "$url" -o "$WEB/$NAME" && log "[√] 下载 $NAME"
    COUNT=$((COUNT+1))
done

log "背景图加载完成，共下载 $COUNT 张图片"
EOF

chmod +x "$PKG_DIR/root/usr/bin/"*

# -------------------- luasrc/controller/banner.lua --------------------
cat > "$PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)
function index()
    entry({"admin", "status", "banner"}, alias("admin", "status", "banner", "display"), _("福利导航"), 98).dependent = false
    entry({"admin", "status", "banner", "display"}, template("banner/display"), _("首页展示"), 1)
    entry({"admin", "status", "banner", "settings"}, template("banner/settings"), _("远程更新"), 2)
    entry({"admin", "status", "banner", "background"}, template("banner/background"), _("背景设置"), 3)
end
EOF

# -------------------- view/banner --------------------
cat > "$PKG_DIR/luasrc/view/banner/display.htm" <<'EOF'
<%+header%>
<%+banner/global_style%>
<div class="banner-hero">
    <h2><%=banner_texts or text%></h2>
</div>
EOF

cat > "$PKG_DIR/luasrc/view/banner/settings.htm" <<'EOF'
<%+header%>
<h3>远程更新设置</h3>
<form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/settings')%>">
    <label>更新 URL</label>
    <input type="text" name="update_url" value="<%=uci:get('banner','banner','update_url')%>"/>
    <button type="submit">保存</button>
</form>
EOF

cat > "$PKG_DIR/luasrc/view/banner/background.htm" <<'EOF'
<%+header%>
<h3>背景设置</h3>
<p>选择背景组加载显示</p>
EOF

cat > "$PKG_DIR/luasrc/view/banner/global_style.htm" <<'EOF'
<style>
.banner-hero { background: rgba(0,0,0,0.3); padding:20px; border-radius:12px; color:white; text-align:center; }
</style>
EOF

echo ""
echo "=========================================="
echo "完整插件生成完成！"
echo "目录: $PKG_DIR"
echo "可直接放入 OpenWrt package/custom/ 编译"
echo "=========================================="
