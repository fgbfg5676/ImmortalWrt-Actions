
#!/bin/bash
# OpenWrt Banner Plugin - Final Optimized Version v2.7
# All potential issues addressed for maximum reliability and compatibility.
# This script is provided in three parts for completeness. Please concatenate them.

set -e

echo "=========================================="
echo "OpenWrt Banner Plugin v2.7 - Final Optimized"
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

# 安全性檢查：確保 PKG_DIR 是一個有效且安全的路徑
if [ -z "$PKG_DIR" ]; then
    echo "❌ 錯誤：目標目錄變數為空，已終止操作。"
    exit 1
fi

if command -v realpath >/dev/null 2>&1; then
    # 使用 -m 選項確保即使路徑不存在也能正常工作
    ABS_PKG_DIR=$(realpath -m "$PKG_DIR")
else
    # 作為最終備用方案，如果連 realpath 都沒有，我們就手動處理
    echo "警告：系統中未找到 realpath 命令，路徑安全檢查可能不夠完備。"
    ABS_PKG_DIR="$PKG_DIR" # 直接使用，並依賴後續檢查
fi

case "$ABS_PKG_DIR" in
    "/"|"/root"|"/root/"|"$HOME"|"$HOME/"|"/etc"|"/etc/"|"/usr"|"/usr/")
        echo "❌ 錯誤：目標目錄指向了危險的系統路徑 ('$ABS_PKG_DIR')，已終止操作。"
        exit 1
        ;;
esac

if echo "$PKG_DIR" | grep -q '/\.\./'; then
    echo "❌ 錯誤：目標目錄包含非法的路徑穿越符 '..' ('$PKG_DIR')，已終止操作。"
    exit 1
fi

# 安全檢查通過，執行刪除
rm -rf "$PKG_DIR"

mkdir -p "$PKG_DIR"/root/{etc/{config,init.d,cron.d},usr/{bin,share/banner,lib/lua/luci/{controller,view/banner}},www/luci-static/banner,overlay/banner}

# 下载离线背景图
OFFLINE_BG="$PKG_DIR/root/www/luci-static/banner/bg0.jpg"
mkdir -p "$(dirname "$OFFLINE_BG")"
mkdir -p "$PKG_DIR/root/usr/share/banner"

echo "Downloading offline background image..."
if ! curl -fLsS https://github.com/fgbfg5676/ImmortalWrt-Actions/raw/main/bg0.jpg -o "$OFFLINE_BG"; then
    echo "[ERROR] Failed to download offline background image!"
    exit 1
fi
# 同时复制到 /usr/share/banner 供 init 脚本使用
cp "$OFFLINE_BG" "$PKG_DIR/root/usr/share/banner/bg0.jpg"
echo "Offline background image downloaded successfully."


# Create Makefile
echo "[2/3] Creating Makefile..."
cat > "$PKG_DIR/Makefile" <<'MAKEFILE'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-banner
PKG_VERSION:=2.7
PKG_RELEASE:=1
PKG_FLAGS:=nonshared

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
  A highly optimized LuCI web interface for OpenWrt banner navigation.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/share/banner
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
	mkdir -p /www/luci-static/banner /overlay/banner 2>/dev/null
	/etc/init.d/banner enable
	/etc/init.d/banner start
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
MAKEFILE
echo "调试：Makefile 生成成功，大小 $(wc -c < "$PKG_DIR/Makefile") 字节"
# UCI Configuration
cat > "$PKG_DIR/root/etc/config/banner" <<'UCICONF'
config banner 'banner'
	option text '🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行'
	option color 'rainbow'
	option opacity '50' # 0-100
	option carousel_interval '5000' # 1000-30000 (ms)
	option bg_group '1' # 1-4
	option bg_enabled '1' # 0 or 1
	option persistent_storage '0' # 0 or 1
	option current_bg '0' # 0-2
	list update_urls 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	list update_urls 'https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json'
	option selected_url 'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json'
	option update_interval '10800' # seconds
	option last_update '0'
	option banner_texts ''
	option remote_message ''
	option cache_dir '/tmp/banner_cache' # Cache directory
	option web_dir '/www/luci-static/banner' # Web directory
	option persistent_dir '/overlay/banner' # Persistent storage directory
	option curl_timeout '15' # seconds
	option wait_timeout '5' # seconds
	option cleanup_age '3' # days
	option restart_delay '15' # seconds
	option contact_email 'example@email.com'
	option contact_telegram '@fgnb111999'
	option contact_qq '183452852'
UCICONF

# 創建一個全局配置文件，用於存儲可配置的變數
mkdir -p "$PKG_DIR/root/usr/share/banner"
cat > "$PKG_DIR/root/usr/share/banner/config.sh" <<'CONFIGSH'
#!/bin/sh
# Banner 全局配置

# 預設文件大小限制 (3MB)
MAX_FILE_SIZE=3145728

# 預設日誌文件
LOG_FILE="/tmp/banner_update.log"

# 預設快取目錄
CACHE_DIR=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")

# 預設背景圖存儲路徑
DEFAULT_BG_PATH=$(uci -q get banner.banner.web_dir || echo "/www/luci-static/banner")
PERSISTENT_BG_PATH=$(uci -q get banner.banner.persistent_dir || echo "/overlay/banner")
CONFIGSH

# Cache cleaner script
cat > "$PKG_DIR/root/usr/bin/banner_cache_cleaner.sh" <<'CLEANER'
#!/bin/sh
LOG="/tmp/banner_update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    if [ -s "$LOG" ] && [ $(wc -c < "$LOG") -gt 51200 ]; then
        mv "$LOG" "$LOG.bak"; tail -n 50 "$LOG.bak" > "$LOG"; rm -f "$LOG.bak"
    fi
}

log "========== Cache Cleanup Started =========="
CACHE_DIR=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")
CLEANUP_AGE=$(uci -q get banner.banner.cleanup_age || echo 3)
if [ ! -d "$CACHE_DIR" ]; then
    log "[!] Cache directory $CACHE_DIR not found, skipping cleanup."
    exit 0
fi
find "$CACHE_DIR" -type f -name '*.jpg' -mtime +"$CLEANUP_AGE" -delete
log "[√] Removed JPEG files older than $CLEANUP_AGE days from $CACHE_DIR"
CLEANER


#--- 用這段新程式碼替換舊的 banner_manual_update.sh 區塊 ---
cat > "$PKG_DIR/root/usr/bin/banner_manual_update.sh" <<'MANUALUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")

log() {
    local msg="$1"; msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL Redacted]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP Redacted]|g' );
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="/tmp/banner_update.log"
    echo "[$timestamp] $msg" >> "$log_file"
    # 检查日志文件大小，超过 50KB (51200 字节) 时保留最后 50 行
    if [ -s "$log_file" ] && [ $(wc -c < "$log_file") -gt 51200 ]; then
        mv "$log_file" "$log_file.bak"
        tail -n 50 "$log_file.bak" > "$log_file"
        rm -f "$log_file.bak"
        echo "[$timestamp] 日志文件 $log_file 已清理，保留最后 50 行" >> "$log_file"
    fi
}
check_lock() {
    local lock_file="$1"; local max_age="$2";
    if [ -f "$lock_file" ]; then
        local lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || date +%s); local current_time=$(date +%s); local age=$((current_time - lock_time));
        if [ $age -gt $max_age ]; then
            log "Clearing stale lock (age: ${age}s): $lock_file"; rm -f "$lock_file";
        else
            log "Task blocked by lock (age: ${age}s): $lock_file"; return 1;
        fi
    fi;
    touch "$lock_file"; return 0;
}

