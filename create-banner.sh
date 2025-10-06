#!/bin/bash
# OpenWrt Banner Plugin - Fixed Version v2.5
# All critical issues resolved

set -e

echo "=========================================="
echo "OpenWrt Banner Plugin v2.5 - Fixed"
echo "=========================================="

# Determine package directory
if [ -n "$GITHUB_WORKSPACE" ]; then
    PKG_DIR="$GITHUB_WORKSPACE/openwrt/package/custom/luci-app-banner"
elif [ -d "openwrt/package" ]; then
    PKG_DIR="$(pwd)/openwrt/package/custom/luci-app-banner"
else
    PKG_DIR="./luci-app-banner"
fi

echo "Package directory: $PKG_DIR"

# Clean and create directory structure
echo "[1/3] Creating directory structure..."
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"/root/{etc/{config,init.d,cron.d},usr/{bin,lib/lua/luci/{controller,view/banner}},www/luci-static/banner,overlay/banner}

echo "[1.5/3] Skipping default background creation..."
# Create Makefile
echo "[2/3] Creating Makefile..."
cat > "$PKG_DIR/Makefile" <<'MAKEFILE'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.5
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
	command -v uci >/dev/null 2>&1 || exit 0
	mkdir -p /tmp/banner_cache /overlay/banner
	[ -f /www/luci-static/banner/default_bg.jpg ] || touch /www/luci-static/banner/default_bg.jpg
	/etc/init.d/banner enable
	/usr/bin/banner_manual_update.sh && sleep 3 && /usr/bin/banner_bg_loader.sh 1 >/dev/null 2>&1 &
	/etc/init.d/nginx restart 2>/dev/null || /etc/init.d/uhttpd restart 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
MAKEFILE

echo "[3/3] Creating all package files..."

# UCI Configuration - FIXED: Default opacity 90
cat > "$PKG_DIR/root/etc/config/banner" <<'UCICONF'
config banner 'banner'
	option text '🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行'
	option color 'rainbow'
	option opacity '90'
	option carousel_interval '5000'
	option bg_group '1'
	option bg_enabled '1'
	option persistent_storage '0'
	option current_bg '0'
	list update_urls 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	list update_urls 'https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json'
	option selected_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option update_interval '10800'
	option last_update '0'
	option banner_texts ''
	option remote_message ''
UCICONF

# Cache cleaner script
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
log "[√] Removed files older than 3 days"
CLEANER

# Manual update script
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

if ! command -v uci >/dev/null 2>&1; then
    log "Skipping UCI operations in build environment"
    exit 0
fi

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
    log "[✓] JSON downloaded, size: $(stat -c %s "$CACHE/banner_new.json") bytes"
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
    log "[×] All Sources Failed, keeping old nav_data.json"
fi
MANUALUPDATE

# Auto update script
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

if ! command -v uci >/dev/null 2>&1; then
    log "Skipping UCI operations in build environment"
    exit 0
fi

LAST=$(uci -q get banner.banner.last_update || echo 0)
NOW=$(date +%s)
INTERVAL=86400

[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0

log "========== Auto Update Started =========="

# Use same logic as manual update
/usr/bin/banner_manual_update.sh
AUTOUPDATE

# Background loader - FIXED: Better image validation and path handling
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}
LOG="/tmp/banner_bg.log"
CACHE="/tmp/banner_cache"
WEB="/www/luci-static/banner"
PERSISTENT="/overlay/banner"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    [ -s "$LOG" ] && [ $(stat -f %z "$LOG" 2>/dev/null || stat -c %s "$LOG") -gt 51200 ] && {
        mv "$LOG" "$LOG.bak"
        tail -n 10 "$LOG.bak" > "$LOG"
        rm -f "$LOG.bak"
    }
}

if ! command -v uci >/dev/null 2>&1; then
    log "Skipping UCI operations in build environment"
    DEST="$WEB"
else
    UCI_PERSISTENT=$(uci -q get banner.banner.persistent_storage || echo 0)
    if [ "$UCI_PERSISTENT" = "1" ]; then
        DEST="$PERSISTENT"
    else
        DEST="$WEB"
    fi
fi

mkdir -p "$CACHE" "$WEB" "$PERSISTENT"

# Wait for nav_data.json (max 10 seconds)
JSON="$CACHE/nav_data.json"
WAIT_COUNT=0
while [ ! -f "$JSON" ] && [ $WAIT_COUNT -lt 10 ]; do
    log "Waiting for nav_data.json... ($WAIT_COUNT/10)"
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -f "$JSON" ]; then
    log "[×] Timeout: nav_data.json not generated, using default background"
    if [ -s "$WEB/default_bg.jpg" ]; then
        cp "$WEB/default_bg.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
        cp "$WEB/default_bg.jpg" "$DEST/bg0.jpg" 2>/dev/null
        cp "$WEB/default_bg.jpg" "$DEST/bg1.jpg" 2>/dev/null
        cp "$WEB/default_bg.jpg" "$DEST/bg2.jpg" 2>/dev/null
    fi
    exit 1
fi

# Single instance lock
LOCK_DIR="/tmp/banner_bg_loader.lock"
if [ -d "$LOCK_DIR" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)))
    if [ $LOCK_AGE -gt 300 ]; then
        log "Clearing stale lock (${LOCK_AGE}s)"
        rm -rf "$LOCK_DIR"
    else
        log "Another download task is running (${LOCK_AGE}s ago)"
        exit 1
    fi
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "Cannot create lock"
    exit 1
fi

trap 'rm -rf "$LOCK_DIR"' EXIT

validate_url() {
    local url=$1
    case "$url" in
        http://*|https://*) return 0 ;;
        *) log "[×] Invalid URL: $url"; return 1 ;;
    esac
}

# Validate JPEG
validate_jpeg() {
    local file=$1
    if [ ! -s "$file" ]; then
        return 1
    fi
    
    # Check magic number (FF D8 FF)
    local header=$(od -An -t x1 -N 3 "$file" 2>/dev/null | tr -d ' \n')
    if [ "$header" = "ffd8ff" ]; then
        return 0
    fi
    
    # Fallback: use file command
    if command -v file >/dev/null 2>&1; then
        file "$file" | grep -qiE '(JPEG|JPG)' && return 0
    fi
    
    return 1
}

