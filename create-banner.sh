#!/bin/bash
# OpenWrt 横幅福利导航插件 - 云编译完整脚本
# 版本: v2.2 最终版
# 适配: GitHub Actions / 云编译环境

set -e

echo "=========================================="
echo "OpenWrt 横幅插件云编译打包"
echo "版本: v2.2 | 最终优化版"
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

# 清理并一次性创建完整目录结构
echo "[1/3] 创建完整目录结构..."
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"/root/{etc/{config,init.d,cron.d},usr/{bin,lib/lua/luci/{controller,view/banner}},www/luci-static/banner,overlay/banner}

# 创建 Makefile
echo "[2/3] 创建 Makefile..."
cat > "$PKG_DIR/Makefile" <<'MAKEFILE'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.2
PKG_RELEASE:=1

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=OpenWrt Community

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-banner
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for Banner Navigation
  DEPENDS:=+curl +jsonfilter +luci-base +jq
  PKGARCH:=all
endef

define Package/luci-app-banner/description
  LuCI web interface for OpenWrt banner navigation with dynamic backgrounds
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
	$(INSTALL_DIR) $(1)/overlay/banner
	
	$(CP) ./root/* $(1)/
	chmod +x $(1)/usr/bin/*
	chmod +x $(1)/etc/init.d/*
endef

define Package/luci-app-banner/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	mkdir -p /tmp/banner_cache
	mkdir -p /overlay/banner
	[ -f /www/luci-static/banner/default_bg.jpg ] || {
		[ -f /rom/www/luci-static/banner/default_bg.jpg ] && cp /rom/www/luci-static/banner/default_bg.jpg /www/luci-static/banner/default_bg.jpg
	}
	/etc/init.d/banner enable
	/usr/bin/banner_manual_update.sh >/dev/null 2>&1 &
	sleep 2
	/usr/bin/banner_bg_loader.sh 1 >/dev/null 2>&1 &
	/etc/init.d/nginx restart 2>/dev/null || /etc/init.d/uhttpd restart 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
MAKEFILE

# 创建所有文件
echo "[3/3] 创建所有软件包文件..."

# UCI 配置
cat > "$PKG_DIR/root/etc/config/banner" <<'UCICONF'
config banner 'banner'
	option text '🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行'
	option color 'rainbow'
	option opacity '50'
	option carousel_interval '5000'
	option bg_group '1'
	option bg_enabled '1'
	option persistent_storage '0'
	option current_bg '0'
	list update_urls 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	list update_urls 'https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json'
	option selected_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option update_interval '86400'
	option last_update '0'
	option banner_texts ''
	option remote_message ''
UCICONF

# 缓存清理脚本
cat > "$PKG_DIR/root/usr/bin/banner_cache_cleaner.sh" <<'CLEANER'
#!/bin/sh
LOG="/tmp/banner_update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    [ -s "$LOG" ] && [ $(stat -f %z "$LOG" 2>/dev/null || stat -c %s "$LOG") -gt 51200 ] && {
        mv "$LOG" "$LOG.bak"
        tail -n 10 "$LOG.bak" > "$LOG"
        rm -f "$LOG.bak"
    }
}

log "========== Cache Cleanup Started =========="
find /tmp/banner_cache -type f -mtime +3 -delete
log "[√] Removed files older than 3 days in /tmp/banner_cache"
CLEANER

# 手动更新脚本
cat > "$PKG_DIR/root/usr/bin/banner_manual_update.sh" <<'MANUALUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
mkdir -p "$CACHE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    [ -s "$LOG" ] && [ $(stat -f %z "$LOG" 2>/dev/null || stat -c %s "$LOG") -gt 51200 ] && {
        mv "$LOG" "$LOG.bak"
        tail -n 10 "$LOG.bak" > "$LOG"
        rm -f "$LOG.bak"
    }
}

log "========== Manual Update Started =========="

validate_url() {
    local url=$1
    case "$url" in
        http://*|https://*) return 0 ;;
        *) log "[×] Invalid URL: $url"; return 1 ;;
    esac
}

URLS=$(uci -q get banner.banner.update_urls | tr ' ' '\n')
SELECTED_URL=$(uci -q get banner.banner.selected_url)
SUCCESS=0

# Prioritize selected URL
if [ -n "$SELECTED_URL" ] && validate_url "$SELECTED_URL"; then
    for i in 1 2 3; do
        log "Selected URL Attempt $i/3 ($SELECTED_URL)..."
        curl -sL --max-time 15 "$SELECTED_URL" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
            log "[√] Selected URL Download Successful (Valid JSON)"
            SUCCESS=1
            break
        fi
        log "[×] Selected URL Attempt $i Failed or Invalid JSON"
        rm -f "$CACHE/banner_new.json"
        sleep 2
    done
fi

# Try other URLs
if [ $SUCCESS -eq 0 ]; then
    for url in $URLS; do
        if [ "$url" != "$SELECTED_URL" ] && validate_url "$url"; then
            for i in 1 2 3; do
                log "Attempt $i/3 for URL ($url)..."
                curl -sL --max-time 15 "$url" -o "$CACHE/banner_new.json" 2>/dev/null
                if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
                    log "[√] URL Download Successful (Valid JSON)"
                    uci set banner.banner.selected_url="$url"
                    uci commit banner
                    SUCCESS=1
                    break 2
                fi
                log "[×] URL Attempt $i Failed or Invalid JSON"
                rm -f "$CACHE/banner_new.json"
                sleep 2
            done
        fi
    done
fi

if [ $SUCCESS -eq 1 ] && [ -s "$CACHE/banner_new.json" ]; then
    ENABLED=$(jq -r '.enabled // "true"' "$CACHE/banner_new.json")
    if [ "$ENABLED" = "false" ] || [ "$ENABLED" = "0" ]; then
        MSG=$(jq -r '.disable_message // "服务已被管理员关闭"' "$CACHE/banner_new.json")
        uci set banner.banner.bg_enabled='0'
        uci set banner.banner.remote_message="$MSG"
        uci commit banner
        log "[!REMOTE DISABLED] $MSG"
        rm -f "$CACHE/banner_new.json"
    else
        TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
        COLOR=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null)
        TEXTS=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
        if [ -n "$TEXT" ]; then
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            uci set banner.banner.text="$TEXT"
            uci set banner.banner.color="${COLOR:-rainbow}"
            [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
            uci set banner.banner.bg_enabled='1'
            uci delete banner.banner.remote_message >/dev/null 2>&1
            uci set banner.banner.last_update=$(date +%s)
            uci commit banner
            log "[√] Manual Update Successful"
        else
            log "[×] Invalid JSON content (missing text field)"
            rm -f "$CACHE/banner_new.json"
        fi
    fi
else
    log "[×] All Sources Failed or Invalid JSON, keeping old nav_data.json"
fi
MANUALUPDATE

# 自动更新脚本
cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'AUTOUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
LOCK="/tmp/banner_auto_update.lock"
mkdir -p "$CACHE"

[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap "rm -f $LOCK" EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    [ -s "$LOG" ] && [ $(stat -f %z "$LOG" 2>/dev/null || stat -c %s "$LOG") -gt 51200 ] && {
        mv "$LOG" "$LOG.bak"
        tail -n 10 "$LOG.bak" > "$LOG"
        rm -f "$LOG.bak"
    }
}

LAST=$(uci -q get banner.banner.last_update || echo 0)
NOW=$(date +%s)
INTERVAL=86400

[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0

log "========== Auto Update Started =========="

validate_url() {
    local url=$1
    case "$url" in
        http://*|https://*) return 0 ;;
        *) log "[×] Invalid URL: $url"; return 1 ;;
    esac
}

URLS=$(uci -q get banner.banner.update_urls | tr ' ' '\n')
SELECTED_URL=$(uci -q get banner.banner.selected_url)
SUCCESS=0

# Prioritize selected URL
if [ -n "$SELECTED_URL" ] && validate_url "$SELECTED_URL"; then
    for i in 1 2 3; do
        log "Selected URL Attempt $i/3 ($SELECTED_URL)..."
        curl -sL --max-time 15 "$SELECTED_URL" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
            log "[√] Selected URL Download Successful (Valid JSON)"
            SUCCESS=1
            break
        fi
        log "[×] Selected URL Attempt $i Failed or Invalid JSON"
        rm -f "$CACHE/banner_new.json"
        sleep 3
    done
fi

# Try other URLs
if [ $SUCCESS -eq 0 ]; then
    for url in $URLS; do
        if [ "$url" != "$SELECTED_URL" ] && validate_url "$url"; then
            for i in 1 2 3; do
                log "Attempt $i/3 for URL ($url)..."
                curl -sL --max-time 15 "$url" -o "$CACHE/banner_new.json" 2>/dev/null
                if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
                    log "[√] URL Download Successful (Valid JSON)"
                    uci set banner.banner.selected_url="$url"
                    uci commit banner
                    SUCCESS=1
                    break 2
                fi
                log "[×] URL Attempt $i Failed or Invalid JSON"
                rm -f "$CACHE/banner_new.json"
                sleep 3
            done
        fi
    done
fi

if [ $SUCCESS -eq 1 ] && [ -s "$CACHE/banner_new.json" ]; then
    ENABLED=$(jq -r '.enabled // "true"' "$CACHE/banner_new.json")
    if [ "$ENABLED" = "false" ] || [ "$ENABLED" = "0" ]; then
        MSG=$(jq -r '.disable_message // "服务已被管理员关闭"' "$CACHE/banner_new.json")
        uci set banner.banner.bg_enabled='0'
        uci set banner.banner.remote_message="$MSG"
        uci commit banner
        log "[!REMOTE DISABLED] $MSG"
        rm -f "$CACHE/banner_new.json"
    else
        TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
        COLOR=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null)
        TEXTS=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
        if [ -n "$TEXT" ]; then
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            uci set banner.banner.text="$TEXT"
            uci set banner.banner.color="${COLOR:-rainbow}"
            [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
            uci set banner.banner.bg_enabled='1'
            uci delete banner.banner.remote_message >/dev/null 2>&1
            uci set banner.banner.last_update=$(date +%s)
            uci commit banner
            log "[√] Auto Update Successful"
        else
            log "[×] Invalid JSON content (missing text field)"
            rm -f "$CACHE/banner_new.json"
        fi
    fi
else
    log "[×] All Sources Failed or Invalid JSON, keeping old nav_data.json"
fi
AUTOUPDATE

# 背景图加载器
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}
LOG="/tmp/banner_bg.log"
CACHE="/tmp/banner_cache"
WEB="/www/luci-static/banner"
PERSISTENT="/overlay/banner"
UCI_PERSISTENT=$(uci -q get banner.banner.persistent_storage || echo 0)
DEST="$([ "$UCI_PERSISTENT" = "1" ] && echo "$PERSISTENT" || echo "$WEB")"

mkdir -p "$CACHE" "$WEB" "$PERSISTENT"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    [ -s "$LOG" ] && [ $(stat -f %z "$LOG" 2>/dev/null || stat -c %s "$LOG") -gt 51200 ] && {
        mv "$LOG" "$LOG.bak"
        tail -n 10 "$LOG.bak" > "$LOG"
        rm -f "$LOG.bak"
    }
}

validate_url() {
    local url=$1
    case "$url" in
        http://*|https://*) return 0 ;;
        *) log "[×] Invalid URL: $url"; return 1 ;;
    esac
}

log "加载第 ${BG_GROUP} 组背景图..."

START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))
JSON="$CACHE/nav_data.json"

[ ! -f "$JSON" ] && log "[×] 数据文件未找到" && exit 1

# Clean old backgrounds, keep only 3
rm -f "$DEST"/bg{0,1,2}.jpg
[ "$UCI_PERSISTENT" = "1" ] && rm -f "$WEB"/bg{0,1,2}.jpg

for i in 0 1 2; do
    KEY="background_$((START_IDX + i))"
    URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
    if [ -n "$URL" ] && validate_url "$URL"; then
        log "  下载 $KEY..."
        curl -sL --max-time 15 "$URL" -o "$DEST/bg$i.jpg" 2>/dev/null
        if [ -s "$DEST/bg$i.jpg" ]; then
            chmod 644 "$DEST/bg$i.jpg"
            [ "$UCI_PERSISTENT" = "1" ] && cp "$DEST/bg$i.jpg" "$WEB/bg$i.jpg" 2>/dev/null
            log "  [√] bg$i.jpg"
            # Set first valid image as current_bg.jpg for initial display
            [ $i -eq 0 ] && cp "$DEST/bg$i.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
        else
            log "  [×] bg$i.jpg 失败"
        fi
    else
        log "  [×] $KEY 无效或URL格式错误"
    fi
done

# Ensure current_bg.jpg exists
if [ ! -s "$CACHE/current_bg.jpg" ]; then
    if [ -s "$DEST/bg0.jpg" ]; then
        cp "$DEST/bg0.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
    elif [ -s "$WEB/default_bg.jpg" ]; then
        cp "$WEB/default_bg.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
    fi
fi

log "[完成] 第 ${BG_GROUP} 组"
BGLOADER

# 定时任务
cat > "$PKG_DIR/root/etc/cron.d/banner" <<'CRON'
0 * * * * root /usr/bin/banner_auto_update.sh
0 0 * * * root /usr/bin/banner_cache_cleaner.sh
CRON

# 开机自启动
cat > "$PKG_DIR/root/etc/init.d/banner" <<'INIT'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start() {
    # Ensure default background
    if [ ! -s /tmp/banner_cache/current_bg.jpg ]; then
        if [ -s /www/luci-static/banner/bg0.jpg ]; then
            cp /www/luci-static/banner/bg0.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null
        elif [ -s /overlay/banner/bg0.jpg ]; then
            cp /overlay/banner/bg0.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null
        elif [ -s /www/luci-static/banner/default_bg.jpg ]; then
            cp /www/luci-static/banner/default_bg.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null
        fi
    fi
    /usr/bin/banner_auto_update.sh >/dev/null 2>&1 &
    sleep 2
    BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
    /usr/bin/banner_bg_loader.sh "$BG_GROUP" >/dev/null 2>&1 &
}

status() {
    local uci_enabled=$(uci -q get banner.banner.bg_enabled || echo 1)
    local last_update=$(uci -q get banner.banner.last_update || echo 0)
    local current_bg=$(uci -q get banner.banner.current_bg || echo 0)
    local bg_group=$(uci -q get banner.banner.bg_group || echo 1)
    local remote_msg=$(uci -q get banner.banner.remote_message || echo "无")

    echo "===== 横幅导航状态 ====="
    if [ "$uci_enabled" = "0" ]; then
        echo "状态: 已禁用"
        echo "禁用原因: $remote_msg"
    else
        echo "状态: 已启用"
    fi
    echo "当前背景: bg$current_bg.jpg (组 $bg_group)"
    if [ "$last_update" = "0" ]; then
        echo "上次更新: 从未更新"
    else
        echo "上次更新: $(date -d "@$last_update" '+%Y-%m-%d %H:%M:%S')"
    fi
    echo "缓存目录: /tmp/banner_cache"
    echo "背景存储: $(uci -q get banner.banner.persistent_storage | grep -q 1 && echo '/overlay/banner' || echo '/www/luci-static/banner')"
    echo "========================"
}
INIT

# LuCI 控制器
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<'CONTROLLER'
module("luci.controller.banner", package.seeall)

function index()
    entry({"admin", "status", "banner"}, alias("admin", "status", "banner", "display"), _("福利导航"), 98).dependent = false
    entry({"admin", "status", "banner", "display"}, call("action_display"), _("首页展示"), 1)
    entry({"admin", "status", "banner", "settings"}, call("action_settings"), _("远程更新"), 2)
    entry({"admin", "status", "banner", "background"}, call("action_background"), _("背景设置"), 3)
    entry({"admin", "status", "banner", "do_update"}, post("action_do_update")).leaf = true
    entry({"admin", "status", "banner", "do_set_bg"}, post("action_do_set_bg")).leaf = true
    entry({"admin", "status", "banner", "do_clear_cache"}, post("action_do_clear_cache")).leaf = true
    entry({"admin", "status", "banner", "do_load_group"}, post("action_do_load_group")).leaf = true
    entry({"admin", "status", "banner", "do_upload_bg"}, post("action_do_upload_bg")).leaf = true
    entry({"admin", "status", "banner", "do_apply_url"}, post("action_do_apply_url")).leaf = true
    entry({"admin", "status", "banner", "do_set_opacity"}, post("action_do_set_opacity")).leaf = true
    entry({"admin", "status", "banner", "do_set_carousel_interval"}, post("action_do_set_carousel_interval")).leaf = true
    entry({"admin", "status", "banner", "do_set_update_url"}, post("action_do_set_update_url")).leaf = true
    entry({"admin", "status", "banner", "do_set_persistent_storage"}, post("action_do_set_persistent_storage")).leaf = true
end

function action_display()
    local uci = require "luci.model.uci".cursor()
    local fs = require "nixio.fs"
    local jsonc = require "luci.jsonc"
    local nav_file = fs.readfile("/tmp/banner_cache/nav_data.json")
    local nav_data = nav_file and jsonc.parse(nav_file) or nil
    local banner_texts = uci:get("banner", "banner", "banner_texts") or ""
    luci.template.render("banner/display", {
        text = uci:get("banner", "banner", "text") or "欢迎访问福利导航",
        color = uci:get("banner", "banner", "color") or "rainbow",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        carousel_interval = uci:get("banner", "banner", "carousel_interval") or "5000",
        current_bg = uci:get("banner", "banner", "current_bg") or "0",
        bg_enabled = uci:get("banner", "banner", "bg_enabled") or "1",
        remote_message = uci:get("banner", "banner", "remote_message") or "",
        banner_texts = banner_texts,
        nav_data = nav_data
    })
end

function action_settings()
    local uci = require "luci.model.uci".cursor()
    local fs = require "nixio.fs"
    luci.template.render("banner/settings", {
        text = uci:get("banner", "banner", "text") or "",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        carousel_interval = uci:get("banner", "banner", "carousel_interval") or "5000",
        persistent_storage = uci:get("banner", "banner", "persistent_storage") or "0",
        last_update = uci:get("banner", "banner", "last_update") or "0",
        log = fs.readfile("/tmp/banner_update.log") or "暂无日志"
    })
end

function action_background()
    local uci = require "luci.model.uci".cursor()
    local fs = require "nixio.fs"
    luci.template.render("banner/background", {
        bg_group = uci:get("banner", "banner", "bg_group") or "1",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        current_bg = uci:get("banner", "banner", "current_bg") or "0",
        persistent_storage = uci:get("banner", "banner", "persistent_storage") or "0",
        log = fs.readfile("/tmp/banner_bg.log") or "暂无日志"
    })
end

function action_do_update()
    luci.sys.call("/usr/bin/banner_manual_update.sh >/dev/null 2>&1 &")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_bg()
    local uci = require "luci.model.uci".cursor()
    local bg = luci.http.formvalue("bg")
    if bg then
        uci:set("banner", "banner", "current_bg", bg)
        uci:commit("banner")
        local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
        local src="/www/luci-static/banner"
        [ "$persistent" = "1" ] && src="/overlay/banner"
        luci.sys.call(string.format("cp %s/bg%s.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null", src, bg))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_clear_cache()
    luci.sys.call("rm -rf /tmp/banner_cache/*.jpg /www/luci-static/banner/bg*.jpg /overlay/banner/bg*.jpg")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_load_group()
    local uci = require "luci.model.uci".cursor()
    local group = luci.http.formvalue("group")
    if group then
        uci:set("banner", "banner", "bg_group", group)
        uci:commit("banner")
        luci.sys.call(string.format("/usr/bin/banner_bg_loader.sh %s >/dev/null 2>&1 &", group))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_upload_bg()
    local fs = require "nixio.fs"
    local http = require "luci.http"
    local uci = require "luci.model.uci".cursor()
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest="/www/luci-static/banner"
    [ "$persistent" = "1" ] && dest="/overlay/banner"
    http.setfilehandler(function(meta, chunk, eof)
        if not meta then return end
        if meta.name == "bg_file" then
            local path = "$dest/upload_temp.jpg"
            if chunk then
                local fp = io.open(path, meta.file and "ab" or "wb")
                if fp then fp:write(chunk); fp:close() end
            end
            if eof and fs.stat(path) then
                luci.sys.call("cp " .. path .. " $dest/bg0.jpg")
                luci.sys.call("rm -f " .. path)
                [ "$persistent" = "1" ] && luci.sys.call("cp $dest/bg0.jpg /www/luci-static/banner/bg0.jpg")
                local log = fs.readfile("/tmp/banner_bg.log") or ""
                fs.writefile("/tmp/banner_bg.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] 本地上传成功")
            end
        end
    end)
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_apply_url()
    local url = luci.http.formvalue("custom_bg_url")
    local uci = require "luci.model.uci".cursor()
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest="/www/luci-static/banner"
    [ "$persistent" = "1" ] && dest="/overlay/banner"
    if url and url:match("^https?://") then
        luci.sys.call(string.format("curl -sL --max-time 15 '%s' -o %s/bg0.jpg 2>/dev/null", url, dest))
        [ "$persistent" = "1" ] && luci.sys.call(string.format("cp %s/bg0.jpg /www/luci-static/banner/bg0.jpg", dest))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_set_opacity()
    local uci = require "luci.model.uci".cursor()
    local opacity = luci.http.formvalue("opacity")
    if opacity and opacity:match("^[0-9]+$") and opacity >= 0 and opacity <= 100 then
        uci:set("banner", "banner", "opacity", opacity)
        uci:commit("banner")
    end
    luci.http.status(200, "OK")
end

function action_do_set_carousel_interval()
    local uci = require "luci.model.uci".cursor()
    local interval = luci.http.formvalue("carousel_interval")
    if interval and interval:match("^[0-9]+$") and interval >= 1000 and interval <= 30000 then
        uci:set("banner", "banner", "carousel_interval", interval)
        uci:commit("banner")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_update_url()
    local uci = require "luci.model.uci".cursor()
    local selected_url = luci.http.formvalue("selected_url")
    if selected_url and selected_url:match("^https?://") then
        uci:set("banner", "banner", "selected_url", selected_url)
        uci:commit("banner")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_persistent_storage()
    local uci = require "luci.model.uci".cursor()
    local persistent = luci.http.formvalue("persistent_storage")
    if persistent and persistent:match("^[0-1]$") then
        uci:set("banner", "banner", "persistent_storage", persistent)
        uci:commit("banner")
        if [ "$persistent" = "1" ]; then
            luci.sys.call("mkdir -p /overlay/banner")
            luci.sys.call("cp /www/luci-static/banner/bg*.jpg /overlay/banner/ 2>/dev/null")
        else
            luci.sys.call("cp /overlay/banner/bg*.jpg /www/luci-static/banner/ 2>/dev/null")
        fi
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end
CONTROLLER

# 全局样式（实时透明度调节）
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/global_style.htm" <<'GLOBALSTYLE'
<%
local uci = require "luci.model.uci".cursor()
local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
local alpha = (100 - opacity) / 100
local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
local bg_path = "/tmp/banner_cache"
%>
<style>
html, body, #maincontent, .container, .cbi-map, .cbi-section, 
.cbi-map > *, .cbi-section > *, #maincontent > .container > .cbi-map > *,
.cbi-map table, .cbi-section table, .cbi-value, .cbi-value-field,
.cbi-section-node, .cbi-map-descr, .cbi-section-descr {
    background: transparent !important;
}
body {
    background: linear-gradient(rgba(0,0,0,<%=alpha%>), rgba(0,0,0,<%=alpha%>)), 
                url(<%=bg_path%>/current_bg.jpg?t=<%=os.time()%>) center/cover fixed !important;
    min-height: 100vh;
}
.cbi-map, #maincontent > .container > .cbi-map {
    background: rgba(0,0,0,0.3) !important;
    border: 1px solid rgba(255,255,255,0.1) !important;
    border-radius: 12px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.2);
    padding: 15px;
}
.cbi-section, .cbi-map > .cbi-section, .cbi-section-node {
    background: rgba(0,0,0,0.2) !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
    border-radius: 8px;
    padding: 10px;
    margin: 10px 0;
}
.cbi-value-title, .cbi-section h2, .cbi-section h3, .cbi-map h2 {
    color: white !important;
    text-shadow: 0 2px 4px rgba(0,0,0,0.6);
}
input[type="text"], textarea, select {
    background: rgba(255,255,255,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: #333 !important;
}
input:disabled, select:disabled {
    background: rgba(200,200,200,0.5) !important;
}
.cbi-button, input[type="submit"], button {
    background: rgba(66,139,202,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: white !important;
}
</style>
<script>
(function() {
    var sliders = document.querySelectorAll('input[type="range"][data-realtime="opacity"]');
    sliders.forEach(function(s) {
        s.addEventListener('input', function() {
            var val = parseInt(this.value);
            var a = (100 - val) / 100;
            document.body.style.background = 
                'linear-gradient(rgba(0,0,0,' + a + '), rgba(0,0,0,' + a + ')), ' +
                'url(<%=bg_path%>/current_bg.jpg?t=<%=os.time()%>) center/cover fixed';
            var display = document.getElementById('opacity-display');
            if (display) display.textContent = val + '%';
            var xhr = new XMLHttpRequest();
            xhr.open('POST', '<%=luci.dispatcher.build_url("admin/status/banner/do_set_opacity")%>', true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.send('token=<%=token%>&opacity=' + val);
        });
    });
})();
</script>
GLOBALSTYLE

# 首页展示（带轮播图和导航）
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/display.htm" <<'DISPLAYVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.banner-hero {
    background: rgba(0,0,0,0.3);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 15px;
    padding: 25px;
    margin: 20px auto;
    max-width: 1200px;
}
.banner-scroll {
    padding: 25px;
    margin-bottom: 50px;
    text-align: center;
    font-weight: bold;
    font-size: 20px;
    border-radius: 10px;
    min-height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
    <% if color == 'rainbow' then %>
    background: linear-gradient(90deg, #ff0000, #ff7f00, #ffff00, #00ff00, #0000ff, #4b0082, #9400d3);
    background-size: 400% 400%;
    animation: rainbow 8s ease infinite;
    color: white;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
    <% else %>
    background: rgba(255,255,255,0.15);
    color: <%=color%>;
    <% end %>
}
@keyframes rainbow {
    0%, 100% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
}
.banner-contacts {
    display: flex;
    justify-content: space-around;
    gap: 25px;
    margin-bottom: 50px;
    flex-wrap: wrap;
}
.contact-card {
    flex: 1;
    min-width: 200px;
    background: rgba(0,0,0,0.3);
    backdrop-filter: blur(6px);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 10px;
    padding: 15px;
    text-align: center;
    color: white;
}
.copy-btn {
    background: rgba(76,175,80,0.9);
    color: white;
    border: none;
    padding: 8px 18px;
    border-radius: 5px;
    cursor: pointer;
    margin-top: 10px;
    font-weight: bold;
}
.copy-btn:hover {
    background: rgba(76,175,80,1);
}
.nav-groups {
    display: flex;
    gap: 30px;
    flex-wrap: wrap;
    justify-content: center;
}
.nav-group {
    min-width: 220px;
    background: rgba(0,0,0,0.3);
    backdrop-filter: blur(6px);
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 10px;
    padding: 15px;
    cursor: pointer;
    transition: all 0.3s;
}
.nav-group:hover {
    background: rgba(0,0,0,0.4);
    transform: translateY(-5px);
    border-color: #4fc3f7;
}
.nav-group-title {
    font-size: 18px;
    font-weight: bold;
    color: white;
    text-align: center;
    margin-bottom: 10px;
    padding: 10px;
    background: rgba(102,126,234,0.6);
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
}
.nav-group-title img {
    width: 24px;
    height: 24px;
    margin-right: 8px;
}
.nav-links {
    display: none;
    padding: 10px;
}
.nav-links.active {
    display: block;
}
.nav-links a {
    display: block;
    color: #4fc3f7;
    text-decoration: none;
    padding: 10px;
    margin: 5px 0;
    border-radius: 5px;
    background: rgba(255,255,255,0.1);
    transition: all 0.2s;
}
.nav-links a:hover {
    background: rgba(79,195,247,0.3);
    transform: translateX(5px);
}
.nav-desc {
    color: #aaa;
    font-size: 12px;
    margin-top: 5px;
}
.bg-selector {
    position: fixed;
    bottom: 30px;
    right: 30px;
    display: flex;
    gap: 12px;
    z-index: 999;
}
.bg-circle {
    width: 60px;
    height: 60px;
    border-radius: 50%;
    border: 3px solid rgba(255,255,255,0.8);
    background-size: cover;
    cursor: pointer;
    transition: all 0.3s;
    box-shadow: 0 4px 15px rgba(0,0,0,0.5);
}
.bg-circle:hover {
    transform: scale(1.15);
    border-color: #4fc3f7;
}
.carousel {
    position: relative;
    width: 100%;
    height: 200px;
    overflow: hidden;
    border-radius: 10px;
    margin-bottom: 30px;
}
.carousel img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    position: absolute;
    top: 0;
    left: 0;
    opacity: 0;
    transition: opacity 0.5s;
}
.carousel img.active {
    opacity: 1;
}
.disabled-message {
    background: rgba(100,100,100,0.8);
    color: white;
    padding: 15px;
    border-radius: 10px;
    margin-bottom: 20px;
    text-align: center;
    font-weight: bold;
}
</style>
<% if bg_enabled == '0' then %>
<div class="disabled-message"><%=pcdata(remote_message)%></div>
<% else %>
<div class="banner-hero">
    <div class="carousel">
        <%
            local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
            local bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
        %>
        <img src="<%=bg_path%>/bg0.jpg?t=<%=os.time()%>" data-bg="0">
        <img src="<%=bg_path%>/bg1.jpg?t=<%=os.time()%>" data-bg="1">
        <img src="<%=bg_path%>/bg2.jpg?t=<%=os.time()%>" data-bg="2">
    </div>
    <div class="banner-scroll" id="banner-text"><%=pcdata(text:gsub("\\n", " · "))%></div>
    <div class="banner-contacts">
        <div class="contact-card">
            <span>📱 Telegram</span>
            <strong>@fgnb111999</strong>
            <button class="copy-btn" onclick="copyText('@fgnb111999')">复制</button>
        </div>
        <div class="contact-card">
            <span>💬 QQ</span>
            <strong>183452852</strong>
            <button class="copy-btn" onclick="copyText('183452852')">复制</button>
        </div>
        <div class="contact-card">
            <span>📧 Email</span>
            <strong>niwo5507@gmail.com</strong>
            <button class="copy-btn" onclick="copyText('niwo5507@gmail.com')">复制</button>
        </div>
    </div>
    <% if nav_data and nav_data.nav_tabs then %>
    <div style="margin-top:30px">
        <h3 style="color:white;text-align:center;text-shadow:2px 2px 4px rgba(0,0,0,0.6)">🚀 快速导航</h3>
        <div class="nav-groups" id="nav-groups">
            <% for i, tab in ipairs(nav_data.nav_tabs) do %>
            <div class="nav-group" data-page="<%=math.ceil(i/4)%>" style="display:none;" onmouseenter="showLinks(this)" onclick="toggleLinks(this)">
                <div class="nav-group-title">
                    <% if tab.icon then %>
                    <img src="<%=pcdata(tab.icon)%>" alt="icon">
                    <% end %>
                    <%=pcdata(tab.title)%>
                </div>
                <% if tab.desc then %>
                <div class="nav-desc"><%=pcdata(tab.desc)%></div>
                <% end %>
                <div class="nav-links">
                    <% for _, link in ipairs(tab.links) do %>
                    <a href="<%=pcdata(link.url)%>" target="_blank"><%=pcdata(link.name)%></a>
                    <% end %>
                </div>
            </div>
            <% end %>
        </div>
        <div class="pagination">
            <button onclick="changePage(-1)">上一页</button>
            <span id="page-info">1 / <%=math.ceil(#nav_data.nav_tabs/4)%></span>
            <button onclick="changePage(1)">下一页</button>
        </div>
    </div>
    <% end %>
</div>
<div class="bg-selector">
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg0.jpg?t=<%=os.time()%>)" onclick="changeBg(0)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg1.jpg?t=<%=os.time()%>)" onclick="changeBg(1)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg2.jpg?t=<%=os.time()%>)" onclick="changeBg(2)"></div>
</div>
<% end %>
<script>
// 背景轮播（仅前端切换）
(function() {
    var images = document.querySelectorAll('.carousel img');
    var interval = parseInt('<%=carousel_interval%>', 10) || 5000;
    var current = 0;
    if (images.length > 1) {
        images[current].classList.add('active');
        setInterval(function() {
            images[current].classList.remove('active');
            current = (current + 1) % images.length;
            images[current].classList.add('active');
        }, interval);
    }
})();

// 横幅轮播
(function() {
    var bannerTexts = '<%=banner_texts%>'.split('|').filter(function(t) { return t.trim(); });
    var interval = parseInt('<%=carousel_interval%>', 10) || 5000;
    if (bannerTexts.length > 1) {
        var idx = 0;
        var elem = document.getElementById('banner-text');
        setInterval(function() {
            idx = (idx + 1) % bannerTexts.length;
            elem.style.opacity = '0';
            setTimeout(function() {
                elem.textContent = bannerTexts[idx];
                elem.style.opacity = '1';
            }, 300);
        }, interval);
        elem.style.transition = 'opacity 0.3s';
    }
})();

// 分页逻辑
var currentPage = 1;
var totalPages = <%=math.ceil(#nav_data.nav_tabs/4)%>;
function changePage(delta) {
    currentPage = Math.max(1, Math.min(totalPages, currentPage + delta));
    document.querySelectorAll('.nav-group').forEach(function(g) {
        g.style.display = (parseInt(g.getAttribute('data-page')) === currentPage) ? 'block' : 'none';
    });
    document.getElementById('page-info').textContent = currentPage + ' / ' + totalPages;
    updatePaginationButtons();
}
function updatePaginationButtons() {
    document.querySelector('.pagination button:first-child').disabled = (currentPage === 1);
    document.querySelector('.pagination button:last-child').disabled = (currentPage === totalPages);
}
changePage(0);

// 导航交互
function showLinks(el) {
    document.querySelectorAll('.nav-links').forEach(function(l) { l.classList.remove('active'); });
    el.querySelector('.nav-links').classList.add('active');
}
function toggleLinks(el) {
    el.querySelector('.nav-links').classList.toggle('active');
}
function changeBg(n) {
    var f = document.createElement('form');
    f.method = 'POST';
    f.action = '<%=luci.dispatcher.build_url("admin/status/banner/do_set_bg")%>';
    f.innerHTML = '<input type="hidden" name="token" value="<%=token%>"><input type="hidden" name="bg" value="' + n + '">';
    document.body.appendChild(f);
    f.submit();
}
function copyText(txt) {
    var textarea = document.createElement('textarea');
    textarea.value = txt;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
        document.execCommand('copy');
        alert('已复制: ' + txt);
    } catch (err) {
        prompt('请手动复制以下内容：', txt);
    }
    document.body.removeChild(textarea);
}
</script>
<%+footer%>
DISPLAYVIEW

# 设置页面
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/settings.htm" <<'SETTINGSVIEW'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
    <h2>远程更新设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <% if remote_message and remote_message ~= '' then %>
        <div class="disabled-message" style="background:rgba(100,100,100,0.8);color:white;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center;font-weight:bold">
            <%=pcdata(remote_message)%>
        </div>
        <% end %>
        <div class="cbi-value">
            <label class="cbi-value-title">背景透明度</label>
            <div class="cbi-value-field">
                <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%" />
                <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                <p style="color:#aaa;font-size:12px">💡 拖动即刻生效（自动保存）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">轮播间隔（毫秒）</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_carousel_interval')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="number" name="carousel_interval" value="<%=carousel_interval%>" min="1000" max="30000" style="width:100px;background:rgba(255,255,255,0.9);color:#333" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 设置轮播间隔（1000-30000毫秒）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">永久存储背景</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_persistent_storage')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="checkbox" name="persistent_storage" value="1" <%=persistent_storage=='1' and 'checked' or ''%> />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 启用后背景图存储到 /overlay/banner（防止掉电丢失）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">更新源</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_update_url')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <select name="selected_url" style="flex:1;background:rgba(255,255,255,0.9);color:#333">
                        <% for _, url in ipairs(uci:get_list("banner", "banner", "update_urls")) do %>
                        <option value="<%=url%>" <%=url==uci:get("banner", "banner", "selected_url") and 'selected' or ''%>><%=url%></option>
                        <% end %>
                    </select>
                    <input type="submit" class="cbi-button cbi-button-apply" value="选择更新源" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 选择优先使用的更新源</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">公告文本</label>
            <div class="cbi-value-field">
                <textarea readonly style="width:100%;height:80px;background:rgba(255,255,255,0.9);color:#333"><%=pcdata(text)%></textarea>
                <p style="color:#aaa;font-size:12px">📌 由远程仓库控制</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">自动更新间隔</label>
            <div class="cbi-value-field">
                <input type="text" value="86400 秒 (24小时)" disabled style="background:rgba(200,200,200,0.5);color:#333">
                <p style="color:#5cb85c;font-size:12px">✓ 已启用 (系统锁定，不可修改)</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">上次更新</label>
            <div class="cbi-value-field">
                <input type="text" value="<%= last_update == '0' and '从未更新' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update)) %>" readonly style="background:rgba(255,255,255,0.9);color:#333">
            </div>
        </div>
        <div class="cbi-value">
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_update')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="立即手动更新" />
                </form>
                <p style="color:#aaa;font-size:12px">🔄 不受24小时限制，立即执行</p>
            </div>
        </div>
        <h3 style="color:white">更新日志 (最近20条)</h3>
        <div style="background:rgba(0,0,0,0.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,0.1)"><%=pcdata(log)%></div>
    </div></div>
</div>
<%+footer%>
SETTINGSVIEW

# 背景设置页面
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/background.htm" <<'BGVIEW'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
    <h2>背景图设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <div class="cbi-value">
            <label class="cbi-value-title">实时透明度调节</label>
            <div class="cbi-value-field">
                <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%" />
                <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                <p style="color:#aaa;font-size:12px">💡 拖动即刻生效（自动保存）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">永久存储背景</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_persistent_storage')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="checkbox" name="persistent_storage" value="1" <%=persistent_storage=='1' and 'checked' or ''%> />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 启用后背景图存储到 /overlay/banner（防止掉电丢失）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">选择背景图组</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_load_group')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <select name="group" style="flex:1;background:rgba(255,255,255,0.9);color:#333">
                        <option value="1" <%=bg_group=='1' and 'selected' or ''%>>第 1 组 (背景1-3)</option>
                        <option value="2" <%=bg_group=='2' and 'selected' or''%>>第 2 组 (背景4-6)</option>
                        <option value="3" <%=bg_group=='3' and 'selected' or''%>>第 3 组 (背景7-9)</option>
                        <option value="4" <%=bg_group=='4' and 'selected' or''%>>第 4 组 (背景10-12)</option>
                    </select>
                    <input type="submit" class="cbi-button cbi-button-apply" value="加载背景组" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 选择后自动下载并缓存对应组的三张图片</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">手动填写背景图链接</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="text" name="custom_bg_url" placeholder="https://example.com/image.jpg" style="width:65%;background:rgba(255,255,255,0.9);color:#333" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用链接" />
                </form>
                <p style="color:#aaa;font-size:12px">📌 仅支持 HTTPS 链接（JPG/PNG），应用后覆盖 bg0.jpg</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">从本地上传背景图</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="file" name="bg_file" accept="image/jpeg,image/png" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="上传并应用" />
                </form>
                <p style="color:#aaa;font-size:12px">📤 支持 JPG/PNG，上传后覆盖 bg0.jpg</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">删除缓存图片</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_clear_cache')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="submit" class="cbi-button cbi-button-remove" value="删除缓存" />
                </form>
                <p style="color:#aaa;font-size:12px">🗑️ 清空所有 bg*.jpg 缓存</p>
            </div>
        </div>
        <h3 style="color:white">背景日志 (最近20条)</h3>
        <div style="background:rgba(0,0,0,0.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,0.1)"><%=pcdata(log)%></div>
    </div></div>
</div>
<%+footer%>
BGVIEW

echo "=========================================="
echo "✓ 软件包 luci-app-banner_2.2-1_all.ipk 准备完成！"
echo "=========================================="
echo "包目录: $PKG_DIR"
echo "编译提示: 请将 $PKG_DIR 置于 OpenWrt 源码的 package 目录下"
echo "然后运行 make package/custom/luci-app-banner/compile V=s"
echo ""
echo "主要功能："
echo "  • 统一背景显示（修复白板问题）"
echo "  • 独立更新机制："
echo "    - 手动更新: 立即执行，无锁限制"
echo "    - 自动更新: 开机一次 + 每24小时一次"
echo "  • 轮播横幅: 彩虹渐变，每5秒切换（可通过 LuCI 调整）"
echo "  • 分页导航: 每页显示4个导航组，支持 icon 和 desc"
echo "  • 背景轮播: 首页展示多背景轮播"
echo "  • 实时透明度调节: 拖动滑块即时生效（自动保存）"
echo "  • 本地上传/远程链接/永久存储支持"
echo "  • 多源更新: 支持多个 JSON 数据源，LuCI 选择"
echo "  • 安全增强: JSON 校验 + URL 注入防护"
echo "  • 缓存清理: 定期删除超过3天的缓存文件"
echo "  • 远程控制: 支持 enabled/disable_message 远程禁用"
echo "  • 状态检查: /etc/init.d/banner status 查看状态"
echo ""
echo "JSON 数据结构示例："
echo '{'
echo '  "enabled": true,'
echo '  "disable_message": "系统维护中，请于 2025-10-04 08:00 后访问",'
echo '  "text": "默认横幅文本",'
echo '  "color": "rainbow",'
echo '  "banner_texts": ['
echo '    "🎉 横幅文本1",'
echo '    "🚀 横幅文本2",'
echo '    "💎 横幅文本3"'
echo '  ],'
echo '  "background_1": "https://...",'
echo '  ...'
echo '  "background_12": "https://...",'
echo '  "nav_tabs": ['
echo '    {'
echo '      "title": "导航组1",'
echo '      "icon": "https://example.com/icon1.png",'
echo '      "desc": "组1描述",'
echo '      "links": [...]'
echo '    }'
echo '  ]'
echo '}'
echo "=========================================="