if [ ! -f "/etc/config/banner" ]; then
    log "[×] UCI 配置文件 /etc/config/banner 不存在，创建默认配置"
    cat > /etc/config/banner <<'EOF'
config banner 'banner'
    option text '默认横幅文本'
    option color 'white'
    option opacity '50'
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
EOF
fi

mkdir -p "$CACHE"
if ! command -v uci >/dev/null 2>&1; then
    log "[×] UCI command not found. This script requires UCI to function. Exiting."
    exit 0
fi

MANUAL_LOCK="/tmp/banner_manual_update.lock"
if ! check_lock "$MANUAL_LOCK" 60; then
    exit 1
fi
trap "rm -f $MANUAL_LOCK" EXIT

AUTO_LOCK="/tmp/banner_auto_update.lock"
if [ -f "$AUTO_LOCK" ]; then
    log "Manual update overriding auto-update lock."
    rm -f "$AUTO_LOCK"
fi

log "========== Manual Update Started =========="

validate_url() {
    case "$1" in
        http://*|https://* ) return 0;;
        *) log "[×] Invalid URL format: $1"; return 1;;
    esac
}

URLS=$(uci -q get banner.banner.update_urls | tr ' ' '\n')
SELECTED_URL=$(uci -q get banner.banner.selected_url)
SUCCESS=0
CURL_TIMEOUT=$(uci -q get banner.banner.curl_timeout || echo 15)

if [ -n "$SELECTED_URL" ] && validate_url "$SELECTED_URL"; then
    for i in 1 2 3; do
        log "Attempt $i/3 with selected URL: $SELECTED_URL"
        curl -sL --max-time "$CURL_TIMEOUT" "$SELECTED_URL" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ]; then
            log "[√] Selected URL download successful."
            SUCCESS=1
            break
        fi
        rm -f "$CACHE/banner_new.json"
        sleep 2
    done
fi

if [ $SUCCESS -eq 0 ]; then
    for url in $URLS; do
        if [ "$url" != "$SELECTED_URL" ] && validate_url "$url"; then
            for i in 1 2 3; do
                log "Attempt $i/3 with fallback URL: $url"
                curl -sL --max-time "$CURL_TIMEOUT" "$url" -o "$CACHE/banner_new.json" 2>/dev/null
                if [ -s "$CACHE/banner_new.json" ]; then
                    log "[√] Fallback URL download successful. Updating selected URL."
                    uci set banner.banner.selected_url="$url"
                    uci commit banner
                    SUCCESS=1
                    break 2
                fi
                rm -f "$CACHE/banner_new.json"
                sleep 2
            done
        fi
    done
fi
if ! command -v jq >/dev/null 2>&1; then
    log "[×] jq not found, skipping JSON parsing."
    exit 0
fi
if [ $SUCCESS -eq 1 ] && [ -s "$CACHE/banner_new.json" ]; then
    if ! jq empty "$CACHE/banner_new.json" >/dev/null 2>&1; then
        log "[⚠️] Invalid JSON detected. Attempting to perform partial recovery."
        jq "{
            text: .text // "內容加載失敗",
            color: .color // "white",
            banner_texts: .banner_texts // [],
            nav_tabs: .nav_tabs // [],
            contact_info: .contact_info // {},
            enabled: .enabled // "true"
        }" "$CACHE/banner_new.json" > "$CACHE/banner_partial.json"

        if [ -s "$CACHE/banner_partial.json" ] && jq empty "$CACHE/banner_partial.json" >/dev/null 2>&1; then
            mv "$CACHE/banner_partial.json" "$CACHE/banner_new.json"
            log "[✓] Partial data recovery successful. Key fields have been restored."
        else
            log "[×] Partial data recovery failed. Discarding invalid JSON."
            rm -f "$CACHE/banner_new.json" "$CACHE/banner_partial.json"
            SUCCESS=0
        fi
    fi
fi

if [ $SUCCESS -eq 1 ] && [ -s "$CACHE/banner_new.json" ]; then
    ENABLED=$(jq -r '.enabled // "true"' "$CACHE/banner_new.json")
    log "[DEBUG] Remote control - enabled field value: '$ENABLED'"
    if [ "$ENABLED" = "false" ] || [ "$ENABLED" = "0" ]; then
        MSG=$(jq -r '.disable_message // "服务已被管理员远程关闭"' "$CACHE/banner_new.json")
        uci set banner.banner.bg_enabled='0'
        uci set banner.banner.remote_message="$MSG"
        uci commit banner
        log "[!] Service remotely disabled. Reason: $MSG"
        log "[DEBUG] bg_enabled set to: $(uci get banner.banner.bg_enabled)"
        rm -f "$CACHE/banner_new.json"
        exit 0
    else
        TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
        if [ -n "$TEXT" ]; then
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            uci set banner.banner.text="$TEXT"
            # 更新联系方式（只在有新值时更新，否则保留现有值）
    CONTACT_EMAIL=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.email' 2>/dev/null)
    CONTACT_TG=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.telegram' 2>/dev/null)
    CONTACT_QQ=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.qq' 2>/dev/null)
    
    if [ -n "$CONTACT_EMAIL" ]; then
        uci set banner.banner.contact_email="$CONTACT_EMAIL"
    fi
    if [ -n "$CONTACT_TG" ]; then
        uci set banner.banner.contact_telegram="$CONTACT_TG"
    fi
    if [ -n "$CONTACT_QQ" ]; then
        uci set banner.banner.contact_qq="$CONTACT_QQ"
    fi
            uci set banner.banner.color="$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null || echo 'rainbow')"
            uci set banner.banner.banner_texts="$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')"
            uci set banner.banner.bg_enabled='1'
            uci delete banner.banner.remote_message >/dev/null 2>&1
            uci set banner.banner.last_update=$(date +%s)
            uci commit banner
            log "[√] Manual update applied successfully."
        else
            log "[×] Update failed: Invalid JSON content (missing 'text' field)."
            rm -f "$CACHE/banner_new.json"
        fi
    fi
else
    log "[×] Update failed: All sources are unreachable or provided invalid data."
    if [ ! -f "$CACHE/nav_data.json" ]; then
        log "[!] No local cache found. Using built-in default JSON data."
        DEFAULT_JSON_PATH=$(grep -oE '/default/banner_default.json' /usr/lib/ipkg/info/luci-app-banner.list | sed 's|/default/banner_default.json||' | head -n1)/default/banner_default.json
        if [ -f "$DEFAULT_JSON_PATH" ]; then
            cp "$DEFAULT_JSON_PATH" "$CACHE/nav_data.json"
        fi
    fi
fi
MANUALUPDATE


#--- 用這段新程式碼替換舊的 auto_update 腳本 ---
cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'AUTOUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"

log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG"  # "$LOG" 已定义为 "/tmp/banner_update.log"
    msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL Redacted]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP Redacted]|g')
    echo "[$timestamp] $msg" >> "$log_file"
    if [ -s "$log_file" ] && [ $(wc -c < "$log_file") -gt 51200 ]; then
        mv "$log_file" "$log_file.bak"
        tail -n 50 "$log_file.bak" > "$log_file"
        rm -f "$log_file.bak"
        echo "[$timestamp] 日志文件 $log_file 已清理，保留最后 50 行" >> "$log_file"
    fi
}
check_lock() {
    local lock_file="$1"; local max_age="$2";
    if [ -f "$lock_file" ]; then
        local lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || date +%s); local current_time=$(date +%s); local age=$((current_time - lock_time));
        if [ $age -gt $max_age ]; then
            log "Clearing stale lock (age: ${age}s): $lock_file"; rm -f "$lock_file";
        else
            log "Task blocked by lock (age: ${age}s): $lock_file"; return 1;
        fi
    fi;
    touch "$lock_file"; return 0;
}