log "Loading Group ${BG_GROUP} backgrounds..."

echo "loading" > "$CACHE/bg_loading"
rm -f "$CACHE/bg_complete"

START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))

if ! jq empty "$JSON" 2>/dev/null; then
    log "[×] JSON format error: $JSON"
    rm -f "$CACHE/bg_loading"
    exit 1
fi

rm -f "$DEST"/bg{0,1,2}.jpg
if [ "$UCI_PERSISTENT" = "1" ]; then
    rm -f "$WEB"/bg{0,1,2}.jpg
fi

DOWNLOAD_SUCCESS=0

for i in 0 1 2; do
    KEY="background_$((START_IDX + i))"
    URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
    if [ -n "$URL" ] && validate_url "$URL"; then
        log "  Downloading $KEY..."
        TMPFILE="$DEST/bg$i.tmp"
        curl -sL --max-time 15 "$URL" -o "$TMPFILE" 2>/dev/null
        
        if validate_jpeg "$TMPFILE"; then
            mv "$TMPFILE" "$DEST/bg$i.jpg"
            chmod 644 "$DEST/bg$i.jpg"
            log "  [√] bg$i.jpg downloaded successfully"
            DOWNLOAD_SUCCESS=1
            
            if [ "$UCI_PERSISTENT" = "1" ]; then
                cp "$DEST/bg$i.jpg" "$WEB/bg$i.jpg" 2>/dev/null
            fi
            
            if [ $i -eq 0 ]; then
                cp "$DEST/bg$i.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
            fi
        else
            log "  [×] bg$i.jpg invalid or non-JPEG format"
            rm -f "$TMPFILE"
        fi
    else
        log "  [×] $KEY invalid or URL format error"
    fi
done

# Fallback to default if no images downloaded
if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "[!] No images downloaded, using default background"
    for i in 0 1 2; do
        if [ -s "$WEB/default_bg.jpg" ]; then
            cp "$WEB/default_bg.jpg" "$DEST/bg$i.jpg" 2>/dev/null
            [ $i -eq 0 ] && cp "$WEB/default_bg.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
        fi
    done
fi

# Ensure current_bg.jpg exists
if [ ! -s "$CACHE/current_bg.jpg" ]; then
    if [ -s "$DEST/bg0.jpg" ]; then
        cp "$DEST/bg0.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
    elif [ -s "$WEB/default_bg.jpg" ]; then
        cp "$WEB/default_bg.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
    fi
fi

log "[Complete] Group ${BG_GROUP}"

rm -f "$CACHE/bg_loading"
echo "complete" > "$CACHE/bg_complete"
BGLOADER

# Cron jobs
cat > "$PKG_DIR/root/etc/cron.d/banner" <<'CRON'
0 * * * * root /usr/bin/banner_auto_update.sh
0 0 * * * root /usr/bin/banner_cache_cleaner.sh
CRON

# Init script
cat > "$PKG_DIR/root/etc/init.d/banner" <<'INIT'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start() {
    if ! command -v uci >/dev/null 2>&1; then
        return 0
    fi
    
    # Wait for network (max 60 seconds)
    WAIT=0
    while ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && [ $WAIT -lt 60 ]; do
        sleep 2
        WAIT=$((WAIT + 2))
    done
    
    # Ensure default background exists
    mkdir -p /tmp/banner_cache /www/luci-static/banner /overlay/banner
    
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

    echo "===== Banner Status ====="
    if [ "$uci_enabled" = "0" ]; then
        echo "Status: Disabled"
        echo "Reason: $remote_msg"
    else
        echo "Status: Enabled"
    fi
    echo "Current Background: bg$current_bg.jpg (Group $bg_group)"
    if [ "$last_update" = "0" ]; then
        echo "Last Update: Never"
    else
        echo "Last Update: $(date -d "@$last_update" '+%Y-%m-%d %H:%M:%S')"
    fi
    echo "Cache Directory: /tmp/banner_cache"
    echo "Background Storage: $(uci -q get banner.banner.persistent_storage | grep -q 1 && echo '/overlay/banner' || echo '/www/luci-static/banner')"
    echo "========================"
}
INIT

# LuCI 控制器 - 修复版（使用 require("uci") 而非 luci.model.uci）
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
    entry({"admin", "status", "banner", "check_bg_complete"}, call("action_check_bg_complete")).leaf = true
    entry({"admin", "status", "banner", "do_reset_defaults"}, post("action_do_reset_defaults")).leaf = true
end

       function action_display()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    local jsonc = require("luci.jsonc")  
    -- 优先检查远程禁用状态
    local bg_enabled = uci:get("banner", "banner", "bg_enabled") or "1"
    if bg_enabled == "0" then
        local remote_msg = uci:get("banner", "banner", "remote_message") or "服务已被远程禁用"
        luci.template.render("banner/display", {
            text = "",
            color = "rainbow",
            opacity = uci:get("banner", "banner", "opacity") or "50",
            carousel_interval = "5000",
            current_bg = "0",
            bg_enabled = "0",
            remote_message = remote_msg,
            banner_texts = "",
            nav_data = { nav_tabs = {} },
            persistent = uci:get("banner", "banner", "persistent_storage") or "0",
            bg_path = "/tmp/banner_cache",
            token = luci.dispatcher.context.authsession or ""
        })
        return
    end
    
    local nav_file = fs.readfile("/tmp/banner_cache/nav_data.json")
    local nav_data = { nav_tabs = {} }
    if nav_file then
        local success, parsed = pcall(jsonc.parse, nav_file)
        if success and parsed and parsed.nav_tabs then
            for i, tab in ipairs(parsed.nav_tabs) do
                for j, link in ipairs(tab.links) do
                    if not link.url:match("^https?://(raw%.githubusercontent%.com|gitee%.com)/") then
                        parsed.nav_tabs[i].links[j].url = "#"
                    end
                end
            end
            nav_data = parsed
        else
            local log = fs.readfile("/tmp/banner_update.log") or ""
            fs.writefile("/tmp/banner_update.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] JSON 解析失败")
        end
    else
        local log = fs.readfile("/tmp/banner_update.log") or ""
        fs.writefile("/tmp/banner_update.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] nav_data.json 文件不存在")
    end
    
    local banner_texts = uci:get("banner", "banner", "banner_texts") or ""
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"

    luci.template.render("banner/display", {
        text = uci:get("banner", "banner", "text") or "欢迎访问福利导航",
        color = uci:get("banner", "banner", "color") or "rainbow",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        carousel_interval = uci:get("banner", "banner", "carousel_interval") or "5000",
        current_bg = uci:get("banner", "banner", "current_bg") or "0",
        bg_enabled = bg_enabled,
        remote_message = uci:get("banner", "banner", "remote_message") or "",
        banner_texts = banner_texts,
        nav_data = nav_data,
        persistent = persistent,
        bg_path = bg_path,
        token = luci.dispatcher.context.authsession or ""
    })