if ! command -v uci >/dev/null 2>&1; then
    log "[×] UCI command not found in auto_update script. Exiting."
    exit 0
fi

LOCK="/tmp/banner_auto_update.lock"
if ! check_lock "$LOCK" 60; then
    exit 1
fi
trap "rm -f $LOCK" EXIT

LAST_UPDATE=$(uci -q get banner.banner.last_update || echo 0)
CURRENT_TIME=$(date +%s)
INTERVAL=$(uci -q get banner.banner.update_interval || echo 10800)

if [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$INTERVAL" ]; then
    log "[√] 未到更新时间，跳过自动更新"
    exit 0
fi

log "========== Auto Update Started =========="
/usr/bin/banner_manual_update.sh
if [ $? -ne 0 ]; then
    log "[×] 自动更新失败，查看 /tmp/banner_update.log 获取详情"
fi
AUTOUPDATE

cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}

# 首先加载配置文件（如果存在）
if [ -f "/usr/share/banner/config.sh" ]; then
    . /usr/share/banner/config.sh
else
    # Fallback defaults
    MAX_FILE_SIZE=3145728
    CACHE_DIR="/tmp/banner_cache"
    DEFAULT_BG_PATH="/www/luci-static/banner"
    PERSISTENT_BG_PATH="/overlay/banner"
fi

# 定义变量
LOG="/tmp/banner_bg.log"
CACHE="$CACHE_DIR"
WEB="$DEFAULT_BG_PATH"
PERSISTENT="$PERSISTENT_BG_PATH"

# 添加日志函数
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG"  # "$LOG" 已定义为 "/tmp/banner_bg.log"
    echo "[$timestamp] $msg" >> "$log_file"
    if [ -s "$log_file" ] && [ $(wc -c < "$log_file") -gt 51200 ]; then
        mv "$log_file" "$log_file.bak"
        tail -n 50 "$log_file.bak" > "$log_file"
        rm -f "$log_file.bak"
        echo "[$timestamp] 日志文件 $log_file 已清理，保留最后 50 行" >> "$log_file"
    fi
}

# 添加锁检查函数
check_lock() {
    local lock_file="$1"
    local max_age="$2"
    if [ -f "$lock_file" ]; then
        local lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || date +%s)
        local current_time=$(date +%s)
        local age=$((current_time - lock_time))
        if [ $age -gt $max_age ]; then
            log "Clearing stale lock (age: ${age}s): $lock_file"
            rm -f "$lock_file"
        else
            log "Task blocked by lock (age: ${age}s): $lock_file"
            return 1
        fi
    fi
    touch "$lock_file"
    return 0
}

# 动态决定存储路径
if ! command -v uci >/dev/null 2>&1; then
    DEST="$WEB"
else
    # 讀取 UCI 配置，如果不存在，則使用 config.sh 的預設值
    [ "$(uci -q get banner.banner.persistent_storage)" = "1" ] && DEST="$PERSISTENT" || DEST="$WEB"
fi
mkdir -p "$CACHE" "$WEB" "$PERSISTENT"

JSON="$CACHE/nav_data.json"
WAIT_COUNT=0
while [ ! -f "$JSON" ] && [ $WAIT_COUNT -lt 5 ]; do
    log "Waiting for nav_data.json... ($WAIT_COUNT/5)"
    sleep 1; WAIT_COUNT=$((WAIT_COUNT + 1))
done
#--- 用這段新程式碼替換舊的 JSON 檢查 ---
if [ ! -f "$JSON" ]; then
    log "[!] nav_data.json not found, will use cached backgrounds if available."
    # 尝试使用已缓存的背景图
    for i in 0 1 2; do
        if [ -f "$DEST/bg${i}.jpg" ]; then
            cp "$DEST/bg${i}.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
            log "[i] Using cached bg${i}.jpg as fallback"
            exit 0
        fi
    done
    exit 1
fi

LOCK_FILE="/tmp/banner_bg_loader.lock"
if ! check_lock "$LOCK_FILE" 60; then
    exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT

validate_url() {
    case "$1" in
        http://*|https://* ) return 0;;
        *) log "[×] Invalid URL format: $1"; return 1;;
    esac
}
# 当前的验证函数太严格，建议改为：
validate_jpeg() {
    [ ! -s "$1" ] && return 1
    # 只检查文件头，不依赖 file 命令
    local magic=$(od -An -t x1 -N 3 "$1" 2>/dev/null | tr -d ' \n')
    [ "$magic" = "ffd8ff" ] && return 0
    return 1
}

log "Loading background group ${BG_GROUP}..."
echo "loading" > "$CACHE/bg_loading"
rm -f "$CACHE/bg_complete"

START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))
if ! jq empty "$JSON" 2>/dev/null; then
    log "[×] JSON format error in nav_data.json"; rm -f "$CACHE/bg_loading"; exit 1
fi

rm -f "$DEST"/bg{0,1,2}.jpg
if [ "$(uci -q get banner.banner.persistent_storage)" = "1" ]; then
    rm -f "$WEB"/bg{0,1,2}.jpg
fi

# 從 UCI 或全局配置讀取文件大小限制
MAX_SIZE=$(uci -q get banner.banner.max_file_size || echo "$MAX_FILE_SIZE")
log "Using max file size limit: $MAX_SIZE bytes."

DOWNLOAD_SUCCESS=0
for i in 0 1 2; do
    KEY="background_$((START_IDX + i))"
    URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
    if [ -n "$URL" ] && validate_url "$URL"; then
        log "  Downloading image for bg${i}.jpg..."
        TMPFILE="$DEST/bg$i.tmp"
        
  # 简化下载逻辑，不依赖 --max-filesize
        log "  Attempting download from: $(echo "$URL" | sed 's/https:\/\///')"
curl -sL --max-time 20 -w "HTTP_CODE:%{http_code}\n" "$URL" -o "$TMPFILE" 2>&1 | tee -a "$LOG"

# 检查 HTTP 响应
HTTP_CODE=$(tail -n 1 "$LOG" | grep -oP 'HTTP_CODE:\K\d+')
if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "200" ]; then
    log "  [×] HTTP error: $HTTP_CODE"
    rm -f "$TMPFILE"
    continue
fi
        
        # 检查下载是否成功
        if [ ! -s "$TMPFILE" ]; then
            log "  [×] Download failed for $URL"
            rm -f "$TMPFILE"
            continue
        fi
        
        # 手动检查文件大小
        FILE_SIZE=$(stat -c %s "$TMPFILE" 2>/dev/null || wc -c < "$TMPFILE" 2>/dev/null || echo 999999999)
        if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
            log "  [×] File too large: $FILE_SIZE bytes (limit: $MAX_SIZE)"
            rm -f "$TMPFILE"
            continue
        fi

        # 检查文件是否为 HTML（被重定向到登录页）
if head -n 1 "$TMPFILE" 2>/dev/null | grep -q "<!DOCTYPE\|<html"; then
    log "  [×] Downloaded HTML instead of image (possible redirect/block)"
    rm -f "$TMPFILE"
    continue