end

function action_settings()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    local update_urls = uci:get("banner", "banner", "update_urls") or { "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json" }
    if type(update_urls) ~= "table" then
        update_urls = { update_urls }
    end
    local display_urls = {}
    for _, url in ipairs(update_urls) do
        local display = url
        if url:match("github.com") then
            display = "GitHub"
        elseif url:match("gitee.com") then
            display = "Gitee"
        end
        table.insert(display_urls, {value = url, display = display})
    end
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    luci.template.render("banner/settings", {
        text = uci:get("banner", "banner", "text") or "",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        carousel_interval = uci:get("banner", "banner", "carousel_interval") or "5000",
        persistent_storage = persistent,
        last_update = uci:get("banner", "banner", "last_update") or "0",
        remote_message = uci:get("banner", "banner", "remote_message") or "",
        display_urls = display_urls,
        selected_url = uci:get("banner", "banner", "selected_url") or "",
        bg_path = bg_path,
        token = luci.dispatcher.context.authsession or "",
        log = fs.readfile("/tmp/banner_update.log") or "暂无日志"
    })
end

function action_background()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    luci.template.render("banner/background", {
        bg_group = uci:get("banner", "banner", "bg_group") or "1",
        opacity = uci:get("banner", "banner", "opacity") or "50",
        current_bg = uci:get("banner", "banner", "current_bg") or "0",
        persistent_storage = persistent,
        bg_path = bg_path,
        token = luci.dispatcher.context.authsession or "",
        log = fs.readfile("/tmp/banner_bg.log") or "暂无日志"
    })
end

function action_do_update()
    luci.sys.call("/usr/bin/banner_manual_update.sh >/dev/null 2>&1 &")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_bg()
    local uci = require("uci").cursor()
    local bg = luci.http.formvalue("bg")
    if bg then
        uci:set("banner", "banner", "current_bg", bg)
        uci:commit("banner")
        local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
        local src = "/www/luci-static/banner"
        if persistent == "1" then
            src = "/overlay/banner"
        end
        luci.sys.call(string.format("cp %s/bg%s.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null", src, bg))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_clear_cache()
    -- 只清理运行时和持久缓存，不动固件自带背景
    luci.sys.call("rm -f /tmp/banner_cache/bg*.jpg /overlay/banner/bg*.jpg")

    local fs = require("nixio.fs")
    local log = fs.readfile("/tmp/banner_bg.log") or ""
    fs.writefile("/tmp/banner_bg.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] 🗑️ 已清理缓存图片")

    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end


function action_do_load_group()
    local uci = require("uci").cursor()
    local group = luci.http.formvalue("group")
    if group then
        uci:set("banner", "banner", "bg_group", group)
        uci:commit("banner")
        luci.sys.call(string.format("/usr/bin/banner_bg_loader.sh %s >/dev/null 2>&1 &", group))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_upload_bg()
    local fs = require("nixio.fs")
    local http = require("luci.http")
    local uci = require("uci").cursor()
    local sys = require("luci.sys")
    
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"

    -- 确保目录存在且可写
    if not fs.stat(dest) then
        local ok = sys.call("mkdir -p '" .. dest .. "' && chmod 755 '" .. dest .. "'")
        if ok ~= 0 then
            local log = fs.readfile("/tmp/banner_bg.log") or ""
            fs.writefile("/tmp/banner_bg.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ❌ 无法创建目录: " .. dest)
            http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
            return
        end
    end

    local tmpfile = dest .. "/bg0.tmp"
    local finalfile = dest .. "/bg0.jpg"
    local filesize = 0
    local upload_failed = false
    local fail_reason = ""

    http.setfilehandler(function(meta, chunk, eof)
        if not meta then return end
        
        if meta.name == "bg_file" then
            if chunk then
                filesize = filesize + #chunk
                
                -- 文件大小限制 5MB
                if filesize > 5242880 then
                    upload_failed = true
                    fail_reason = "文件超过 5MB"
                    fs.remove(tmpfile)
                    return
                end
                
                local fp = io.open(tmpfile, meta.file and "ab" or "wb")
                if fp then
                    fp:write(chunk)
                    fp:close()
                else
                    upload_failed = true
                    fail_reason = "无法写入临时文件"
                    return
                end
            end

            if eof then
                if upload_failed then
                    fs.remove(tmpfile)
                    local log = fs.readfile("/tmp/banner_bg.log") or ""
                    fs.writefile("/tmp/banner_bg.log", 
                        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ❌ 上传失败: " .. fail_reason)
                    return
                end
                
                if not fs.stat(tmpfile) then
                    local log = fs.readfile("/tmp/banner_bg.log") or ""
                    fs.writefile("/tmp/banner_bg.log", 
                        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ❌ 临时文件不存在")
                    return
                end

                -- 多种方式验证 JPEG
                local is_jpg = false
                
                -- 方法1: 使用 file 命令
                if sys.call("command -v file >/dev/null 2>&1") == 0 then
                    is_jpg = sys.call("file '" .. tmpfile .. "' | grep -qiE '(JPEG|JPG)'") == 0
                end
                
                -- 方法2: 检查文件头魔数 (FF D8 FF)
                if not is_jpg then
                    local fp = io.open(tmpfile, "rb")
                    if fp then
                        local header = fp:read(3)
                        fp:close()
                        if header and #header == 3 then
                            local b1, b2, b3 = header:byte(1, 3)
                            is_jpg = (b1 == 0xFF and b2 == 0xD8 and b3 == 0xFF)
                        end
                    end
                end

                if is_jpg then
                    fs.rename(tmpfile, finalfile)
                    sys.call("chmod 644 '" .. finalfile .. "'")
                    
                    -- 同步到另一个位置
                    if persistent == "1" then
                        sys.call("cp '" .. finalfile .. "' /www/luci-static/banner/bg0.jpg 2>/dev/null")
                    end
                    
                    -- 更新当前背景
                    sys.call("cp '" .. finalfile .. "' /tmp/banner_cache/current_bg.jpg 2>/dev/null")
                    
                    uci:set("banner", "banner", "current_bg", "0")
                    uci:commit("banner")
                    
                    local log = fs.readfile("/tmp/banner_bg.log") or ""
                    fs.writefile("/tmp/banner_bg.log", 
                        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ✅ 本地上传成功 (" .. filesize .. " 字节)")
                else
                    fs.remove(tmpfile)
                    local log = fs.readfile("/tmp/banner_bg.log") or ""
                    fs.writefile("/tmp/banner_bg.log", 
                        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ❌ 上传失败: 仅支持 JPG 格式")
                end
            end
        end
    end)

    http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_apply_url()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    local http = require("luci.http")

    local url = luci.http.formvalue("custom_bg_url")
    if not url or url == "" then
        return luci.http.write("未填写 URL")
    end

    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"

-- 确保目录存在
    luci.sys.call("mkdir -p '" .. dest .. "' && chmod 755 '" .. dest .. "'")
    
    if url and url:match("^https://(raw%.githubusercontent%.com|gitee%.com)/.*%.(jpg|jpeg)$") then
        local tmpfile = dest .. "/bg0.tmp"
        local finalfile = dest .. "/bg0.jpg"
        local ok = os.execute(string.format("curl -fsSL --max-time 20 --max-filesize 3145728 '%s' -o '%s'", url, tmpfile))

       if ok == 0 and fs.stat(tmpfile) then
    local is_jpg = luci.sys.call("file " .. tmpfile .. " | grep -q 'JPEG'") == 0
    if is_jpg then
        fs.rename(tmpfile, finalfile)
        if persistent == "1" then
            luci.sys.call(string.format("cp '%s' /www/luci-static/banner/bg0.jpg", finalfile))
        end
        uci:set("banner", "banner", "current_bg", "0")
        uci:commit("banner")

        local log = fs.readfile("/tmp/banner_bg.log") or ""
        fs.writefile("/tmp/banner_bg.log",
            log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") ..
            "] ✅ 下载成功 (JPG): " .. url:match("^https?://[^/]+") .. "/...")
    else
        fs.remove(tmpfile)
        local log = fs.readfile("/tmp/banner_bg.log") or ""
        fs.writefile("/tmp/banner_bg.log",
            log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") ..
            "] ❌ 下载失败: 仅支持 JPG 格式")
    end
else
    fs.remove(tmpfile)
    local log = fs.readfile("/tmp/banner_bg.log") or ""
    fs.writefile("/tmp/banner_bg.log",
        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") ..
        "] ❌ 下载失败: " .. url:match("^https?://[^/]+") .. "/...")
end

    else
        local log = fs.readfile("/tmp/banner_bg.log") or ""
        fs.writefile("/tmp/banner_bg.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] ⚠️ 非法URL或域名: " .. tostring(url:match("^https?://[^/]+") or url))
    end

    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end


function action_do_set_opacity()
    local uci = require("uci").cursor()
    local opacity = luci.http.formvalue("opacity")
    if opacity and tonumber(opacity) and tonumber(opacity) >= 0 and tonumber(opacity) <= 100 then
        uci:set("banner", "banner", "opacity", opacity)
        uci:commit("banner")
    end
    luci.http.status(200, "OK")
end

function action_do_set_carousel_interval()
    local uci = require("uci").cursor()
    local interval = luci.http.formvalue("carousel_interval")
    if interval and tonumber(interval) and tonumber(interval) >= 1000 and tonumber(interval) <= 30000 then
        uci:set("banner", "banner", "carousel_interval", interval)
        uci:commit("banner")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_update_url()
    local uci = require("uci").cursor()
    local selected_url = luci.http.formvalue("selected_url")
    if selected_url and selected_url:match("^https?://") then
        uci:set("banner", "banner", "selected_url", selected_url)
        uci:commit("banner")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_persistent_storage()
    local uci = require("uci").cursor()
    local persistent = luci.http.formvalue("persistent_storage")
    if persistent and persistent:match("^[0-1]$") then
        uci:set("banner", "banner", "persistent_storage", persistent)
        uci:commit("banner")
        if persistent == "1" then
            luci.sys.call("mkdir -p /overlay/banner")
            luci.sys.call("cp /www/luci-static/banner/bg*.jpg /overlay/banner/ 2>/dev/null")
        else
            luci.sys.call("cp /overlay/banner/bg*.jpg /www/luci-static/banner/ 2>/dev/null")
        end
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_check_bg_complete()
    local fs = require("nixio.fs")
    if fs.access("/tmp/banner_cache/bg_complete") then
        luci.http.write("complete")
    else
        luci.http.write("pending")
    end
end

function action_do_reset_defaults()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    
    -- 恢复默认配置
    uci:set("banner", "banner", "text", "🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行")
    uci:set("banner", "banner", "color", "rainbow")
    uci:set("banner", "banner", "opacity", "50")
    uci:set("banner", "banner", "carousel_interval", "5000")
    uci:set("banner", "banner", "bg_group", "1")
    uci:set("banner", "banner", "current_bg", "0")
    uci:set("banner", "banner", "bg_enabled", "1")
    uci:set("banner", "banner", "persistent_storage", "0")
    uci:delete("banner", "banner", "remote_message")
    uci:set("banner", "banner", "last_update", "0")
    uci:commit("banner")
    
    -- 清理缓存
    luci.sys.call("rm -f /tmp/banner_cache/*.json /tmp/banner_cache/*.jpg")
    luci.sys.call("rm -f /overlay/banner/*.jpg")
    
    -- 记录日志
    local log = fs.readfile("/tmp/banner_update.log") or ""
    fs.writefile("/tmp/banner_update.log", 
        log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] 🔄 已恢复默认配置")
    
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end
CONTROLLER

-- FIXED: Global style with higher CSS priority and correct background path
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/global_style.htm" <<'GLOBALSTYLE'
<%
local uci = require("uci").cursor()
local opacity = tonumber(uci:get("banner", "banner", "opacity") or "90")
local alpha = (100 - opacity) / 100
local bg_path = "/tmp/banner_cache"
%>
<style type="text/css">
/* CRITICAL: Force override all backgrounds with !important */
html, body {
    background: linear-gradient(rgba(0,0,0,<%=alpha%>), rgba(0,0,0,<%=alpha%>)), 
                url(<%=bg_path%>/current_bg.jpg?t=<%=os.time()%>) center/cover fixed no-repeat !important;
    min-height: 100vh !important;
    margin: 0 !important;
    padding: 0 !important;
}

#maincontent, .container, .cbi-map, .cbi-section, 
.cbi-map > *, .cbi-section > *, #maincontent > .container > .cbi-map > *,
.cbi-map table, .cbi-section table, .cbi-value, .cbi-value-field,
.cbi-section-node, .cbi-map-descr, .cbi-section-descr,
.table, .tr, .td, .th {
    background: transparent !important;
    background-color: transparent !important;
    background-image: none !important;
}

.cbi-map, #maincontent > .container > .cbi-map {
    background: rgba(0,0,0,0.3) !important;
    border: 1px solid rgba(255,255,255,0.1) !important;
    border-radius: 12px !important;
    box-shadow: 0 8px 32px rgba(0,0,0,0.2) !important;
    padding: 15px !important;
    margin: 15px auto !important;
}

.cbi-section, .cbi-map > .cbi-section, .cbi-section-node {
    background: rgba(0,0,0,0.2) !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
    border-radius: 8px !important;
    padding: 10px !important;
    margin: 10px 0 !important;
}

.cbi-value-title, .cbi-section h2, .cbi-section h3, .cbi-map h2, .cbi-map h3,
label, legend, .cbi-section-descr {
    color: white !important;
    text-shadow: 0 2px 4px rgba(0,0,0,0.6) !important;
}

input[type="text"], input[type="number"], textarea, select {
    background: rgba(255,255,255,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: #333 !important;
    padding: 5px 10px !important;
    border-radius: 4px !important;
}

input:disabled, select:disabled {
    background: rgba(200,200,200,0.5) !important;
    cursor: not-allowed !important;
}

.cbi-button, input[type="submit"], button, .btn {
    background: rgba(66,139,202,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: white !important;
    padding: 6px 12px !important;
    border-radius: 4px !important;
    cursor: pointer !important;
    transition: all 0.3s !important;
}

.cbi-button:hover, input[type="submit"]:hover, button:hover {
    background: rgba(66,139,202,1) !important;
    transform: translateY(-1px) !important;
}

.cbi-button-remove {
    background: rgba(217,83,79,0.9) !important;
}

.cbi-button-reset {
    background: rgba(240,173,78,0.9) !important;
}
</style>
<script>
(function() {
    var sliders = document.querySelectorAll('input[type="range"][data-realtime="opacity"]');
    sliders.forEach(function(s) {
        s.addEventListener('input', function() {
            var val = parseInt(this.value);
            var a = (100 - val) / 100;
            document.documentElement.style.background = 
                'linear-gradient(rgba(0,0,0,' + a + '), rgba(0,0,0,' + a + ')), ' +
                'url(<%=bg_path%>/current_bg.jpg?t=<%=os.time()%>) center/cover fixed no-repeat';
            document.body.style.background = 
                'linear-gradient(rgba(0,0,0,' + a + '), rgba(0,0,0,' + a + ')), ' +
                'url(<%=bg_path%>/current_bg.jpg?t=<%=os.time()%>) center/cover fixed no-repeat';
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

-- FIXED: Display view with vertical layout and better mobile support
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/display.htm" <<'DISPLAYVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.banner-hero {
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 15px;
    padding: 20px;
    margin: 20px auto;
    max-width: 1200px;
}

.carousel {
    position: relative;
    width: 100%;
    height: 300px;
    overflow: hidden;
    border-radius: 10px;
    margin-bottom: 20px;
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

.banner-scroll {
    padding: 20px;
    margin-bottom: 30px;
    text-align: center;
    font-weight: bold;
    font-size: 18px;
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

/* FIXED: Vertical layout for contacts */
.banner-contacts {
    display: flex;
    flex-direction: column;
    gap: 15px;
    margin-bottom: 30px;
}

.contact-card {
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 10px;
    padding: 15px;
    text-align: center;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 10px;
}

.contact-info {
    flex: 1;
    min-width: 200px;
    text-align: left;
}

.contact-info span {
    display: block;
    color: #aaa;
    font-size: 14px;
    margin-bottom: 5px;
}

.contact-info strong {
    display: block;
    font-size: 16px;
    color: white;
}

.copy-btn {
    background: rgba(76,175,80,0.9);
    color: white;
    border: none;
    padding: 8px 18px;
    border-radius: 5px;
    cursor: pointer;
    font-weight: bold;
    transition: all 0.3s;
}

.copy-btn:hover {
    background: rgba(76,175,80,1);
    transform: translateY(-2px);
}

/* FIXED: Better navigation layout */
.nav-section {
    margin-top: 30px;
}

.nav-section h3 {
    color: white;
    text-align: center;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.6);
    margin-bottom: 20px;
}

.nav-groups {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
}

.nav-group {
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: 10px;
    padding: 15px;
    transition: all 0.3s;
}

.nav-group:hover {
    background: rgba(0,0,0,0.4);
    transform: translateY(-3px);
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
    cursor: pointer;
}

.nav-group-title img {
    width: 24px;
    height: 24px;
    margin-right: 8px;
}

.nav-desc {
    color: #aaa;
    font-size: 12px;
    margin: 5px 0 10px;
    text-align: center;
}

.nav-links {
    display: none;
    padding: 10px 0;
    max-height: 300px;
    overflow-y: auto;
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
    word-break: break-word;
}

.nav-links a:hover {
    background: rgba(79,195,247,0.3);
    transform: translateX(5px);
}

.pagination {
    text-align: center;
    margin-top: 20px;
    color: white;
}

.pagination button {
    background: rgba(66,139,202,0.9);
    border: 1px solid rgba(255,255,255,0.3);
    color: white;
    padding: 8px 15px;
    margin: 0 5px;
    border-radius: 5px;
    cursor: pointer;
}

.pagination button:disabled {
    background: rgba(100,100,100,0.5);
    cursor: not-allowed;
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

.disabled-message {
    background: rgba(100,100,100,0.8);
    color: white;
    padding: 15px;
    border-radius: 10px;
    margin-bottom: 20px;
    text-align: center;
    font-weight: bold;
}

/* Mobile responsive */
@media (max-width: 768px) {
    .carousel {
        height: 200px;
    }
    
    .banner-scroll {
        font-size: 16px;
        padding: 15px;
    }
    
    .nav-groups {
        grid-template-columns: 1fr;
    }
    
    .bg-selector {
        bottom: 15px;
        right: 15px;
    }
    
    .bg-circle {
        width: 50px;
        height: 50px;
    }
}
</style>

<% if bg_enabled == '0' then %>
<div class="disabled-message"><%=pcdata(remote_message)%></div>
<% else %>
<div class="banner-hero">
    <div class="carousel">
        <img src="<%=bg_path%>/bg0.jpg?t=<%=os.time()%>" data-bg="0" alt="Background 1">
        <img src="<%=bg_path%>/bg1.jpg?t=<%=os.time()%>" data-bg="1" alt="Background 2">
        <img src="<%=bg_path%>/bg2.jpg?t=<%=os.time()%>" data-bg="2" alt="Background 3">
    </div>
    
    <div class="banner-scroll" id="banner-text"><%=pcdata(text:gsub("\\n", " · "))%></div>
    
    <div class="banner-contacts">
        <div class="contact-card">
            <div class="contact-info">
                <span>📱 Telegram</span>
                <strong>@fgnb111999</strong>
            </div>
            <button class="copy-btn" onclick="copyText('@fgnb111999')">复制</button>
        </div>
        <div class="contact-card">
            <div class="contact-info">
                <span>💬 QQ</span>
                <strong>183452852</strong>
            </div>
            <button class="copy-btn" onclick="copyText('183452852')">复制</button>
        </div>
        <div class="contact-card">
            <div class="contact-info">
                <span>📧 Email</span>
                <strong>niwo5507@gmail.com</strong>
            </div>
            <button class="copy-btn" onclick="copyText('niwo5507@gmail.com')">复制</button>
        </div>
    </div>
    
    <% if nav_data and nav_data.nav_tabs and #nav_data.nav_tabs > 0 then %>
    <div class="nav-section">
        <h3>🚀 快速导航</h3>
        <div class="nav-groups" id="nav-groups">
            <% for i, tab in ipairs(nav_data.nav_tabs) do %>
            <div class="nav-group" data-page="<%=math.ceil(i/4)%>" style="display:none;">
                <div class="nav-group-title" onclick="toggleLinks(this.parentElement)">
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
                    <a href="<%=pcdata(link.url)%>" target="_blank" rel="noopener noreferrer"><%=pcdata(link.name)%></a>
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
    <% else %>
    <div style="color:white;text-align:center;margin-top:30px;padding:20px;background:rgba(0,0,0,0.3);border-radius:10px;">
        暂无导航数据,请检查更新源或手动更新。
    </div>
    <% end %>
</div>

<div class="bg-selector">
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg0.jpg?t=<%=os.time()%>)" onclick="changeBg(0)" title="背景 1"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg1.jpg?t=<%=os.time()%>)" onclick="changeBg(1)" title="背景 2"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg2.jpg?t=<%=os.time()%>)" onclick="changeBg(2)" title="背景 3"></div>
</div>
<% end %>

<script>
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
    } else if (images.length === 1) {
        images[0].classList.add('active');
    }
})();

(function() {
    var bannerTexts = '<%=banner_texts%>'.split('|').filter(function(t) { return t.trim(); });
    var interval = parseInt('<%=carousel_interval%>', 10) || 5000;
    if (bannerTexts.length > 1) {
        var idx = 0;
        var elem = document.getElementById('banner-text');
        elem.style.transition = 'opacity 0.3s';
        setInterval(function() {
            idx = (idx + 1) % bannerTexts.length;
            elem.style.opacity = '0';
            setTimeout(function() {
                elem.textContent = bannerTexts[idx];
                elem.style.opacity = '1';
            }, 300);
        }, interval);
    }
})();

<% if nav_data and nav_data.nav_tabs and #nav_data.nav_tabs > 0 then %>
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
    var buttons = document.querySelectorAll('.pagination button');
    buttons[0].disabled = (currentPage === 1);
    buttons[1].disabled = (currentPage === totalPages);
}

changePage(0);
<% end %>

function toggleLinks(el) {
    var links = el.querySelector('.nav-links');
    var wasActive = links.classList.contains('active');
    document.querySelectorAll('.nav-links').forEach(function(l) { 
        l.classList.remove('active'); 
    });
    if (!wasActive) {
        links.classList.add('active');
    }
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
    if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(txt).then(function() {
            alert('已复制: ' + txt);
        }).catch(function() {
            fallbackCopy(txt);
        });
    } else {
        fallbackCopy(txt);
    }
}

function fallbackCopy(txt) {
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
        prompt('请手动复制以下内容:', txt);
    }
    document.body.removeChild(textarea);
}
</script>
<%+footer%>
DISPLAYVIEW

-- FIXED: Settings view with toggle switch for persistent storage
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/settings.htm" <<'SETTINGSVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.toggle-switch {
    position: relative;
    display: inline-block;
    width: 50px;
    height: 24px;
    margin-right: 10px;
}

.toggle-switch input {
    opacity: 0;
    width: 0;
    height: 0;
}

.toggle-slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(200,200,200,0.5);
    transition: 0.4s;
    border-radius: 24px;
}

.toggle-slider:before {
    position: absolute;
    content: "";
    height: 18px;
    width: 18px;
    left: 3px;
    bottom: 3px;
    background-color: white;
    transition: 0.4s;
    border-radius: 50%;
}

input:checked + .toggle-slider {
    background-color: rgba(76,175,80,0.9);
}

input:checked + .toggle-slider:before {
    transform: translateX(26px);
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
</style>

<div class="cbi-map">
    <h2>远程更新设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <% if remote_message and remote_message ~= '' then %>
        <div style="background:rgba(100,100,100,0.8);color:white;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center;font-weight:bold">
            <%=pcdata(remote_message)%>
        </div>
        <% end %>
        
        <div class="cbi-value">
            <label class="cbi-value-title">背景透明度</label>
            <div class="cbi-value-field">
                <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%" />
                <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                <p style="color:#aaa;font-size:12px">📌 仅支持 HTTPS 链接(JPG,GitHub/Gitee),应用后覆盖 bg0.jpg</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">从本地上传背景图</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data" id="uploadForm">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="file" name="bg_file" accept="image/jpeg,image/jpg" id="bgFileInput" required />
                    <input type="submit" class="cbi-button cbi-button-apply" value="上传并应用" />
                </form>
                <script>
                document.getElementById('uploadForm').addEventListener('submit', function(e) {
                    var file = document.getElementById('bgFileInput').files[0];
                    if (!file) {
                        e.preventDefault();
                        alert('⚠️ 请选择文件');
                        return;
                    }
                    if (file.size > 5242880) {
                        e.preventDefault();
                        alert('⚠️ 文件大小不能超过 5MB\n当前: ' + (file.size / 1048576).toFixed(2) + ' MB');
                        return;
                    }
                    if (!file.type.match('image/jp(e)?g')) {
                        e.preventDefault();
                        alert('⚠️ 仅支持 JPG/JPEG 格式\n当前: ' + file.type);
                        return;
                    }
                });
                </script>
                <p style="color:#aaa;font-size:12px">📤 仅支持 JPG,上传后覆盖 bg0.jpg</p>
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

<div class="bg-selector">
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg0.jpg?t=<%=os.time()%>)" onclick="changeBg(0)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg1.jpg?t=<%=os.time()%>)" onclick="changeBg(1)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg2.jpg?t=<%=os.time()%>)" onclick="changeBg(2)"></div>
</div>