fi
        if validate_jpeg "$TMPFILE"; then
            mv "$TMPFILE" "$DEST/bg$i.jpg"
            chmod 644 "$DEST/bg$i.jpg"
            log "  [√] bg${i}.jpg downloaded and validated successfully."
            DOWNLOAD_SUCCESS=1
            if [ "$(uci -q get banner.banner.persistent_storage)" = "1" ]; then
                cp "$DEST/bg$i.jpg" "$WEB/bg$i.jpg" 2>/dev/null
            fi
            if [ $i -eq 0 ]; then
                cp "$DEST/bg$i.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
            fi
        else
            log "  [×] Downloaded file for bg${i}.jpg is invalid or not a JPEG."
            rm -f "$TMPFILE"
        fi
    else
        log "  [×] No valid URL found for ${KEY}."
    fi
done

if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "[!] No images were downloaded for group ${BG_GROUP}. Keeping existing cached images."
    # 不做任何操作,保留现有的缓存图片
fi

if [ ! -s "$CACHE/current_bg.jpg" ]; then
    log "[!] current_bg.jpg is missing. Attempting to restore from cached backgrounds."
    # 随机选择一张缓存的背景
    for i in $(shuf -i 0-2 2>/dev/null || echo "0 1 2"); do
        if [ -s "$DEST/bg${i}.jpg" ]; then
            cp "$DEST/bg${i}.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
            log "[i] Restored current_bg.jpg from bg${i}.jpg"
            break
        fi
    done
fi

log "[Complete] Background loading for group ${BG_GROUP} finished."
rm -f "$CACHE/bg_loading"
echo "complete" > "$CACHE/bg_complete"
BGLOADER

# Cron jobs
cat > "$PKG_DIR/root/etc/cron.d/banner" <<'CRON'
0 * * * * /usr/bin/banner_auto_update.sh
0 0 * * * /usr/bin/banner_cache_cleaner.sh
CRON

# --- 用這段新程式碼替換舊的 init 腳本 ---
cat > "$PKG_DIR/root/etc/init.d/banner" <<'INIT'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start() {
    # 检查 UCI 命令
    if ! command -v uci >/dev/null 2>&1; then
        echo "[$(date)] Error: UCI command not found, cannot start banner service." >> /tmp/banner_init.log
        return 1
    fi

    # 日志函数
    log_msg() {
        echo "[$(date)] $1" >> /tmp/banner_update.log
    }

    # 获取活跃网络接口
    get_active_interface() {
        local iface
        for iface in $(ubus list network.interface.* | cut -d. -f3); do
            if ubus call network.interface."$iface" status 2>/dev/null | grep -q '"up": true'; then
                echo "$iface"
                return
            fi
        done
        echo "lan"
    }

    INTERFACE=$(get_active_interface)
    log_msg "Network detection: Using interface '$INTERFACE'."

    # 等待网络接口上线，最多等待 30 秒
    WAIT=0
    while :; do
        STATUS=$(ubus call network.interface.$INTERFACE status 2>/dev/null)
        echo "$STATUS" | grep -q '"up": true' && break
        sleep 2
        WAIT=$((WAIT + 2))
        if [ $WAIT -ge 30 ]; then
            log_msg "Network interface '$INTERFACE' not up after 30 seconds. Proceeding anyway."
            break
        fi
    done

    # 创建目录并设置权限
    mkdir -p /tmp/banner_cache /www/luci-static/banner /overlay/banner
    chmod 755 /tmp/banner_cache /www/luci-static/banner /overlay/banner

    # 确定背景图目录
    PERSISTENT=$(uci -q get banner.banner.persistent_storage || echo "0")
    if [ "$PERSISTENT" = "1" ]; then
        BG_DIR="/overlay/banner"
    else
        BG_DIR="/www/luci-static/banner"
    fi

   # 确保缓存目录有图片
    if [ ! -s /tmp/banner_cache/current_bg.jpg ]; then
        # 优先级1: 检查web目录
        if [ -f "$BG_DIR/bg0.jpg" ] && [ -s "$BG_DIR/bg0.jpg" ]; then
            cp "$BG_DIR/bg0.jpg" /tmp/banner_cache/current_bg.jpg
            log_msg "Using existing bg0.jpg from $BG_DIR"
        # 优先级2: 使用打包的离线图片
        elif [ -f "/usr/share/banner/bg0.jpg" ]; then
            cp "/usr/share/banner/bg0.jpg" "$BG_DIR/bg0.jpg"
            cp "/usr/share/banner/bg0.jpg" /tmp/banner_cache/current_bg.jpg
            log_msg "Initialized offline background from package"
        else
            log_msg "WARNING: No background image available"
        fi
    fi

    # 启动后台更新和加载脚本，输出到日志
    /usr/bin/banner_auto_update.sh >> /tmp/banner_update.log 2>&1 &
    sleep 2
    BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
    /usr/bin/banner_bg_loader.sh "$BG_GROUP" >> /tmp/banner_update.log 2>&1 &
}


status() {
    local uci_enabled=$(uci -q get banner.banner.bg_enabled || echo 1)
    local remote_msg=$(uci -q get banner.banner.remote_message)

    echo "===== Banner Status ====="
    if [ "$uci_enabled" = "0" ] && [ -n "$remote_msg" ]; then
        echo "Status: Disabled (Reason: $remote_msg)"
    else
        echo "Status: Enabled"
    fi
    
    local last_update=$(uci -q get banner.banner.last_update || echo 0)
    if [ "$last_update" = "0" ]; then
        echo "Last Update: Never"
    else
        echo "Last Update: $(date -d "@$last_update" '+%Y-%m-%d %H:%M:%S')"
    fi
    echo "========================"
}
INIT

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
    
    if uci:get("banner", "banner", "bg_enabled") == "0" then
        luci.template.render("banner/display", {
            bg_enabled = "0",
            remote_message = uci:get("banner", "banner", "remote_message") or "服务已被远程禁用"
        })
        return
    end
    
    local nav_data = { nav_tabs = {} }
    pcall(function()
        nav_data = require("luci.jsonc").parse(fs.readfile("/tmp/banner_cache/nav_data.json"))
    end)
    
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"

    local text = uci:get("banner", "banner", "text") or "欢迎使用"
    
    local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
    if not opacity or opacity < 0 or opacity > 100 then
        opacity = 50
    end

    local banner_texts = uci:get("banner", "banner", "banner_texts") or ""
    if banner_texts == "" then
        banner_texts = text
    end

    luci.template.render("banner/display", {
        text = text,
        color = uci:get("banner", "banner", "color"),
        opacity = opacity,
        carousel_interval = uci:get("banner", "banner", "carousel_interval"),
        current_bg = uci:get("banner", "banner", "current_bg"),
        bg_enabled = "1",
        banner_texts = banner_texts,
        nav_data = nav_data,
       persistent = persistent,
        bg_path = bg_path,
        token = luci.dispatcher.context.authsession,
        uci = uci
    })
end

function action_settings()
    local uci = require("uci").cursor()
    
    local urls = uci:get("banner", "banner", "update_urls") or {}
    if type(urls) ~= "table" then urls = { urls } end
    
    local display_urls = {}
    for _, url in ipairs(urls) do
        local name = "Unknown Source"
        if url:match("github") then name = "GitHub"
        elseif url:match("gitee") then name = "Gitee"
        end
        table.insert(display_urls, { value = url, display = name })
    end
    
    local log = luci.sys.exec("tail -c 5000 /tmp/banner_update.log 2>/dev/null") or "暫無日誌"
    if log == "" then log = "暫無日誌" end
    
    luci.template.render("banner/settings", {
        text = uci:get("banner", "banner", "text"),
        opacity = uci:get("banner", "banner", "opacity"),
        carousel_interval = uci:get("banner", "banner", "carousel_interval"),
        persistent_storage = uci:get("banner", "banner", "persistent_storage"),
        last_update = uci:get("banner", "banner", "last_update"),
        remote_message = uci:get("banner", "banner", "remote_message"),
        display_urls = display_urls,
        selected_url = uci:get("banner", "banner", "selected_url"),
        token = luci.dispatcher.context.authsession,
        log = log
    })