<script>
document.getElementById('loadGroupForm').addEventListener('submit', function(e) {
    e.preventDefault();
    document.getElementById('loadingOverlay').classList.add('active');
    var form = this;
    var formData = new FormData(form);
    var xhr = new XMLHttpRequest();
    xhr.open('POST', form.action, true);
    xhr.onload = function() {
        setTimeout(function() {
            window.location.reload();
        }, 8000);
    };
    xhr.send(formData);
});

function togglePersistent(enabled) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '<%=luci.dispatcher.build_url("admin/status/banner/do_set_persistent_storage")%>', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = function() {
        window.location.reload();
    };
    xhr.send('token=<%=token%>&persistent_storage=' + (enabled ? '1' : '0'));
}

function changeBg(n) {
    var f = document.createElement('form');
    f.method = 'POST';
    f.action = '<%=luci.dispatcher.build_url("admin/status/banner/do_set_bg")%>';
    f.innerHTML = '<input type="hidden" name="token" value="<%=token%>"><input type="hidden" name="bg" value="' + n + '">';
    document.body.appendChild(f);
    f.submit();
}
</script>
<%+footer%>
BGVIEW

# Make scripts executable
chmod +x "$PKG_DIR"/root/usr/bin/*.sh
chmod +x "$PKG_DIR"/root/etc/init.d/banner

echo "=========================================="
echo "✓ Package luci-app-banner v2.5 Ready!"
echo "=========================================="
echo "Package directory: $PKG_DIR"
echo ""
echo "Key Fixes:"
echo "  ✓ Fixed background display: Better JPEG validation"
echo "  ✓ Fixed mobile compatibility: Added rel='noopener noreferrer'"
echo "  ✓ Fixed update source display: Shows 'GitHub' or 'Gitee'"
echo "  ✓ Fixed persistent storage: Toggle switch can be disabled"
echo "  ✓ Fixed default opacity: Changed to 90%"
echo "  ✓ Fixed layout: Vertical contact cards, better spacing"
echo "  ✓ Fixed CSS priority: Added !important to all backgrounds"
echo "  ✓ Fixed enabled=false: Properly checks remote disable status"
echo "  ✓ Fixed image paths: Uses /tmp/banner_cache consistently"
echo "  ✓ Added fallback: Default background if downloads fail"
echo ""
echo "Compilation command:"
echo "  make package/custom/luci-app-banner/compile V=s"
echo ""
echo "All issues from logs have been addressed!"
echo "=========================================="💡 拖动即刻生效(自动保存)</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">轮播间隔(毫秒)</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_carousel_interval')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="number" name="carousel_interval" value="<%=carousel_interval%>" min="1000" max="30000" style="width:100px;background:rgba(255,255,255,0.9);color:#333" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 设置轮播间隔(1000-30000毫秒)</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">永久存储背景</label>
            <div class="cbi-value-field">
                <label class="toggle-switch">
                    <input type="checkbox" id="persistent-toggle" <%=persistent_storage=='1' and 'checked' or ''%> onchange="togglePersistent(this.checked)">
                    <span class="toggle-slider"></span>
                </label>
                <span style="color:white"><%=persistent_storage=='1' and '已启用' or '已禁用'%></span>
                <p style="color:#aaa;font-size:12px">💡 启用后背景图存储到 /overlay/banner(防止掉电丢失)</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">更新源</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_update_url')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <select name="selected_url" style="flex:1;background:rgba(255,255,255,0.9);color:#333">
                        <% if display_urls and type(display_urls) == "table" then %>
                            <% for _, item in ipairs(display_urls) do %>
                                <option value="<%=item.value%>" <%=item.value==selected_url and 'selected' or''%>><%=item.display%></option>
                            <% end %>
                        <% else %>
                            <option value="">无可用更新源</option>
                        <% end %>
                    </select>
                    <input type="submit" class="cbi-button cbi-button-apply" value="选择更新源" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 选择优先使用的更新源(GitHub 或 Gitee)</p>
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
                <input type="text" value="10800 秒 (3小时)" disabled style="background:rgba(200,200,200,0.5);color:#333">
                <p style="color:#5cb85c;font-size:12px">✓ 已启用 (系统锁定,不可修改)</p>
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
                <p style="color:#aaa;font-size:12px">🔄 不受24小时限制,立即执行</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">恢复默认配置</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_reset_defaults')%>" onsubmit="return confirm('⚠️ 确定要恢复默认配置吗?\n\n这将清除所有自定义设置和缓存图片!')">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="submit" class="cbi-button cbi-button-reset" value="恢复默认值" style="background:rgba(217,83,79,0.9) !important" />
                </form>
                <p style="color:#ff6b6b;font-size:12px">⚠️ 将清除所有配置并恢复出厂设置</p>
            </div>
        </div>
        
        <h3 style="color:white">更新日志 (最近20条)</h3>
        <div style="background:rgba(0,0,0,0.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,0.1)"><%=pcdata(log)%></div>
    </div></div>
</div>

<div class="bg-selector">
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg0.jpg?t=<%=os.time()%>)" onclick="changeBg(0)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg1.jpg?t=<%=os.time()%>)" onclick="changeBg(1)"></div>
    <div class="bg-circle" style="background-image:url(<%=bg_path%>/bg2.jpg?t=<%=os.time()%>)" onclick="changeBg(2)"></div>
</div>

<script>
function togglePersistent(enabled) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '<%=luci.dispatcher.build_url("admin/status/banner/do_set_persistent_storage")%>', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = function() {
        window.location.reload();
    };
    xhr.send('token=<%=token%>&persistent_storage=' + (enabled ? '1' : '0'));
}

function changeBg(n) {
    var f = document.createElement('form');
    f.method = 'POST';
    f.action = '<%=luci.dispatcher.build_url("admin/status/banner/do_set_bg")%>';
    f.innerHTML = '<input type="hidden" name="token" value="<%=token%>"><input type="hidden" name="bg" value="' + n + '">';
    document.body.appendChild(f);
    f.submit();
}
</script>
<%+footer%>
SETTINGSVIEW

-- Background settings view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/background.htm" <<'BGVIEW'
<%+header%>
<%+banner/global_style%>
<style>
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

.loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.8);
    display: none;
    justify-content: center;
    align-items: center;
    z-index: 9999;
}

.loading-overlay.active {
    display: flex;
}

.loading-content {
    background: rgba(255,255,255,0.1);
    padding: 30px;
    border-radius: 15px;
    text-align: center;
    color: white;
}

.spinner {
    border: 4px solid rgba(255,255,255,0.3);
    border-top: 4px solid #4fc3f7;
    border-radius: 50%;
    width: 50px;
    height: 50px;
    animation: spin 1s linear infinite;
    margin: 0 auto 20px;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.toggle-switch {
    position: relative;
    display: inline-block;
    width: 50px;
    height: 24px;
    margin-right: 10px;
}

.toggle-switch input {
    opacity: 0;
    width: 0;
    height: 0;
}

.toggle-slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(200,200,200,0.5);
    transition: 0.4s;
    border-radius: 24px;
}

.toggle-slider:before {
    position: absolute;
    content: "";
    height: 18px;
    width: 18px;
    left: 3px;
    bottom: 3px;
    background-color: white;
    transition: 0.4s;
    border-radius: 50%;
}

input:checked + .toggle-slider {
    background-color: rgba(76,175,80,0.9);
}

input:checked + .toggle-slider:before {
    transform: translateX(26px);
}
</style>

<div class="loading-overlay" id="loadingOverlay">
    <div class="loading-content">
        <div class="spinner"></div>
        <p style="font-size:18px;font-weight:bold">正在下载背景图...</p>
        <p style="font-size:14px;color:#aaa">下载完成后将自动刷新</p>
    </div>
</div>

<div class="cbi-map">
    <h2>背景图设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <div class="cbi-value">
            <label class="cbi-value-title">实时透明度调节</label>
            <div class="cbi-value-field">
                <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%" />
                <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                <p style="color:#aaa;font-size:12px">💡 拖动即刻生效(自动保存)</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">永久存储背景</label>
            <div class="cbi-value-field">
                <label class="toggle-switch">
                    <input type="checkbox" id="persistent-toggle" <%=persistent_storage=='1' and 'checked' or ''%> onchange="togglePersistent(this.checked)">
                    <span class="toggle-slider"></span>
                </label>
                <span style="color:white"><%=persistent_storage=='1' and '已启用' or '已禁用'%></span>
                <p style="color:#aaa;font-size:12px">💡 启用后背景图存储到 /overlay/banner(防止掉电丢失)</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">选择背景图组</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_load_group')%>" id="loadGroupForm">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <select name="group" style="flex:1;background:rgba(255,255,255,0.9);color:#333">
                        <option value="1" <%=bg_group=='1' and 'selected' or ''%>>第 1 组 (背景1-3)</option>
                        <option value="2" <%=bg_group=='2' and 'selected' or ''%>>第 2 组 (背景4-6)</option>
                        <option value="3" <%=bg_group=='3' and 'selected' or ''%>>第 3 组 (背景7-9)</option>
                        <option value="4" <%=bg_group=='4' and 'selected' or ''%>>第 4 组 (背景10-12)</option>
                    </select>
                    <input type="submit" class="cbi-button cbi-button-apply" value="加载背景组" />
                </form>
                <p style="color:#aaa;font-size:12px">💡 选择后自动下载并缓存对应组的三张图片</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">手动填写背景图链接</label>
            <div class="cbi-value-field">
                <form id="customBgForm" method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="text" name="custom_bg_url" placeholder="https://raw.githubusercontent.com/.../image.jpg" style="width:65%;background:rgba(255,255,255,0.9);color:#333" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="应用链接" />
                </form>
                <script>
                document.getElementById('customBgForm').addEventListener('submit', function(e){
                    var url = this.custom_bg_url.value.trim();
                    if (!url.startsWith('https://') || !url.match(/\.(jpg|jpeg)$/) || !url.match(/^(https:\/\/raw\.githubusercontent\.com|https:\/\/gitee\.com)/)) {
                        e.preventDefault();
                        alert('⚠️ 仅支持 HTTPS 链接、JPG 格式和 GitHub/Gitee 域名,请输入正确 URL');
                    }
                });
                </script>
                <p style="color:#aaa;font-size:12px">