end

function action_background()
    local uci = require("uci").cursor()
   local log = luci.sys.exec("tail -c 5000 /tmp/banner_bg.log 2>/dev/null") or "暫無日誌"
if log == "" then log = "暫無日誌" end
    
    luci.template.render("banner/background", {
        bg_group = uci:get("banner", "banner", "bg_group"),
        opacity = uci:get("banner", "banner", "opacity"),
        current_bg = uci:get("banner", "banner", "current_bg"),
        persistent_storage = uci:get("banner", "banner", "persistent_storage"),
        token = luci.dispatcher.context.authsession,
        log = log
    })
end

function action_do_update()
    luci.sys.call("/usr/bin/banner_manual_update.sh >/dev/null 2>&1 &")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_do_set_bg()
    local uci = require("uci").cursor()
    local bg = luci.http.formvalue("bg")
    if bg and bg:match("^[0-2]$") then
        uci:set("banner", "banner", "current_bg", bg)
        uci:commit("banner")
        local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
        local src_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
        if not (src_path == "/overlay/banner" or src_path == "/www/luci-static/banner") then
            luci.http.status(400, "Invalid source directory")
            return
        end
        luci.sys.call(string.format("cp %s/bg%s.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null", src_path, bg))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_clear_cache()
    luci.sys.call("rm -f /tmp/banner_cache/bg*.jpg /overlay/banner/bg*.jpg /www/luci-static/banner/bg*.jpg")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_load_group()
    local uci = require("uci").cursor()
    local group = luci.http.formvalue("group")
    if group and group:match("^[1-4]$") then
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
    local dest_dir = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    if not (dest_dir == "/overlay/banner" or dest_dir == "/www/luci-static/banner") then
        luci.http.status(400, "Invalid destination directory")
        return
    end
    sys.call("mkdir -p '" .. dest_dir .. "'")

    local tmp_file = dest_dir .. "/bg0.tmp"
    local final_file = dest_dir .. "/bg0.jpg"

    http.setfilehandler(function(meta, chunk, eof)
        if not meta or meta.name ~= "bg_file" then return end
        
        if chunk then
            local fp = io.open(tmp_file, "ab")
            if fp then fp:write(chunk); fp:close() end
        end

        if eof then
            local max_size = tonumber(uci:get("banner", "banner", "max_file_size") or "3145728")
            if fs.stat(tmp_file) and fs.stat(tmp_file).size > max_size then
                fs.remove(tmp_file)
                luci.http.status(400, "File size exceeds 3MB")
                return
            end
            if sys.call("file '" .. tmp_file .. "' | grep -qiE 'JPEG|JPG'") == 0 then
                fs.rename(tmp_file, final_file)
                sys.call("chmod 644 '" .. final_file .. "'")
                if persistent == "1" then
                    sys.call("cp '" .. final_file .. "' /www/luci-static/banner/bg0.jpg 2>/dev/null")
                end
                sys.call("cp '" .. final_file .. "' /tmp/banner_cache/current_bg.jpg 2>/dev/null")
                uci:set("banner", "banner", "current_bg", "0")
                uci:commit("banner")
            else
                fs.remove(tmp_file)
                luci.http.status(400, "Invalid JPEG file")
            end
        end
    end)
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_apply_url()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    local sys = require("luci.sys")
    local url = luci.http.formvalue("custom_bg_url")

    if not url or not url:match("^https://.*%.jpe?g$") then
        luci.http.status(400, "Invalid URL format")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
        return
    end

    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest_dir = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    if not (dest_dir == "/overlay/banner" or dest_dir == "/www/luci-static/banner") then
        luci.http.status(400, "Invalid destination directory")
        return
    end
    sys.call("mkdir -p '" .. dest_dir .. "'")
    
    local tmp_file = dest_dir .. "/bg0.tmp"
    local final_file = dest_dir .. "/bg0.jpg"
    
    local max_size = uci:get("banner", "banner", "max_file_size") or "3145728"
    local curl_cmd = string.format("curl -fsSL --max-time 20 --max-filesize %s '%s' -o '%s'", max_size, url, tmp_file)

    if os.execute(curl_cmd) == 0 and fs.stat(tmp_file) then
        local magic_ok = false
        local f = io.open(tmp_file, "rb")
        if f then
            if f:read(2) == "\255\216" then magic_ok = true end
            f:close()
        end

        if magic_ok or (sys.call("file '" .. tmp_file .. "' | grep -qiE 'JPEG|JPG'") == 0) then
            fs.rename(tmp_file, final_file)
            if persistent == "1" then
                sys.call("cp '" .. final_file .. "' /www/luci-static/banner/bg0.jpg 2>/dev/null")
            end
            sys.call("cp '" .. final_file .. "' /tmp/banner_cache/current_bg.jpg 2>/dev/null")
            uci:set("banner", "banner", "current_bg", "0")
            uci:commit("banner")
        else
            fs.remove(tmp_file)
            luci.http.status(400, "Invalid JPEG file")
        end
    else
        fs.remove(tmp_file)
        luci.http.status(400, "Failed to download file")
    end
    
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_set_opacity()
    local uci = require("uci").cursor()
    local opacity = luci.http.formvalue("opacity")
    if opacity and tonumber(opacity) and tonumber(opacity) >= 0 and tonumber(opacity) <= 100 then
        uci:set("banner", "banner", "opacity", opacity)
        uci:commit("banner")
        luci.http.status(200)
    else
        luci.http.status(400, "Invalid opacity value (must be 0-100)")
    end
end

function action_do_set_carousel_interval()
    local uci = require("uci").cursor()
    local interval = luci.http.formvalue("carousel_interval")
    if interval and tonumber(interval) and tonumber(interval) >= 1000 and tonumber(interval) <= 30000 then
        uci:set("banner", "banner", "carousel_interval", interval)
        uci:commit("banner")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
    else
        luci.http.status(400, "Invalid carousel interval (must be 1000-30000)")
    end
end

function action_do_set_update_url()
    local uci = require("uci").cursor()
    local selected_url = luci.http.formvalue("selected_url")
    if selected_url and selected_url:match("^https?://") then
        uci:set("banner", "banner", "selected_url", selected_url)
        uci:commit("banner")
    else
        luci.http.status(400, "Invalid URL format")
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
            luci.sys.call("mkdir -p /overlay/banner && cp /www/luci-static/banner/bg*.jpg /overlay/banner/ 2>/dev/null")
        else
            luci.sys.call("cp /overlay/banner/bg*.jpg /www/luci-static/banner/ 2>/dev/null")
        end
    else
        luci.http.status(400, "Invalid persistent storage value")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end

function action_check_bg_complete()
    if require("nixio.fs").access("/tmp/banner_cache/bg_complete") then
        luci.http.write("complete")
    else
        luci.http.write("pending")
    end
end

function action_do_reset_defaults()
    local uci = require("uci").cursor()
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
    luci.sys.call("rm -f /tmp/banner_cache/* /overlay/banner/bg*.jpg /www/luci-static/banner/bg*.jpg")
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end
CONTROLLER
# Global style view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/global_style.htm" <<'GLOBALSTYLE'
<%
local uci = require("uci").cursor()
local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
local alpha = (100 - opacity) / 100
local bg_path = "/luci-static/banner"
%>
<style type="text/css">
html, body {
    background: linear-gradient(rgba(0,0,0,<%=alpha%>), rgba(0,0,0,<%=alpha%>)), 
                url(/luci-static/banner/bg0.jpg?t=<%=os.time()%>) center/cover fixed no-repeat !important;
    min-height: 100vh !important;
}
#maincontent, .container, .cbi-map, .cbi-section, .cbi-map > *, .cbi-section > *, .cbi-section-node, .table, .tr, .td, .th {
    background: transparent !important;
}
.cbi-map {
    background: rgba(0,0,0,0.3) !important;
    border: 1px solid rgba(255,255,255,0.1) !important;
    border-radius: 12px !important;
    box-shadow: 0 8px 32px rgba(0,0,0,0.2) !important;
    padding: 15px !important;
}
.cbi-section {
    background: rgba(0,0,0,0.2) !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
    border-radius: 8px !important;
    padding: 10px !important;
}
h2, h3, label, legend, .cbi-section-descr {
    color: white !important;
    text-shadow: 0 2px 4px rgba(0,0,0,0.6) !important;
}
input, textarea, select {
    background: rgba(255,255,255,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: #333 !important;
    border-radius: 4px !important;
}
.cbi-button {
    background: rgba(66,139,202,0.9) !important;
    border: 1px solid rgba(255,255,255,0.3) !important;
    color: white !important;
    border-radius: 4px !important;
    cursor: pointer !important;
    transition: all 0.3s !important;
}
.cbi-button:hover {
    background: rgba(66,139,202,1) !important;
    transform: translateY(-1px) !important;
}
</style>
<script type="text/javascript">
document.addEventListener('DOMContentLoaded', function() {
    var slider = document.getElementById('opacity-slider');
    if (slider) {
        slider.addEventListener('input', function(e) {
            var value = parseInt(e.target.value);
            var display = document.getElementById('opacity-display');
            if (display) display.textContent = value + '%';
        });
    }
});
</script>
GLOBALSTYLE

# Display view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/display.htm" <<'DISPLAYVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.banner-hero { background: rgba(0,0,0,.3); border-radius: 15px; padding: 20px; margin: 20px auto; max-width: min(1200px, 95vw); }
.carousel { position: relative; width: 100%; height: 300px; overflow: hidden; border-radius: 10px; margin-bottom: 20px; }
.carousel img { width: 100%; height: 100%; object-fit: cover; position: absolute; opacity: 0; transition: opacity .5s; }
.carousel img.active { opacity: 1; }
.banner-scroll { padding: 20px; margin-bottom: 30px; text-align: center; font-weight: 700; font-size: 18px; border-radius: 10px; min-height: 60px; display: flex; align-items: center; justify-content: center;
<% if color == 'rainbow' then %>background: linear-gradient(90deg, #ff0000, #ff7f00, #ffff00, #00ff00, #0000ff, #4b0082, #9400d3); background-size: 400% 400%; animation: rainbow 8s ease infinite; color: #fff; text-shadow: 2px 2px 4px rgba(0,0,0,.5)<% else %>background: rgba(255,255,255,.15); color: <%=color%><% end %>
}
@keyframes rainbow { 0%,100% { background-position: 0% 50% } 50% { background-position: 100% 50% } }
.banner-contacts { display: flex; flex-direction: column; gap: 15px; margin-bottom: 30px; }
.contact-card { background: rgba(0,0,0,.3); border: 1px solid rgba(255,255,255,.18); border-radius: 10px; padding: 15px; color: #fff; display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.contact-info { flex: 1; min-width: 200px; text-align: left; }
.contact-info span { display: block; color: #aaa; font-size: 14px; margin-bottom: 5px; }
.copy-btn { background: rgba(76,175,80,.9); color: #fff; border: 0; padding: 8px 18px; border-radius: 5px; cursor: pointer; font-weight: 700; transition: all .3s; }
.copy-btn:hover { background: rgba(76,175,80,1); transform: translateY(-2px); }
.nav-section h3 { color: #fff; text-align: center; margin-bottom: 20px; }
.nav-groups { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
.nav-group { background: rgba(0,0,0,.3); border: 1px solid rgba(255,255,255,.15); border-radius: 10px; padding: 15px; transition: all .3s; }
.nav-group:hover { transform: translateY(-3px); border-color: #4fc3f7; }
.nav-group:hover .nav-links {display: flex !important;}
.nav-group-title { font-size: 18px; font-weight: 700; color: #fff; text-align: center; margin-bottom: 10px; padding: 10px; background: rgba(102,126,234,.6); border-radius: 8px; display: flex; align-items: center; justify-content: center; cursor: pointer; }
.nav-group-title img { width: 24px; height: 24px; margin-right: 8px; }
.nav-links { 
    display: none; 
    flex-direction: column;  /* 强制竖向 */
    padding: 10px 0; 
    max-height: 300px; 
    overflow-y: auto; 
}
.nav-links.active { 
    display: flex;  /* 改为 flex 以支持 flex-direction */
}
.nav-links a { display: block; color: #4fc3f7; text-decoration: none; padding: 10px; margin: 5px 0; border-radius: 5px; background: rgba(255,255,255,.1); transition: all .2s; }
.nav-links a:hover { background: rgba(79,195,247,.3); transform: translateX(5px); }
.nav-group { transition: all .3s; }
.nav-group:hover .nav-links { display: flex !important; flex-direction: column; }
@media (min-width: 769px) { .nav-group-title { cursor: default; } .nav-links { display: none; } } /* 桌面hover，移动点击 */
.pagination { text-align: center; margin-top: 20px; }
.pagination button { background: rgba(66,139,202,.9); border: 1px solid rgba(255,255,255,.3); color: #fff; padding: 8px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; }
.pagination button:disabled { background: rgba(100,100,100,.5); cursor: not-allowed; }
.bg-selector { position: fixed; bottom: 30px; right: 30px; display: flex; gap: 12px; z-index: 999; }
.bg-circle { width: 50px; height: 50px; border-radius: 50%; border: 3px solid rgba(255,255,255,.8); background-size: cover; cursor: pointer; transition: all .3s; }
.bg-circle:hover { transform: scale(1.15); border-color: #4fc3f7; }
.disabled-message { background: rgba(100,100,100,.8); color: #fff; padding: 15px; border-radius: 10px; text-align: center; font-weight: 700; }
/* 平板优化 */
@media (max-width: 1024px) and (min-width: 769px) {
    .banner-hero { padding: 15px; max-width: 90vw; }
    .carousel { height: 280px; }
    .nav-groups { grid-template-columns: repeat(2, 1fr); }
}

/* 手机优化 */
@media (max-width: 768px) {
    .banner-hero { padding: 10px; max-width: 100%; }
    .carousel { height: 200px; }
    .banner-scroll { font-size: 16px; padding: 15px; }
    .copy-btn { padding: 6px 12px; font-size: 14px; }
    .nav-groups { grid-template-columns: 1fr; }
    .bg-selector { bottom: 15px; right: 15px; gap: 8px; }
    .bg-circle { width: 40px; height: 40px; }
}

/* 超小屏优化 */
@media (max-width: 480px) {
    .banner-scroll { font-size: 14px; padding: 12px; min-height: 50px; }
    .contact-card { flex-direction: column; text-align: center; }
    .nav-group { padding: 10px; }
}
</style>
<% if bg_enabled == "0" then %>
    <div class="disabled-message"><%= pcdata(remote_message) %></div>
<% else %>
    <div class="banner-hero">
        <!-- 横幅文字移到最上方 -->
        <div class="banner-scroll" id="banner-text"><%= pcdata(text) %></div>
        
        <!-- 轮播图 -->
        <div class="carousel">
            <% for i = 0, 2 do %><img src="/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>" alt="BG <%=i+1%>" loading="lazy"><% end %>
        </div>
        
        <!-- 联系方式 -->
        <div class="banner-contacts">
            <div class="contact-card"><div class="contact-info"><span>📧 邮箱</span><strong><%=uci:get("banner", "banner", "contact_email") or "example@email.com"%></strong></div><button class="copy-btn" onclick="copyText('<%=uci:get("banner", "banner", "contact_email") or "example@email.com"%>')">复制</button></div>
<div class="contact-card"><div class="contact-info"><span>📱 Telegram</span><strong><%=uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"%></strong></div><button class="copy-btn" onclick="copyText('<%=uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"%>')">复制</button></div>
<div class="contact-card"><div class="contact-info"><span>💬 QQ</span><strong><%=uci:get("banner", "banner", "contact_qq") or "183452852"%></strong></div><button class="copy-btn" onclick="copyText('<%=uci:get("banner", "banner", "contact_qq") or "183452852"%>')">复制</button></div>
        </div>
        <% if nav_data and nav_data.nav_tabs then %>
        <div class="nav-section">
            <h3>🚀 快速导航</h3>
            <div class="nav-groups" id="nav-groups">
                <% for i, tab in ipairs(nav_data.nav_tabs) do %>
                <div class="nav-group" data-page="<%=math.ceil(i/4)%>" style="display:none">
                    <div class="nav-group-title" onclick="toggleLinks(this.parentElement)">
                        <% if tab.icon then %><img src="<%=pcdata(tab.icon)%>"><% end %>
                        <%=pcdata(tab.title)%>
                    </div>
                    <div class="nav-links">
                        <% for _, link in ipairs(tab.links) do %>
                        <a href="<%=pcdata(link.url)%>" target="_blank" rel="noopener noreferrer"><%=pcdata(link.name)%></a>
                        <% end %>
                    </div>
                </div>
                <% end %>
            </div>
            <div class="pagination">
                <button onclick="changePage(-1)">◀</button>
                <span id="page-info" style="color:white;vertical-align:middle;margin:0 10px;"></span>
                <button onclick="changePage(1)">▶</button>
            </div>
        </div>
        <% end %>
    </div>
    <div class="bg-selector">
        <% for i = 0, 2 do %>
        <div class="bg-circle" style="background-image:url(/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>)" onclick="changeBg(<%=i%>)" title="切换背景 <%=i+1%>"></div>
        <% end %>
    </div>
<% end %>
<script type="text/javascript">
var images = document.querySelectorAll('.carousel img'), current = 0;
function showImage(index) { images.forEach(function(img, i) { img.classList.toggle('active', i === index); }); }
if (images.length > 1) { showImage(current); setInterval(function() { current = (current + 1) % images.length; showImage(current); }, <%=carousel_interval%>); } else if (images.length > 0) { showImage(0); }

var bannerTexts = '<%=banner_texts%>'.split('|').filter(Boolean), textIndex = 0;
if (bannerTexts.length > 1) {
    var textElem = document.getElementById('banner-text');
    setInterval(function() {
        textIndex = (textIndex + 1) % bannerTexts.length;
        textElem.style.opacity = 0;
        setTimeout(function() { textElem.textContent = bannerTexts[textIndex]; textElem.style.opacity = 1; }, 300);
    }, <%=carousel_interval%>);
}

<% if nav_data and nav_data.nav_tabs then %>
var currentPage = 1, totalPages = <%=math.ceil(#nav_data.nav_tabs/4)%>;
function changePage(delta) { currentPage = Math.max(1, Math.min(totalPages, currentPage + delta)); showPage(currentPage); }
function showPage(page) {
    document.querySelectorAll('.nav-group').forEach(function(g) { g.style.display = g.dataset.page == page ? 'block' : 'none'; });
    document.getElementById('page-info').textContent = page + ' / ' + totalPages;
    var btns = document.querySelectorAll('.pagination button');
    btns[0].disabled = page === 1; btns[1].disabled = page === totalPages;
}
showPage(1);
<% end %>

function toggleLinks(el) { 
    // 仅在移动端使用点击切换
    if (window.innerWidth <= 768) {
        el.querySelector('.nav-links').classList.toggle('active'); 
    }
}

function changeBg(n) {
    var f = document.createElement('form');
    f.method = 'POST';
    f.action = '<%=luci.dispatcher.build_url("admin/status/banner/do_set_bg")%>';
    f.innerHTML = '<input name="token" type="hidden" value="<%=token%>"><input name="bg" value="' + n + '">';
    document.body.appendChild(f).submit();
}
function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() { 
            alert('✓ 已复制: ' + text); 
        }).catch(function() { 
            fallbackCopy(text); 
        });
    } else {
        fallbackCopy(text);
    }
}

function fallbackCopy(text) {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.left = '-9999px';
    document.body.appendChild(textarea);
    textarea.select();
    try {
        var success = document.execCommand('copy');
        alert(success ? '✓ 已复制: ' + text : '✗ 复制失败，请手动复制');
    } catch(e) {
        alert('✗ 复制失败: ' + text);
    }
    document.body.removeChild(textarea);
}

// 新增开始 (优化 3：加载超时提示)
setTimeout(function() {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/tmp/banner_cache/nav_data.json', true);
    xhr.onload = function() {
    if (xhr.status !== 200) {
        console.log('⚠️ 数据加载失败，可能显示默认内容');  // 改用 console.log
    }
};
xhr.onerror = function() {
    console.log('⚠️ 数据加载失败，可能显示默认内容');
};
    xhr.send();
}, 5000);
</script>
<%+footer%>
DISPLAYVIEW

# Settings view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/settings.htm" <<'SETTINGSVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.toggle-switch { position: relative; display: inline-block; width: 50px; height: 24px; }
.toggle-switch input { opacity: 0; width: 0; height: 0; }
.toggle-slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: rgba(200,200,200,.5); transition: .4s; border-radius: 24px; }
.toggle-slider:before { position: absolute; content: ""; height: 18px; width: 18px; left: 3px; bottom: 3px; background-color: #fff; transition: .4s; border-radius: 50%; }
input:checked + .toggle-slider { background-color: rgba(76,175,80,.9); }
input:checked + .toggle-slider:before { transform: translateX(26px); }
</style>
<div class="cbi-map">
    <h2>远程更新设置</h2>
    <div class="cbi-section-node">
        <% if remote_message and remote_message ~= "" then %>
        <div style="background:rgba(217,83,79,.8);color:#fff;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center"><%=pcdata(remote_message)%></div>
        <% end %>
        <div class="cbi-value"><label class="cbi-value-title">背景透明度</label><div class="cbi-value-field">
    <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_opacity')%>" style="display:flex;align-items:center;gap:10px;">
        <input name="token" type="hidden" value="<%=token%>">
        <input type="range" name="opacity" min="0" max="100" value="<%=opacity%>" id="opacity-slider" style="width:60%">
        <span id="opacity-display" style="color:#fff;"><%=opacity%>%</span>
        <input type="submit" class="cbi-button" value="应用" style="padding:4px 12px;">
    </form>
</div></div>
        <div class="cbi-value"><label class="cbi-value-title">永久存储背景</label><div class="cbi-value-field"><label class="toggle-switch"><input type="checkbox"<%=persistent_storage=='1' and ' checked'%> onchange="togglePersistent(this.checked)"><span class="toggle-slider"></span></label><span style="color:#fff;vertical-align:super;margin-left:10px;"><%=persistent_storage=='1' and '已启用' or '已禁用'%></span></div></div>
<div class="cbi-value"><label class="cbi-value-title">轮播间隔(毫秒)</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_carousel_interval')%>">
                <input name="token" type="hidden" value="<%=token%>">
                <input type="number" name="carousel_interval" value="<%=carousel_interval%>" min="1000" max="30000" style="width:100px">
                <input type="submit" class="cbi-button" value="应用">
            </form>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">更新源</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_update_url')%>">
                <input name="token" type="hidden" value="<%=token%>">
                <select name="selected_url"><% for _, item in ipairs(display_urls) do %><option value="<%=item.value%>"<%=item.value==selected_url and ' selected'%>><%=item.display%></option><% end %></select>
                <input type="submit" class="cbi-button" value="选择">
            </form>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">上次更新</label><div class="cbi-value-field"><input readonly value="<%=last_update=='0' and '从未' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update))%>"></div></div>
        <div class="cbi-value"><div class="cbi-value-field"><form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_update')%>"><input name="token" type="hidden" value="<%=token%>"><input type="submit" class="cbi-button" value="立即手动更新"></form></div></div>
        <div class="cbi-value"><label class="cbi-value-title">恢复默认配置</label><div class="cbi-value-field"><form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_reset_defaults')%>" onsubmit="return confirm('确定要恢复默认配置吗？')"><input name="token" type="hidden" value="<%=token%>"><input type="submit" class="cbi-button cbi-button-reset" value="恢复默认值"></form></div></div>
        <h3>更新日志</h3><div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap"><%=pcdata(log)%></div>
    </div>
</div>
<script type="text/javascript">
function togglePersistent(checkbox) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '<%=luci.dispatcher.build_url("admin/status/banner/do_set_persistent_storage")%>', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onload = function() { window.location.reload(); };
    xhr.send('token=<%=token%>&persistent_storage=' + (checkbox.checked ? '1' : '0'));
}
// OPTIMIZATION 2.5: Disable submit button on invalid input
var carouselForm = document.querySelector('form[action*="do_set_carousel_interval"]');
if (carouselForm) {
    carouselForm.addEventListener('input', function(e) {
        var input = e.target;
        var value = parseInt(input.value, 10);
        var submitBtn = this.querySelector('[type=submit]');
        var isValid = !isNaN(value) && value >= 1000 && value <= 30000;
        submitBtn.disabled = !isValid;
        input.style.borderColor = isValid ? '' : 'red';
    });
}

window.useSimpleAlert = true;
function showMsg(text) {
    if (window.useSimpleAlert) {
        alert(text);
    } else {
        // ... 自定義模態框邏輯 ...
    }
}
function closeMsg() { /* ... */ }
// --- 新增結束 ---

</script>
<%+footer%>
SETTINGSVIEW

# Background settings view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/background.htm" <<'BGVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.loading-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,.8); display: none; justify-content: center; align-items: center; z-index: 9999; }
.loading-overlay.active { display: flex; }
/* --- 用這段新程式碼替換舊的 .spinner 規則 --- */
.spinner {
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top-color: #4fc3f7; /* 只改變頂部顏色，更清晰 */
    border-radius: 50%;
    width: 50px;
    height: 50px;
    margin: 0 auto 20px;
    /* 使用新的動畫屬性，時長 1.2s，並採用 ease-in-out 的變速曲線 */
    animation: spin 1.2s cubic-bezier(0.65, 0, 0.35, 1) infinite;
}

/* --- 用這段新程式碼替換舊的 @keyframes spin 規則 --- */
@keyframes spin {
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

</style>
<div class="loading-overlay" id="loadingOverlay"><div style="text-align:center;color:#fff"><div class="spinner"></div><p>正在下载背景图...</p></div></div>
<div class="cbi-map">
    <h2>背景图设置</h2>
    <div class="cbi-section-node">
        <div class="cbi-value"><label class="cbi-value-title">选择背景图组</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_load_group')%>" id="loadGroupForm">
                <input name="token" type="hidden" value="<%=token%>">
                <select name="group">
                    <% for i = 1, 4 do %><option value="<%=i%>"<%=bg_group==tostring(i) and ' selected'%>><%=i..'-'..i*3%></option><% end %>
                </select>
                <input type="submit" class="cbi-button" value="加载背景组">
            </form>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">手动填写背景图链接</label><div class="cbi-value-field">
            <form id="customBgForm" method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
                
                <input name="token" type="hidden" value="<%=token%>">
                <input type="text" name="custom_bg_url" placeholder="https://..." style="width:70%">
                <input type="submit" class="cbi-button" value="应用链接">
            </form>
            <p style="color:#aaa;font-size:12px">📌 仅支持 GitHub/Gitee 的 HTTPS JPG/JPEG 链接 (小于3MB ), 应用后覆盖 bg0.jpg</p>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">从本地上传背景图</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data" id="uploadForm">
                <input name="token" type="hidden" value="<%=token%>">
                <input type="file" name="bg_file" accept="image/jpeg" required>
                <input type="submit" class="cbi-button" value="上传并应用">
            </form>
            <p style="color:#aaa;font-size:12px">📤 仅支持 JPG (小于3MB), 上传后覆盖 bg0.jpg</p>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">删除缓存图片</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_clear_cache')%>">
                <input name="token" type="hidden" value="<%=token%>">
                <input type="submit" class="cbi-button cbi-button-remove" value="删除缓存">
            </form>
        </div></div>
        <h3>背景日志</h3>
<div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap"><%=pcdata(log)%></div>
</div>
</div>
<script>
function showMsg(msg) {
    alert(msg);
}
</script>
<script type="text/javascript">
document.getElementById('customBgForm').addEventListener('submit', function(e) {
    var url = this.custom_bg_url.value.trim();
    // 只驗證 HTTPS 和 .jpg/.jpeg 後綴，不再限制域名
    if (!url.match(/^https:\/\/.*\.jpe?g$/i )) {
        e.preventDefault();
        // 提示用戶格式要求，並告知後續會有內容驗證
        showMsg('⚠️ 格式錯誤！請確保鏈接以 https:// 開頭 ，並以 .jpg 或 .jpeg 結尾。\n\n(注意：提交後系統仍會驗證文件內容是否為真實圖片)');
    }
});

document.getElementById('uploadForm').addEventListener('submit', function(e) {
    var file = this.bg_file.files[0];
    if (!file) {
        e.preventDefault();
        showMsg('⚠️ 请选择文件');
        return;
    }
    if (file.size > 3145728) {
        e.preventDefault();
        showMsg('⚠️ 文件大小不能超过 3MB');
        return;
    }
    if (!file.type.match('image/jpeg') && !file.name.match(/\.jpe?g$/i)) {
        e.preventDefault();
        showMsg('⚠️ 仅支持 JPG/JPEG 格式');
    }
});
</script>
<%+footer%>
BGVIEW

# Make scripts executable
chmod +x "$PKG_DIR"/root/usr/bin/*.sh
chmod +x "$PKG_DIR"/root/etc/init.d/banner

echo "=========================================="
echo "✓ Package luci-app-banner v2.7 (Final) Ready!"
echo "=========================================="
echo "Package directory: $PKG_DIR"
echo ""
echo "All optimizations from v2.1 to v2.5 have been integrated."
echo "This version is the most stable and compatible."
echo ""
echo "Compilation command:"
echo "  make package/custom/luci-app-banner/compile V=s"
echo "=========================================="
