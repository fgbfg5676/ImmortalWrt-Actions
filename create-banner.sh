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


# ==================== 路径安全检查 - 加强版 ====================


# 检查目录变量是否为空
if [ -z "$PKG_DIR" ]; then
    echo "✖ 错误：目标目录变量为空，已终止操作。"
    exit 1
fi

# 获取规范化的绝对路径
if command -v realpath >/dev/null 2>&1; then
    ABS_PKG_DIR=$(realpath -m "$PKG_DIR" 2>/dev/null) || {
        echo "✖ 错误：无法规范化路径 '$PKG_DIR'"
        exit 1
    }
else
    echo "⚠ 警告：系统未安装 realpath，路径安全检查可能不够完善。"
    # Fallback: 手动规范化（不完美但聊胜于无）
    ABS_PKG_DIR=$(cd "$(dirname "$PKG_DIR")" 2>/dev/null && pwd)/$(basename "$PKG_DIR") || {
        echo "✖ 错误：路径无效 '$PKG_DIR'"
        exit 1
    }
fi
# 允许 GitHub Actions Runner 路径
IS_GITHUB_ACTIONS=0
if echo "$ABS_PKG_DIR" | grep -qE "^/home/runner/work/|^/github/workspace"; then
    echo "âš™ å…è®¸ GitHub Actions è·¯å¾„: $ABS_PKG_DIR"
    IS_GITHUB_ACTIONS=1
fi


if echo "$ABS_PKG_DIR" | grep -qE "^/home/[^/]+/.*openwrt"; then
    echo "âš™ å…è®¸æœ¬åœ°å¼€å'è·¯å¾„: $ABS_PKG_DIR"
    IS_GITHUB_ACTIONS=1
fi
if [ $IS_GITHUB_ACTIONS -eq 0 ]; then
# 黑名单检查：禁止危险的系统路径
case "$ABS_PKG_DIR" in
    "/"|\
    "/root"|\
    "/root/"*|\
    "/etc"|\
    "/etc/"*|\
    "/usr"|\
    "/usr/"*|\
    "/bin"|\
    "/bin/"*|\
    "/sbin"|\
    "/sbin/"*|\
    "/lib"|\
    "/lib/"*|\
    "/boot"|\
    "/boot/"*|\
    "$HOME"|\
    "$HOME/"*)
        echo "✖ 错误：目标目录指向了危险的系统路径 ('$ABS_PKG_DIR')，已终止操作。"
        exit 1
        ;;
esac
fi
# 检查路径穿越字符（所有可能的形式）
if echo "$PKG_DIR" | grep -qE '\.\./|\.\.$|/\.\.'; then
    echo "✖ 错误：目标目录包含非法的路径穿越符 '..' ('$PKG_DIR')，已终止操作。"
    exit 1
fi

# 检查符号链接（可选，更严格）
if [ -L "$PKG_DIR" ]; then
    echo "⚠ 警告：目标路径是符号链接，已拒绝。"
    exit 1
fi

# 白名单验证：确保路径在允许的基础目录内
ALLOWED_BASE_DIRS="/tmp /var/tmp $GITHUB_WORKSPACE ./openwrt"
PATH_ALLOWED=0
for allowed_base in $ALLOWED_BASE_DIRS; do
    if [ -n "$allowed_base" ]; then
        # 规范化允许的基础目录
        if command -v realpath >/dev/null 2>&1; then
            allowed_base=$(realpath -m "$allowed_base" 2>/dev/null) || continue
        fi
        
        # 检查目标路径是否在允许的基础目录内
        case "$ABS_PKG_DIR" in
            "$allowed_base"*)
                PATH_ALLOWED=1
                break
                ;;
        esac
    fi
done

if [ $PATH_ALLOWED -eq 0 ]; then
    echo "✖ 错误：目标路径 '$ABS_PKG_DIR' 不在允许的目录范围内。"
    echo "   允许的基础目录: $ALLOWED_BASE_DIRS"
    exit 1
fi

echo "✓ 路径安全检查通过: $ABS_PKG_DIR"

# 安全检查通过，执行删除
rm -rf "$ABS_PKG_DIR"

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
	echo "Installing luci-app-banner..."
	
	# 创建必要目录
	mkdir -p /www/luci-static/banner /overlay/banner /tmp/banner_cache /usr/share/banner 2>/dev/null
	chmod 755 /www/luci-static/banner /overlay/banner /tmp/banner_cache /usr/share/banner
	
	# 🎯 关键: 立即部署内置背景图
	if [ -f /usr/share/banner/bg0.jpg ]; then
		cp -f /usr/share/banner/bg0.jpg /www/luci-static/banner/current_bg.jpg 2>/dev/null
		cp -f /usr/share/banner/bg0.jpg /www/luci-static/banner/bg0.jpg 2>/dev/null
		chmod 644 /www/luci-static/banner/*.jpg
		echo "✓ Built-in background deployed"
	fi
	
	# 确保脚本可执行
	chmod +x /usr/bin/banner_*.sh 2>/dev/null
	chmod +x /etc/init.d/banner 2>/dev/null
	
	# 确保日志文件可写
	touch /tmp/banner_update.log /tmp/banner_bg.log
	chmod 666 /tmp/banner_update.log /tmp/banner_bg.log
	
	# 重启 cron 确保任务加载
	/etc/init.d/cron restart 2>/dev/null
	
	# 启用并启动服务
	/etc/init.d/banner enable
	/etc/init.d/banner start
	
	echo "✓ luci-app-banner installed successfully"
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-banner))
MAKEFILE
echo "调试：Makefile 生成成功，大小 $(wc -c < "$PKG_DIR/Makefile") 字节"
# UCI Configuration
cat > "$PKG_DIR/root/etc/config/banner" <<'UCICONF'
config banner 'banner'
	option text '🎉 福利导航的内容会不定时更新，关注作者不迷路'
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
	option contact_email 'niwo5507@gmail.com'
	option contact_telegram '@fgnb111999'
	option contact_qq '183452852'
UCICONF

cat > "$PKG_DIR/root/usr/share/banner/timeouts.conf" <<'TIMEOUTS'

LOCK_TIMEOUT=60

NETWORK_WAIT_TIMEOUT=60

CURL_CONNECT_TIMEOUT=10
CURL_MAX_TIMEOUT=30

RETRY_INTERVAL=5

BOOT_RETRY_INTERVAL=300
TIMEOUTS

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
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"

    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    if ! echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null; then

        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null

        touch "$log_file" 2>/dev/null && chmod 644 "$log_file" 2>/dev/null
        return 1
    fi
    
    # 日志轮转(加错误保护)
    local log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
    if [ -s "$log_file" ] && [ "$log_size" -gt 51200 ]; then
        {
            # 使用临时文件避免数据丢失
            tail -n 50 "$log_file" > "${log_file}.tmp" 2>/dev/null && \
            mv "${log_file}.tmp" "$log_file" 2>/dev/null
        } || {
            # 轮转失败,尝试直接截断(保留最后100行)
            tail -n 100 "$log_file" > "${log_file}.new" 2>/dev/null && \
            mv "${log_file}.new" "$log_file" 2>/dev/null
        } || {
            # 彻底失败,清空文件(最后的保护)
            : > "$log_file" 2>/dev/null || true
        }
    fi
    
    return 0
}

log "========== Cache Cleanup Started =========="
CACHE_DIR=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")
CLEANUP_AGE=$(uci -q get banner.banner.cleanup_age || echo 3)
if [ ! -d "$CACHE_DIR" ]; then
    log "[!] Cache directory $CACHE_DIR not found, skipping cleanup."
    exit 0
fi
find "$CACHE_DIR" -type f -name '*.jpg' -mtime +"$CLEANUP_AGE" -delete
log "Removed old files from $CACHE_DIR older than $CLEANUP_AGE days."

# 清理 /overlay/banner 中的旧文件
PERSISTENT_DIR=$(uci -q get banner.banner.persistent_dir || echo "/overlay/banner")
if [ -d "$PERSISTENT_DIR" ]; then
    find "$PERSISTENT_DIR" -type f -name '*.jpg' -mtime +"$CLEANUP_AGE" -delete
    log "Removed old files from $PERSISTENT_DIR older than $CLEANUP_AGE days."
fi

log "========== Cache Cleanup Finished =========="
CLEANER

# Background loader script
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}

# 首先加载配置文件(如果存在)
if [ -f "/usr/share/banner/config.sh" ]; then
    . /usr/share/banner/config.sh
else
    MAX_FILE_SIZE=3145728
    CACHE_DIR="/tmp/banner_cache"
    DEFAULT_BG_PATH="/www/luci-static/banner"
    PERSISTENT_BG_PATH="/overlay/banner"
fi

LOG="/tmp/banner_bg.log"
CACHE="$CACHE_DIR"
WEB="$DEFAULT_BG_PATH"
PERSISTENT="$PERSISTENT_BG_PATH"
# 加载超时配置
if [ -f "/usr/share/banner/timeouts.conf" ]; then
    . /usr/share/banner/timeouts.conf
else
    LOCK_TIMEOUT=60
    CURL_CONNECT_TIMEOUT=10
    CURL_MAX_TIMEOUT=30
fi
# 日志函数
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"

    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    if ! echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null; then

        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null

        touch "$log_file" 2>/dev/null && chmod 644 "$log_file" 2>/dev/null
        return 1
    fi
    
    # 日志轮转(加错误保护)
    local log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
    if [ -s "$log_file" ] && [ "$log_size" -gt 51200 ]; then
        {
            # 使用临时文件避免数据丢失
            tail -n 50 "$log_file" > "${log_file}.tmp" 2>/dev/null && \
            mv "${log_file}.tmp" "$log_file" 2>/dev/null
        } || {
            # 轮转失败,尝试直接截断(保留最后100行)
            tail -n 100 "$log_file" > "${log_file}.new" 2>/dev/null && \
            mv "${log_file}.new" "$log_file" 2>/dev/null
        } || {
            # 彻底失败,清空文件(最后的保护)
            : > "$log_file" 2>/dev/null || true
        }
    fi
    
    return 0
}
# ==================== 🔒 JPEG验证函数 ====================
validate_jpeg() {
    local file="$1"
    
    # 检查文件是否存在且非空
    if [ ! -s "$file" ]; then
        log "[✗] File is empty or does not exist: $file"
        return 1
    fi
    
    # 使用 file 命令检查文件类型
    if command -v file >/dev/null 2>&1; then
        if file "$file" 2>/dev/null | grep -qiE 'JPEG|JPG'; then
            log "[✓] Valid JPEG file: $file"
            return 0
        else
            log "[✗] Not a valid JPEG file: $file"
            return 1
        fi
    else
        # 如果没有 file 命令,检查文件头部魔术字节
        # JPEG文件以 FF D8 FF 开头
        local header=$(hexdump -n 3 -e '3/1 "%02X"' "$file" 2>/dev/null)
        if [ "${header:0:4}" = "FFD8" ]; then
            log "[✓] Valid JPEG file (header check): $file"
            return 0
        else
            log "[✗] Invalid JPEG header: $file"
            return 1
        fi
    fi
}

# ==================== 🔒 URL验证函数 ====================
validate_url() {
    local url="$1"
    case "$url" in
        http://*|https://*) 
            return 0
            ;;
        *)
            log "[✗] Invalid URL format: $url"
            return 1
            ;;
    esac
}
# ==================== 新的 flock 锁机制 ====================

LOCK_FD=202
LOCK_FILE="/var/lock/banner_bg_loader.lock"

acquire_lock() {
    local timeout="${1:-60}"
    mkdir -p /var/lock 2>/dev/null
    
    eval "exec $LOCK_FD>&-" 2>/dev/null || true
    
    eval "exec $LOCK_FD>$LOCK_FILE" || {
        log "[ERROR] Failed to open lock file"
        return 1
    }
    
    if flock -w "$timeout" "$LOCK_FD" 2>/dev/null; then
        log "[LOCK] Successfully acquired bg_loader lock (FD: $LOCK_FD)"
        return 0
    else
        log "[ERROR] Failed to acquire lock after ${timeout}s"
        eval "exec $LOCK_FD>&-" 2>/dev/null || true
        return 1
    fi
}

release_lock() {
    if [ -n "$LOCK_FD" ]; then
        flock -u "$LOCK_FD" 2>/dev/null
        eval "exec $LOCK_FD>&-"
    fi
}

cleanup() {
    release_lock
    rm -f "$CACHE/bg_loading"
}
trap cleanup EXIT INT TERM

# 动态决定存储路径
if ! command -v uci >/dev/null 2>&1; then
    DEST="$WEB"
else
    [ "$(uci -q get banner.banner.persistent_storage)" = "1" ] && DEST="$PERSISTENT" || DEST="$WEB"
fi

mkdir -p "$CACHE" "$WEB" "$PERSISTENT"

# 等待 nav_data.json
JSON="$CACHE/nav_data.json"
WAIT_COUNT=0
while [ ! -f "$JSON" ] && [ $WAIT_COUNT -lt 5 ]; do
    log "Waiting for nav_data.json... ($WAIT_COUNT/5)"
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -f "$JSON" ]; then
    log "[!] nav_data.json not found, will use cached backgrounds if available."
    for i in 0 1 2; do
        if [ -f "$DEST/bg${i}.jpg" ]; then
            cp "$DEST/bg${i}.jpg" "$WEB/current_bg.jpg" 2>/dev/null
            log "[i] Using cached bg${i}.jpg as fallback"
            exit 0
        fi
    done
    exit 1
fi

# 获取锁
if ! acquire_lock 60; then
    log "[ERROR] Failed to acquire lock, exiting"
    exit 1
fi

log "Loading random background images..."
echo "loading" > "$CACHE/bg_loading"
rm -f "$CACHE/bg_complete"

# 删除旧背景
rm -f "$DEST"/bg{0,1,2}.jpg
if [ "$(uci -q get banner.banner.persistent_storage)" = "1" ]; then
    rm -f "$WEB"/bg{0,1,2}.jpg
fi

MAX_SIZE=$(uci -q get banner.banner.max_file_size || echo "$MAX_FILE_SIZE")
log "Using max file size limit: $MAX_SIZE bytes."

# 固定的随机图片URL（每次都不同）
DOWNLOAD_SUCCESS=0
for i in 0 1 2; do
    # 添加时间戳确保每次都是新图片
    URL="https://picsum.photos/1920/1080?random=$(($(date +%s) + i))"
    log "  Downloading bg${i}.jpg from Picsum..."
    TMPFILE="$DEST/bg$i.tmp"
    
    # 下载图片（3次重试）
    DOWNLOAD_OK=0
    for attempt in 1 2 3; do
        HTTP_CODE=$(curl -sL --connect-timeout 10 --max-time 20 -w "%{http_code}" -o "$TMPFILE" "$URL" 2>/dev/null)
        
        if [ "$HTTP_CODE" = "200" ] && [ -s "$TMPFILE" ]; then
            DOWNLOAD_OK=1
            log "  [✓] Download successful on attempt $attempt (HTTP $HTTP_CODE)"
            break
        else
            log "  [×] Attempt $attempt failed (HTTP: ${HTTP_CODE:-timeout})"
            rm -f "$TMPFILE"
            [ $attempt -lt 3 ] && sleep 2
        fi
    done
    
    if [ $DOWNLOAD_OK -eq 0 ]; then
        log "  [×] All 3 download attempts failed for bg${i}"
        continue
    fi
    
    # 文件大小检查
    FILE_SIZE=$(stat -c %s "$TMPFILE" 2>/dev/null || wc -c < "$TMPFILE" 2>/dev/null || echo 999999999)
    if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
        log "  [×] File too large: $FILE_SIZE bytes (limit: $MAX_SIZE)"
        rm -f "$TMPFILE"
        continue
    fi

    # HTML检查
    if head -n 1 "$TMPFILE" 2>/dev/null | grep -q "<!DOCTYPE\|<html"; then
        log "  [×] Downloaded HTML instead of image"
        rm -f "$TMPFILE"
        continue
    fi

    # JPEG验证
    if validate_jpeg "$TMPFILE"; then
        mv "$TMPFILE" "$DEST/bg$i.jpg"
        chmod 644 "$DEST/bg$i.jpg"
        log "  [✓] bg${i}.jpg downloaded and validated successfully."
        DOWNLOAD_SUCCESS=1
        
        # 同步到Web目录
        if [ "$(uci -q get banner.banner.persistent_storage)" = "1" ]; then
            cp "$DEST/bg$i.jpg" "$WEB/bg$i.jpg" 2>/dev/null
        fi
        
        # 第一张图设为默认
        if [ ! -f "$WEB/current_bg.jpg" ]; then
            cp "$DEST/bg$i.jpg" "$WEB/current_bg.jpg" 2>/dev/null
        fi
    else
        log "  [×] Downloaded file for bg${i}.jpg is invalid or not a JPEG."
        rm -f "$TMPFILE"
    fi
done

if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "[!] No images were downloaded. Keeping existing images if any."
fi

# 强制更新逻辑
if [ $DOWNLOAD_SUCCESS -eq 1 ]; then
    if [ -s "$DEST/bg0.jpg" ]; then
        cp "$DEST/bg0.jpg" "$WEB/current_bg.jpg" 2>/dev/null
        log "[✓] Auto-updated current_bg.jpg to bg0.jpg"
        
        # 同步到初始化目录
        if [ -d "/usr/share/banner" ]; then
            cp "$DEST/bg0.jpg" "/usr/share/banner/bg0.jpg" 2>/dev/null
            log "[✓] Synced to initialization background"
        fi
        
        # 更新UCI
        if command -v uci >/dev/null 2>&1; then
            uci set banner.banner.current_bg='0' 2>/dev/null
            uci commit banner 2>/dev/null
            log "[✓] UCI updated: current_bg set to 0"
        fi
    fi
else
    # 兜底：保持现有背景
    if [ ! -s "$WEB/current_bg.jpg" ]; then
        log "[!] current_bg.jpg is missing. Attempting to restore."
        for i in 0 1 2; do
            if [ -s "$DEST/bg${i}.jpg" ]; then
                cp "$DEST/bg${i}.jpg" "$WEB/current_bg.jpg" 2>/dev/null
                log "[i] Restored current_bg.jpg from bg${i}.jpg"
                break
            fi
        done
    fi
fi

log "[Complete] Background loading finished."
rm -f "$CACHE/bg_loading"
echo "complete" > "$CACHE/bg_complete"
BGLOADER

# Manual update script
cat > "$PKG_DIR/root/usr/bin/banner_manual_update.sh" <<'MANUALUPDATE'
LOG="/tmp/banner_update.log"
CACHE=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")
# 加载超时配置
if [ -f "/usr/share/banner/timeouts.conf" ]; then
    . /usr/share/banner/timeouts.conf
else
    LOCK_TIMEOUT=60
    CURL_CONNECT_TIMEOUT=10
    CURL_MAX_TIMEOUT=30
fi
# 日志函数（保持不变）
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"

    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    if ! echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null; then

        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null

        touch "$log_file" 2>/dev/null && chmod 644 "$log_file" 2>/dev/null
        return 1
    fi
    
    # 日志轮转(加错误保护)
    local log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
    if [ -s "$log_file" ] && [ "$log_size" -gt 51200 ]; then
        {
            # 使用临时文件避免数据丢失
            tail -n 50 "$log_file" > "${log_file}.tmp" 2>/dev/null && \
            mv "${log_file}.tmp" "$log_file" 2>/dev/null
        } || {
            # 轮转失败,尝试直接截断(保留最后100行)
            tail -n 100 "$log_file" > "${log_file}.new" 2>/dev/null && \
            mv "${log_file}.new" "$log_file" 2>/dev/null
        } || {
            # 彻底失败,清空文件(最后的保护)
            : > "$log_file" 2>/dev/null || true
        }
    fi
    
    return 0
}
# ==================== 🔒 URL验证函数 ====================
validate_url() {
    local url="$1"
    # 检查URL格式
    case "$url" in
        http://*|https://*) 
            # URL必须以http或https开头
            return 0
            ;;
        *)
            log "[✗] Invalid URL format: $url"
            return 1
            ;;
    esac
}
# ==================== 新的 flock 锁机制 ====================

LOCK_FD=200
LOCK_FILE="/var/lock/banner_manual_update.lock"

acquire_lock() {
    local timeout="${1:-60}"
    
    mkdir -p /var/lock 2>/dev/null

    eval "exec $LOCK_FD>&-" 2>/dev/null || true
    
    eval "exec $LOCK_FD>$LOCK_FILE" || {
        log "[ERROR] Failed to open lock file"
        return 1
    }
    
    if flock -w "$timeout" "$LOCK_FD" 2>/dev/null; then
        log "[LOCK] Successfully acquired lock (FD: $LOCK_FD)"
        return 0
    else
        log "[ERROR] Failed to acquire lock after ${timeout}s timeout"
        eval "exec $LOCK_FD>&-" 2>/dev/null || true
        return 1
    fi
}

# 释放锁
release_lock() {
    if [ -n "$LOCK_FD" ]; then
        log "[LOCK] Releasing lock (FD: $LOCK_FD)"
        flock -u "$LOCK_FD" 2>/dev/null
        eval "exec $LOCK_FD>&-"  # 关闭文件描述符
    fi
}

# 设置清理陷阱
cleanup() {
    release_lock
    log "[CLEANUP] Script exiting"
}
trap cleanup EXIT INT TERM

# ==================== 主逻辑开始 ====================

# 检查 UCI 配置
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
    exit 1
fi

# 获取锁（60秒超时）
if ! acquire_lock 60; then
    log "[ERROR] Another instance is running or lock acquisition failed"
    exit 1
fi

# 如果存在 auto_update 锁，清理它（手动更新优先）
AUTO_LOCK_FILE="/var/lock/banner_auto_update.lock"
if [ -f "$AUTO_LOCK_FILE" ]; then
    log "[INFO] Manual update overriding auto-update lock."
    rm -f "$AUTO_LOCK_FILE"
fi

log "========== Manual Update Started =========="

validate_url() {
    case "$1" in
        http://*|https://*) return 0;;
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
        curl -sL --connect-timeout 10 --max-time "$CURL_TIMEOUT" "$SELECTED_URL" -o "$CACHE/banner_new.json" 2>/dev/null
        if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
            log "[√] Selected URL download successful (valid JSON)."
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
                curl -sL --connect-timeout 10 --max-time "$CURL_TIMEOUT" "$url" -o "$CACHE/banner_new.json" 2>/dev/null
                if [ -s "$CACHE/banner_new.json" ] && jq empty "$CACHE/banner_new.json" 2>/dev/null; then
                    log "[√] Fallback URL download successful (valid JSON). Updating selected URL."
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
    ENABLED=$(jq -r '.enabled' "$CACHE/banner_new.json")
    log "[DEBUG] Remote control - enabled field raw value: '$ENABLED'"
    
   if [ "$ENABLED" = "false" ] || [ "$ENABLED" = "0" ]; then
        MSG=$(jq -r '.disable_message // "服务已被管理员远程关闭"' "$CACHE/banner_new.json")
        
        # 设置禁用状态
        uci set banner.banner.bg_enabled='0'
        uci set banner.banner.remote_message="$MSG"
        
        # 清空横幅文本和导航数据(保留背景和联系方式)
        uci set banner.banner.text=""
        uci set banner.banner.banner_texts=""
        uci commit banner
        
        # 删除导航数据缓存(保留背景图缓存)
        rm -f "$CACHE/nav_data.json" 2>/dev/null
        rm -f "$CACHE/banner_new.json" 2>/dev/null
        
        VERIFY=$(uci get banner.banner.bg_enabled)
        log "[!] Service remotely DISABLED. Reason: $MSG"
        log "[DEBUG] Verification - bg_enabled is now: $VERIFY"
        log "[INFO] Banner text and navigation cleared, backgrounds preserved"
        
        log "Restarting uhttpd service to apply changes..."
    /etc/init.d/uhttpd restart >/dev/null 2>&1
    
    # 等待服务完全重启
    sleep 3
    
    # 🔧 强制刷新 LuCI 缓存
    rm -rf /tmp/luci-* 2>/dev/null
    
    # 🔧 强制重新加载 Lua 模块
    killall -HUP uhttpd 2>/dev/null
    
    log "[✓] Service disabled and cache cleared"
    
    exit 0
   else
        log "[DEBUG] Service remains ENABLED (enabled=$ENABLED)"
        TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
        if [ -n "$TEXT" ]; then
            cp "$CACHE/banner_new.json" "$CACHE/nav_data.json"
            uci set banner.banner.text="$TEXT"
            
            CONTACT_EMAIL=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.email' 2>/dev/null)
            CONTACT_TG=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.telegram' 2>/dev/null)
            CONTACT_QQ=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.contact_info.qq' 2>/dev/null)
            
            if [ -n "$CONTACT_EMAIL" ]; then uci set banner.banner.contact_email="$CONTACT_EMAIL"; fi
            if [ -n "$CONTACT_TG" ]; then uci set banner.banner.contact_telegram="$CONTACT_TG"; fi
            if [ -n "$CONTACT_QQ" ]; then uci set banner.banner.contact_qq="$CONTACT_QQ"; fi
            
            uci set banner.banner.color="$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null || echo 'rainbow')"
            uci set banner.banner.banner_texts="$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')"
            
            # 关键修复: 确保启用状态
            uci set banner.banner.bg_enabled='1'
            uci delete banner.banner.remote_message >/dev/null 2>&1
            
            uci set banner.banner.last_update=$(date +%s)
            uci commit banner
           # 清除可能残留的锁文件
            rm -f /tmp/banner_manual_update.lock /tmp/banner_auto_update.lock 2>/dev/null
            uci set banner.banner.last_update=$(date +%s)
            uci commit banner
           # 清除可能残留的锁文件
            rm -f /tmp/banner_manual_update.lock /tmp/banner_auto_update.lock 2>/dev/null
            
            # 🪄 触发背景组加载，自动更新初始化背景
            BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
            /usr/bin/banner_bg_loader.sh "$BG_GROUP" >> /tmp/banner_update.log 2>&1 &
            
            log "[√] Manual update applied successfully."
        else
            log "[×] Update failed: Invalid JSON content (missing 'text' field)."
            rm -f "$CACHE/banner_new.json"
        fi
    fi
else
    log "[×] Update failed: All sources are unreachable or provided invalid data."
    if [ ! -f "$CACHE/nav_data.json" ]; then
        log "[!] No local cache found. Attempting to use built-in default JSON data."
        DEFAULT_JSON_PATH=$(grep -oE '/default/banner_default.json' /usr/lib/ipkg/info/luci-app-banner.list | sed 's|/default/banner_default.json||' | head -n1)/default/banner_default.json
        if [ -f "$DEFAULT_JSON_PATH" ]; then
            cp "$DEFAULT_JSON_PATH" "$CACHE/nav_data.json"
        fi
    fi
fi
MANUALUPDATE

# Auto update script (cron job)
cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'AUTOUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
BOOT_FLAG="/tmp/banner_first_boot"
RETRY_FLAG="/tmp/banner_retry_count"
RETRY_TIMER="/tmp/banner_retry_timer"

# ==================== 🚨 关键修复: 简化日志函数 ====================
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    
    # 确保日志文件存在
    if [ ! -f "$LOG" ]; then
        touch "$LOG" 2>/dev/null && chmod 666 "$LOG" 2>/dev/null
    fi
    
    # 直接写入,减少错误检查
    echo "[$timestamp] $msg" >> "$LOG" 2>/dev/null || echo "[$timestamp] $msg" >&2
    
    # 简化日志轮转
    if [ -f "$LOG" ] && [ $(wc -c < "$LOG" 2>/dev/null || echo 0) -gt 51200 ]; then
        tail -n 50 "$LOG" > "${LOG}.tmp" 2>/dev/null && mv "${LOG}.tmp" "$LOG" 2>/dev/null
    fi
}

# ==================== 🚨 关键修复: 简化网络检查 ====================
check_network() {
    # 方法1: 检查默认路由
    if ip route show default >/dev/null 2>&1; then
        return 0
    fi
    
    # 方法2: 尝试 ping 网关
    local gateway=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
    if [ -n "$gateway" ] && ping -c 1 -W 1 "$gateway" >/dev/null 2>&1; then
        return 0
    fi
    
    # 方法3: 检查网络接口状态
    if ip link show | grep -q 'state UP'; then
        return 0
    fi
    
    return 1
}

# ==================== 🚨 关键修复: 简化锁机制 ====================
LOCK_FD=201
LOCK_FILE="/var/lock/banner_auto_update.lock"

acquire_lock() {
    mkdir -p /var/lock 2>/dev/null
    
    # 清理旧锁文件
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
        if [ $lock_age -gt 300 ]; then
            rm -f "$LOCK_FILE"
            log "[LOCK] Removed stale lock file"
        fi
    fi
    
    # 尝试获取锁
    exec 201>"$LOCK_FILE"
    if flock -n 201; then
        log "[LOCK] Lock acquired"
        return 0
    else
        log "[LOCK] Failed to acquire lock (another instance running)"
        return 1
    fi
}

release_lock() {
    flock -u 201 2>/dev/null
    exec 201>&-
}

cleanup() {
    release_lock
    log "[CLEANUP] Script exiting"
}
trap cleanup EXIT INT TERM

# ==================== 主逻辑 ====================
log "=========================================="
log "Banner Auto Update Script Started"
log "=========================================="

# 获取锁
if ! acquire_lock; then
    log "[ERROR] Another instance is running"
    exit 1
fi

# 检查 UCI
if ! command -v uci >/dev/null 2>&1; then
    log "[ERROR] UCI command not found"
    exit 1
fi

# 检查是否被禁用
BG_ENABLED=$(uci -q get banner.banner.bg_enabled || echo "1")
if [ "$BG_ENABLED" = "0" ]; then
    log "[INFO] Service is disabled, skipping update"
    exit 0
fi

# ==================== 🚨 关键修复: 简化首次启动逻辑 ====================
if [ ! -f "$BOOT_FLAG" ]; then
    log "========== First Boot Auto Update =========="
    
    # 等待网络 (最多30秒)
    log "[BOOT] Waiting for network..."
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt 15 ]; do
        if check_network; then
            log "[BOOT] ✓ Network ready after ${WAIT_COUNT} attempts"
            break
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ $WAIT_COUNT -ge 15 ]; then
        log "[BOOT] ⚠ Network not ready, will retry in 5 minutes"
        echo "$(date +%s)" > "$RETRY_TIMER"
        echo "0" > "$RETRY_FLAG"
        touch "$BOOT_FLAG"
        exit 0
    fi
    
    # 执行首次更新
    log "[BOOT] Executing first boot update..."
    if /usr/bin/banner_manual_update.sh; then
        log "[BOOT] ✓ First boot update successful"
        touch "$BOOT_FLAG"
        rm -f "$RETRY_FLAG" "$RETRY_TIMER"
    else
        log "[BOOT] ✗ First boot update failed, will retry"
        echo "$(date +%s)" > "$RETRY_TIMER"
        echo "0" > "$RETRY_FLAG"
        touch "$BOOT_FLAG"
    fi
    
    exit 0
fi

# ==================== 重试逻辑 ====================
if [ -f "$RETRY_TIMER" ]; then
    RETRY_TIME=$(cat "$RETRY_TIMER" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - RETRY_TIME))
    
    if [ $TIME_DIFF -ge 300 ]; then
        log "========== Retry Update (5min elapsed) =========="
        
        if ! check_network; then
            log "[RETRY] Network still not ready"
            echo "$(date +%s)" > "$RETRY_TIMER"
            exit 0
        fi
        
        if /usr/bin/banner_manual_update.sh; then
            log "[RETRY] ✓ Retry update successful"
            rm -f "$RETRY_FLAG" "$RETRY_TIMER"
        else
            RETRY_COUNT=$(cat "$RETRY_FLAG" 2>/dev/null || echo 0)
            RETRY_COUNT=$((RETRY_COUNT + 1))
            
            if [ $RETRY_COUNT -ge 3 ]; then
                log "[RETRY] Max retries reached, giving up"
                rm -f "$RETRY_FLAG" "$RETRY_TIMER"
            else
                log "[RETRY] Scheduling next retry (attempt $((RETRY_COUNT + 1))/3)"
                echo "$RETRY_COUNT" > "$RETRY_FLAG"
                echo "$(date +%s)" > "$RETRY_TIMER"
            fi
        fi
    fi
    
    exit 0
fi

# ==================== 定期更新逻辑 ====================
LAST_UPDATE=$(uci -q get banner.banner.last_update || echo 0)
CURRENT_TIME=$(date +%s)
INTERVAL=$(uci -q get banner.banner.update_interval || echo 10800)

if [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$INTERVAL" ]; then
    log "[INFO] Update interval not reached, skipping"
    exit 0
fi

log "========== Scheduled Auto Update =========="

if ! check_network; then
    log "[ERROR] Network not available"
    exit 0
fi

/usr/bin/banner_manual_update.sh
if [ $? -ne 0 ]; then
    log "[ERROR] Scheduled update failed"
fi
AUTOUPDATE

# Init script
cat > "$PKG_DIR/root/etc/init.d/banner" <<'INIT'
#!/bin/sh /etc/rc.common
# Copyright (C) 2023 OpenWrt.org
# Patched for robust network detection and update on first boot

START=99
STOP=15

USE_PROCD=1
PROG=/usr/bin/banner_auto_update.sh
LOG_FILE="/tmp/banner_init.log"

log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    echo "[$timestamp] $msg" >> "$LOG_FILE" 2>/dev/null
}

start_service() {
    log "========== Banner Service Starting =========="
    
    # 确保日志文件可写
    touch "$LOG_FILE" 2>/dev/null
    
    # 🎯 关键修复：立即部署内置背景图（开机时）
    if [ -f /usr/share/banner/bg0.jpg ]; then
        mkdir -p /www/luci-static/banner 2>/dev/null
        
        # 如果 current_bg.jpg 不存在，或者文件大小为0，则部署内置背景
        if [ ! -s /www/luci-static/banner/current_bg.jpg ]; then
            cp -f /usr/share/banner/bg0.jpg /www/luci-static/banner/current_bg.jpg 2>/dev/null
            cp -f /usr/share/banner/bg0.jpg /www/luci-static/banner/bg0.jpg 2>/dev/null
            chmod 644 /www/luci-static/banner/*.jpg 2>/dev/null
            log "✓ 开机部署内置背景图完成"
        else
            log "✓ 背景图已存在，跳过部署"
        fi
    else
        log "✗ 警告：找不到内置背景图 /usr/share/banner/bg0.jpg"
    fi
    
    # 启动自动更新的 cron job
    /usr/bin/banner_auto_update.sh >/dev/null 2>&1
    
    # 首次开机网络检测和更新 (在后台运行)
    (
        # 清理可能存在的舊標記
        rm -f /tmp/banner_first_boot_done

        # 延遲5秒開始，避免開機初期過於繁忙
        sleep 5

        # 循環偵測網路，直到成功
        while [ ! -f /tmp/banner_first_boot_done ]; do
            log "正在偵測網路連線 (ping 223.5.5.5)..."

            # 使用 ping 指令檢查公網連線
            if ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1; then
                log "✅ 網路已就緒！準備執行首次更新。"
                
                # 執行真正的手動更新腳本，並將其輸出記錄到更新日誌
                /usr/bin/banner_manual_update.sh >> /tmp/banner_update.log 2>&1
                
                # 建立成功標記，以便結束偵測循環
                touch /tmp/banner_first_boot_done
                
                log "✅ 首次開機更新任務已觸發。"
                break # 成功後退出循環
            else
                # 如果網路未就緒，等待15秒後重試
                log "網路尚未就緒，15秒後重試..."
                sleep 15
            fi
        done
    ) &

    log "========== Banner Service Started (網路巡檢員已在後台運行) =========="
}

# 服務停止函數
stop_service() {
    log "========== Banner Service Stopping =========="
    # 停止由本腳本啟動的後台任務
    # 使用 pkill 更精準地殺掉包含特定參數的進程
    pkill -f "ping -c 1 -W 3 223.5.5.5"
}

# rc.common 會自動處理 start/stop/restart
# 但為了確保清理邏輯被執行，我們明確定義 restart
restart_service() {
    stop_service
    sleep 1
    start_service
}
status() {
    # 標題，清晰地標識了版本
    echo "===== Banner Service Status (Patched v2.0) ====="
    
    # 1. 核心狀態：實時回報「網路巡檢員」的工作狀態
    if pgrep -f "ping -c 1 -W 3 223.5.5.5" >/dev/null; then
        echo "Status: Running (網路巡檢員正在後台偵測網路...)"
    elif [ -f /tmp/banner_first_boot_done ]; then
        echo "Status: Idle (首次開機更新已完成)"
    else
        echo "Status: Idle (服務已啟動，等待巡檢員執行)"
    fi

    # 2. UCI 配置狀態：顯示遠端或手動的啟用/禁用狀態
    local uci_enabled=$(uci -q get banner.banner.bg_enabled || echo 1)
    if [ "$uci_enabled" = "0" ]; then
        local remote_msg=$(uci -q get banner.banner.remote_message)
        echo "UCI Status: Disabled (Reason: ${remote_msg:-手動禁用})"
    else
        echo "UCI Status: Enabled"
    fi
    
    # 3. 上次更新時間：讓您知道內容的新鮮度
    local last_update=$(uci -q get banner.banner.last_update || echo 0)
    if [ "$last_update" = "0" ]; then
        echo "Last Update: Never"
    else
        # 兼容不同系統的 date 命令，非常穩健
        echo "Last Update: $(date -d "@$last_update" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$last_update" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '無法解析時間')"
    fi
    
    echo "---" # 分隔線，讓版面更清晰
    
    # 4. 初始化日誌：快速查看開機過程
    echo "Recent Init Logs (/tmp/banner_init.log):"
    tail -n 5 /tmp/banner_init.log 2>/dev/null || echo "  (No init logs)"
    
    echo "---"
    
    # 5. 更新日誌：快速查看更新是否成功，或失敗原因
    echo "Recent Update Logs (/tmp/banner_update.log):"
    tail -n 5 /tmp/banner_update.log 2>/dev/null || echo "  (No update logs)"
    
    echo "================================================"
}

# rc.common 會自動處理 status，這裡無需定義
# 如果需要自訂 status，可以取消註解
# status() {
#     echo "自訂狀態輸出..."
# }
INIT


# =================== 核心修正 #1：替換整個 banner.lua (再次確認為完整版) ===================
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<'CONTROLLER'
module("luci.controller.banner", package.seeall)

function index()
    entry({"admin", "status", "banner"}, alias("admin", "status", "banner", "display"), _("福利导航"), 98).dependent = false
    entry({"admin", "status", "banner", "display"}, call("action_display"), _("首页"), 1)
    entry({"admin", "status", "banner", "navigation"}, call("action_navigation"), _("导航展示"), 2)
    entry({"admin", "status", "banner", "settings"}, call("action_settings"), _("设置"), 3)
    
    -- 重构为纯 API 接口,供前端 AJAX 调用
    entry({"admin", "status", "banner", "api_update"}, post("api_update")).leaf = true
    entry({"admin", "status", "banner", "api_set_bg"}, post("api_set_bg")).leaf = true
    entry({"admin", "status", "banner", "api_clear_cache"}, post("api_clear_cache")).leaf = true
    entry({"admin", "status", "banner", "api_load_group"}, post("api_load_group")).leaf = true
    entry({"admin", "status", "banner", "api_set_persistent_storage"}, post("api_set_persistent_storage")).leaf = true
    entry({"admin", "status", "banner", "api_set_opacity"}, post("api_set_opacity")).leaf = true
    entry({"admin", "status", "banner", "api_set_carousel_interval"}, post("api_set_carousel_interval")).leaf = true
    entry({"admin", "status", "banner", "api_set_update_url"}, post("api_set_update_url")).leaf = true
    entry({"admin", "status", "banner", "api_reset_defaults"}, post("api_reset_defaults")).leaf = true
    entry({"admin", "status", "banner", "api_clear_logs"}, post("api_clear_logs")).leaf = true
    -- 保留用于文件上传和URL表单提交的旧入口
    entry({"admin", "status", "banner", "do_upload_bg"}, post("action_do_upload_bg")).leaf = true
    entry({"admin", "status", "banner", "do_apply_url"}, post("action_do_apply_url")).leaf = true
end

-- 辅助函数：返回 JSON 响应
local function json_response(data)
    luci.http.prepare_content("application/json" )
    luci.http.write(require("luci.jsonc" ).stringify(data))
end

-- 页面渲染函数 (保持不变)
function action_display()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    -- 🎯 关键：检查是否被禁用（必须在最前面）
    local bg_enabled = uci:get("banner", "banner", "bg_enabled")
    if bg_enabled == "0" then
        local contact_email = uci:get("banner", "banner", "contact_email") or "niwo5507@gmail.com"
        local contact_telegram = uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"
        local contact_qq = uci:get("banner", "banner", "contact_qq") or "183452852"
        luci.template.render("banner/display", { 
            bg_enabled = "0", 
            remote_message = uci:get("banner", "banner", "remote_message") or "服务已被远程禁用",
            contact_email = contact_email,
            contact_telegram = contact_telegram,
            contact_qq = contact_qq
        })
        return
    end
    local nav_data = { nav_tabs = {} }; pcall(function() nav_data = require("luci.jsonc").parse(fs.readfile("/tmp/banner_cache/nav_data.json")) end)
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local text = uci:get("banner", "banner", "text") or "欢迎使用"
    local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50"); if not opacity or opacity < 0 or opacity > 100 then opacity = 50 end
    local banner_texts = uci:get("banner", "banner", "banner_texts") or ""; if banner_texts == "" then banner_texts = text end
    local contact_email = uci:get("banner", "banner", "contact_email") or "niwo5507@gmail.com"
    local contact_telegram = uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"
    local contact_qq = uci:get("banner", "banner", "contact_qq") or "183452852"
    luci.template.render("banner/display", { text = text, color = uci:get("banner", "banner", "color"), opacity = opacity, carousel_interval = uci:get("banner", "banner", "carousel_interval"), current_bg = uci:get("banner", "banner", "current_bg"), bg_enabled = "1", banner_texts = banner_texts, nav_data = nav_data, persistent = persistent, bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner", token = luci.dispatcher.context.authsession, contact_email = contact_email, contact_telegram = contact_telegram, contact_qq = contact_qq })
end

function action_settings()
    local uci = require("uci").cursor()
    local urls = uci:get("banner", "banner", "update_urls") or {}; if type(urls) ~= "table" then urls = { urls } end
    local display_urls = {}; for _, url in ipairs(urls) do local name = "Unknown"; if url:match("github") then name = "GitHub" elseif url:match("gitee") then name = "Gitee" end; table.insert(display_urls, { value = url, display = name }) end
    local log = luci.sys.exec("tail -c 5000 /tmp/banner_update.log 2>/dev/null") or "暫無日誌"; if log == "" then log = "暫無日誌" end
    local bg_log = luci.sys.exec("tail -c 5000 /tmp/banner_bg.log 2>/dev/null") or "暫無日誌"; if bg_log == "" then bg_log = "暫無日誌" end
    luci.template.render("banner/settings", { 
        text = uci:get("banner", "banner", "text"), 
        opacity = uci:get("banner", "banner", "opacity"), 
        carousel_interval = uci:get("banner", "banner", "carousel_interval"), 
        persistent_storage = uci:get("banner", "banner", "persistent_storage"), 
        last_update = uci:get("banner", "banner", "last_update"), 
        remote_message = uci:get("banner", "banner", "remote_message"), 
        display_urls = display_urls, 
        selected_url = uci:get("banner", "banner", "selected_url"), 
        bg_group = uci:get("banner", "banner", "bg_group"), -- 新增
        current_bg = uci:get("banner", "banner", "current_bg"), -- 新增
        token = luci.dispatcher.context.authsession, 
        log = log,
        bg_log = bg_log -- 新增
    })
end


function action_navigation()
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    
    -- 检查是否被禁用
    if uci:get("banner", "banner", "bg_enabled") == "0" then
        local contact_email = uci:get("banner", "banner", "contact_email") or "niwo5507@gmail.com"
        local contact_telegram = uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"
        local contact_qq = uci:get("banner", "banner", "contact_qq") or "183452852"
        luci.template.render("banner/navigation", { 
            bg_enabled = "0", 
            remote_message = uci:get("banner", "banner", "remote_message") or "服务已被远程禁用",
            contact_email = contact_email,
            contact_telegram = contact_telegram,
            contact_qq = contact_qq
        })
        return
    end
    
    -- 加载导航数据
    local nav_data = { nav_tabs = {} }
    pcall(function() 
        nav_data = require("luci.jsonc").parse(fs.readfile("/tmp/banner_cache/nav_data.json")) 
    end)
    
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
    if not opacity or opacity < 0 or opacity > 100 then opacity = 50 end
    
    luci.template.render("banner/navigation", { 
        nav_data = nav_data, 
        persistent = persistent,
        opacity = opacity,
        bg_enabled = "1",
        token = luci.dispatcher.context.authsession
    })
end
-- ================== 以下是重构后的 API 函数 ==================

function api_update()
    -- 修正点：同步执行，等待脚本完成
    local code = luci.sys.call("/usr/bin/banner_manual_update.sh >/dev/null 2>&1")
    json_response({ success = (code == 0), message = "手动更新命令已执行。请稍后刷新页面查看是否已重新启用。" })
end

function api_set_bg()
    local uci = require("uci").cursor()
    local bg = luci.http.formvalue("bg")
    if bg and bg:match("^[0-2]$") then
        uci:set("banner", "banner", "current_bg", bg)
        uci:commit("banner")
        local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
        local src_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
        if not (src_path == "/overlay/banner" or src_path == "/www/luci-static/banner") then
            return json_response({ success = false, message = "Invalid source directory" })
        end
        luci.sys.call(string.format("cp %s/bg%s.jpg /www/luci-static/banner/current_bg.jpg 2>/dev/null", src_path, bg))
        
        -- 强制刷新缓存
        luci.sys.call("sync")
        
        json_response({ success = true, message = "背景已切换为 " .. bg })
    else
        json_response({ success = false, message = "Invalid background index" })
    end
end

function api_clear_cache()
    luci.sys.call("rm -f /tmp/banner_cache/* /overlay/banner/bg*.jpg /www/luci-static/banner/bg*.jpg /www/luci-static/banner/current_bg.jpg")
    json_response({ success = true, message = "缓存已清除" })
end

function api_load_group()
    local uci = require("uci").cursor()
    local group = luci.http.formvalue("group" )
    if group and group:match("^[1-4]$") then
        uci:set("banner", "banner", "bg_group", group)
        uci:commit("banner")
        -- 修正点：同步执行，等待脚本完成
        local code = luci.sys.call(string.format("/usr/bin/banner_bg_loader.sh %s >/dev/null 2>&1", group))
        json_response({ success = (code == 0), message = "背景组 " .. group .. " 加载命令已执行。请稍后刷新页面查看效果。" })
    else
        json_response({ success = false, message = "Invalid group index" })
    end
end

function api_set_persistent_storage()
    local uci = require("uci").cursor()
    local persistent = luci.http.formvalue("persistent_storage" )
    if persistent and persistent:match("^[0-1]$") then
        local old_persistent = uci:get("banner", "banner", "persistent_storage") or "0"
        if persistent ~= old_persistent then
            uci:set("banner", "banner", "persistent_storage", persistent)
            if persistent == "1" then
                luci.sys.call("mkdir -p /overlay/banner && cp -f /www/luci-static/banner/*.jpg /overlay/banner/ 2>/dev/null")
            else
                luci.sys.call("mkdir -p /www/luci-static/banner && cp -f /overlay/banner/*.jpg /www/luci-static/banner/ 2>/dev/null")
            end
            uci:commit("banner")
        end
        json_response({ success = true, message = "永久存储已" .. (persistent == "1" and "启用" or "禁用") })
    else
        json_response({ success = false, message = "Invalid value" })
    end
end

function api_set_opacity()
    local uci = require("uci").cursor()
    local opacity = luci.http.formvalue("opacity" )
    if opacity and tonumber(opacity) and tonumber(opacity) >= 0 and tonumber(opacity) <= 100 then
        uci:set("banner", "banner", "opacity", opacity); uci:commit("banner")
        json_response({ success = true, message = "透明度已设置" })
    else
        json_response({ success = false, message = "Invalid opacity value" })
    end
end

function api_set_carousel_interval()
    local uci = require("uci").cursor()
    local interval = luci.http.formvalue("carousel_interval" )
    if interval and tonumber(interval) and tonumber(interval) >= 1000 and tonumber(interval) <= 30000 then
        uci:set("banner", "banner", "carousel_interval", interval); uci:commit("banner")
        json_response({ success = true, message = "轮播间隔已设置" })
    else
        json_response({ success = false, message = "Invalid interval value" })
    end
end

function api_set_update_url()
    local uci = require("uci").cursor()
    local url = luci.http.formvalue("selected_url" )
    if url and url:match("^https?://" ) then
        uci:set("banner", "banner", "selected_url", url); uci:commit("banner")
        json_response({ success = true, message = "更新源已选择" })
    else
        json_response({ success = false, message = "Invalid URL" })
    end
end

function api_reset_defaults()
    luci.sys.call("rm -f /etc/config/banner && /etc/init.d/banner restart")
    json_response({ success = true, message = "已恢复默认配置，页面即将刷新。" })
end

function action_do_upload_bg()
    local fs = require("nixio.fs")
    local http = require("luci.http")
    local uci = require("uci").cursor()
    local sys = require("luci.sys")
    
    -- ==================== 步骤1: 严格验证 bg_index ====================
    local bg_index = luci.http.formvalue("bg_index") or "0"
    
    -- 白名单验证: 只允许 0, 1, 2
    if not bg_index:match("^[0-2]$") then
        luci.http.status(400, "Invalid background index")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- ==================== 步骤2: 路径白名单验证 ====================
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    
    -- 定义允许的目录白名单
    local allowed_dirs = {
        ["/overlay/banner"] = true,
        ["/www/luci-static/banner"] = true
    }
    
    -- 根据配置选择目标目录
    local dest_dir = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    
    -- 验证目标目录在白名单内
    if not allowed_dirs[dest_dir] then
        luci.http.status(400, "Invalid destination directory")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 创建目录(安全的路径)
    sys.call(string.format("mkdir -p '%s' 2>/dev/null", dest_dir:gsub("'", "'\\''")))
    
    -- ==================== 步骤3: 安全构建文件路径 ====================
    local tmp_file = string.format("%s/bg%s.tmp", dest_dir, bg_index)
    local final_file = string.format("%s/bg%s.jpg", dest_dir, bg_index)
    
    -- 路径穿越检查
    local function is_safe_path(path, base_dir)
        -- 确保路径以基础目录开头
        if path:sub(1, #base_dir) ~= base_dir then
            return false
        end
        -- 确保路径不包含 ../
        if path:match("%.%.") then
            return false
        end
        -- 确保路径不包含多余的斜杠
        if path:match("//") then
            return false
        end
        return true
    end
    
    if not is_safe_path(tmp_file, dest_dir) or not is_safe_path(final_file, dest_dir) then
        luci.http.status(400, "Path traversal detected")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- ==================== 步骤4: 文件上传处理 ====================
    http.setfilehandler(function(meta, chunk, eof)
        if not meta or meta.name ~= "bg_file" then
            return
        end
        
        -- 写入文件块
        if chunk then
            local fp = io.open(tmp_file, "ab")
            if fp then
                fp:write(chunk)
                fp:close()
            else
                -- 文件打开失败
                return
            end
        end
        
        -- 文件上传完成
        if eof then
            local max_size = tonumber(uci:get("banner", "banner", "max_file_size") or "3145728")
            
            -- 验证文件存在和大小
            local file_stat = fs.stat(tmp_file)
            if not file_stat then
                luci.http.status(400, "File upload failed")
                return
            end
            
            if file_stat.size > max_size then
                fs.remove(tmp_file)
                luci.http.status(400, "File size exceeds 3MB")
                return
            end
            
            -- 验证JPEG格式
            if sys.call(string.format("file '%s' | grep -qiE 'JPEG|JPG'", tmp_file:gsub("'", "'\\'''"))) == 0 then
                -- 文件有效,移动到最终位置
                fs.rename(tmp_file, final_file)
                sys.call(string.format("chmod 644 '%s'", final_file:gsub("'", "'\\''")))
                
                -- 同步文件
                local sync_target = (persistent == "1") and "/www/luci-static/banner/" or "/overlay/banner/"
                if persistent == "1" then
                    sys.call(string.format("cp '%s' '%s' 2>/dev/null", 
                        final_file:gsub("'", "'\\''"),
                        sync_target:gsub("'", "'\\''")
                    ))
                end
                
                -- 如果是 bg0,更新当前背景
                if bg_index == "0" then
                    sys.call(string.format("cp '%s' /www/luci-static/banner/current_bg.jpg 2>/dev/null",
                        final_file:gsub("'", "'\\''")
                    ))
                    uci:set("banner", "banner", "current_bg", "0")
                    uci:commit("banner")
                end
            else
                -- 文件格式无效
                fs.remove(tmp_file)
                luci.http.status(400, "Invalid JPEG file")
            end
        end
    end)
    
    -- 重定向回背景设置页面
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
end
function action_do_apply_url()
    local http = require("luci.http")
    local sys = require("luci.sys")
    local uci = require("uci").cursor()
    local fs = require("nixio.fs")
    
    -- 获取用户输入的URL
    local custom_url = luci.http.formvalue("custom_bg_url")
    
    -- URL验证
    if not custom_url or custom_url == "" then
        luci.http.status(400, "URL cannot be empty")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 验证URL格式（必须是HTTPS的JPEG图片）
    if not custom_url:match("^https://.*%.jpe?g$") then
        luci.http.status(400, "Invalid URL format. Must be HTTPS and end with .jpg or .jpeg")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 确定目标目录
    local persistent = uci:get("banner", "banner", "persistent_storage") or "0"
    local dest_dir = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner"
    
    -- 路径白名单验证
    local allowed_dirs = {
        ["/overlay/banner"] = true,
        ["/www/luci-static/banner"] = true
    }
    
    if not allowed_dirs[dest_dir] then
        luci.http.status(400, "Invalid destination directory")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 创建目录
    sys.call(string.format("mkdir -p '%s' 2>/dev/null", dest_dir:gsub("'", "'\\''")))
    
    -- 构建安全的文件路径
    local tmp_file = dest_dir .. "/bg0.tmp"
    local final_file = dest_dir .. "/bg0.jpg"
    
    -- 下载文件
    local max_size = tonumber(uci:get("banner", "banner", "max_file_size") or "3145728")
    local download_cmd = string.format(
        "curl -fsSL --connect-timeout 10 --max-time 30 --max-filesize %d '%s' -o '%s' 2>/dev/null",
        max_size,
        custom_url:gsub("'", "'\\''"),
        tmp_file:gsub("'", "'\\''")
    )
    
    local ret = sys.call(download_cmd)
    
    if ret ~= 0 or not fs.stat(tmp_file) then
        fs.remove(tmp_file)
        luci.http.status(400, "Failed to download image from URL")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 验证文件大小
    local file_stat = fs.stat(tmp_file)
    if not file_stat or file_stat.size > max_size then
        fs.remove(tmp_file)
        luci.http.status(400, "Downloaded file exceeds 3MB limit")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 验证JPEG格式
    if sys.call(string.format("file '%s' | grep -qiE 'JPEG|JPG'", tmp_file:gsub("'", "'\\'''"))) == 0 then
        -- 文件有效，移动到最终位置
        fs.rename(tmp_file, final_file)
        sys.call(string.format("chmod 644 '%s'", final_file:gsub("'", "'\\''")))
        
        -- 同步文件
        if persistent == "1" then
            sys.call("cp '/overlay/banner/bg0.jpg' '/www/luci-static/banner/bg0.jpg' 2>/dev/null")
        end
        
        -- 更新当前背景
        sys.call("cp '" .. final_file:gsub("'", "'\\''") .. "' /www/luci-static/banner/current_bg.jpg 2>/dev/null")
        uci:set("banner", "banner", "current_bg", "0")
        uci:commit("banner")
    else
        -- 文件格式无效
        fs.remove(tmp_file)
        luci.http.status(400, "Downloaded file is not a valid JPEG")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
        return
    end
    
    -- 重定向回背景设置页面
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings")) -- 重定向到 settings
end
function api_clear_logs()
    luci.sys.call("echo '' > /tmp/banner_update.log 2>/dev/null")
    luci.sys.call("echo '' > /tmp/banner_bg.log 2>/dev/null")
    json_response({ success = true, message = "日志已清空" })
end
CONTROLLER

# Global style view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/global_style.htm" <<'GLOBALSTYLE'
<%
local uci = require("uci").cursor()
local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
local alpha = (100 - opacity) / 100
-- 修复点:使用 current_bg.jpg 而非固定的 bg0.jpg
local bg_url = "/luci-static/banner/current_bg.jpg"
%>
<style type="text/css">
html, body {
    background: linear-gradient(rgba(0,0,0,<%=alpha%>), rgba(0,0,0,<%=alpha%>)), 
                url(<%=bg_url%>?t=<%=os.time()%>) center/cover fixed no-repeat !important;
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
.banner-hero { 
    background: rgba(0,0,0,.3); 
    border-radius: 15px; 
    padding: 20px; 
    margin: 20px auto; 
    width: 100%;                    /* 新增：占满父容器宽度 */
    max-width: 1200px;               /* 修改：固定最大宽度 */
    box-sizing: border-box;          /* 新增：包含内边距在总宽度内 */
}
.carousel { position: relative; width: 100%; height: 300px; overflow: hidden; border-radius: 10px; margin-bottom: 20px; }
.carousel img { width: 100%; height: 100%; object-fit: cover; position: absolute; opacity: 0; transition: opacity .5s; }
.carousel img.active { opacity: 1; }
/* 文件轮播样式 - 固定显示15个(3列×5行) */
.file-carousel { position: relative; width: 100%; min-height: 800px; background: rgba(0,0,0,.25); border-radius: 10px; margin-bottom: 20px; padding: 20px; overflow: hidden; }
.carousel-track { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; }
.file-card { min-height: 140px; background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.2); border-radius: 8px; padding: 15px; display: flex; align-items: center; gap: 12px; backdrop-filter: blur(5px); transition: all .3s; }
.file-card:hover { transform: translateY(-3px); background: rgba(255,255,255,.18); border-color: #4fc3f7; }
.file-icon { font-size: 36px; flex-shrink: 0; }
.file-info { flex: 1; min-width: 0; }
.file-name { color: #fff; font-weight: 700; font-size: 15px; margin-bottom: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-desc { color: #ccc; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-size { color: #bbb; font-size: 11px; }
.file-action { flex-shrink: 0; }
.action-btn { padding: 8px 16px; border: 0; border-radius: 5px; font-weight: 700; cursor: pointer; transition: all .3s; font-size: 13px; text-decoration: none; display: inline-block; }
.visit-btn { background: rgba(33,150,243,.9); color: #fff; }
.visit-btn:hover { background: rgba(33,150,243,1); transform: scale(1.05); }
.carousel-controls { display: flex; align-items: center; justify-content: center; gap: 15px; margin-top: 20px; }
.carousel-btn { background: rgba(255,255,255,.15); border: 1px solid rgba(255,255,255,.3); color: #fff; padding: 10px 20px; border-radius: 5px; cursor: pointer; transition: all .3s; font-weight: 700; }
.carousel-btn:hover:not(:disabled) { background: rgba(255,255,255,.25); transform: scale(1.05); }
.carousel-btn:disabled { opacity: .5; cursor: not-allowed; }
.carousel-indicator { color: #fff; font-weight: 700; font-size: 16px; }
@media (max-width: 1024px) {
    .carousel-track { grid-template-columns: repeat(2, 1fr); }
    .file-carousel { min-height: 600px; }
}
@media (max-width: 768px) {
    .carousel-track { grid-template-columns: 1fr; }
    .file-carousel { min-height: 400px; padding: 15px; }
    .file-card { min-height: 120px; }
}
.banner-scroll { padding: 20px; margin-bottom: 30px; text-align: center; font-weight: 700; font-size: 18px; border-radius: 10px; min-height: 60px; display: flex; align-items: center; justify-content: center;
<% if color == 'rainbow' then %>background: linear-gradient(90deg, #ff0000, #ff7f00, #ffff00, #00ff00, #0000ff, #4b0082, #9400d3); background-size: 400% 400%; animation: rainbow 8s ease infinite; color: #fff; text-shadow: 2px 2px 4px rgba(0,0,0,.5)<% else %>background: rgba(255,255,255,.15); color: <%=color%><% end %>
}
@keyframes rainbow { 0%,100% { background-position: 0% 50% } 50% { background-position: 100% 50% } }
.banner-contacts { display: flex; flex-direction: column; gap: 15px; margin-bottom: 30px; }
.contact-card { 
    background: rgba(0,0,0,.3); 
    border: 1px solid rgba(255,255,255,.18); 
    border-radius: 10px; 
    padding: 15px; 
    color: #fff; 
    display: flex; 
    align-items: center; 
    justify-content: space-between; 
    gap: 10px;
    flex-wrap: wrap;                 /* 新增：允许换行 */
}
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
.nav-links { display: none; flex-direction: column; padding: 10px 0; max-height: 300px; overflow-y: auto; }
.nav-links.active { display: flex; }
.nav-links a { display: block; color: #4fc3f7; text-decoration: none; padding: 10px; margin: 5px 0; border-radius: 5px; background: rgba(255,255,255,.1); transition: all .2s; }
.nav-links a:hover { background: rgba(79,195,247,.3); transform: translateX(5px); }
.nav-group:hover .nav-links { display: flex !important; flex-direction: column; }
@media (min-width: 769px) { .nav-group-title { cursor: default; } .nav-links { display: none; } }
.pagination { text-align: center; margin-top: 20px; }
.pagination button { background: rgba(66,139,202,.9); border: 1px solid rgba(255,255,255,.3); color: #fff; padding: 8px 15px; margin: 0 5px; border-radius: 5px; cursor: pointer; }
.pagination button:disabled { background: rgba(100,100,100,.5); cursor: not-allowed; }
.bg-selector { position: fixed; bottom: 30px; right: 30px; display: flex; gap: 12px; z-index: 999; }
.bg-circle { width: 50px; height: 50px; border-radius: 50%; border: 3px solid rgba(255,255,255,.8); background-size: cover; cursor: pointer; transition: all .3s; }
.bg-circle:hover { transform: scale(1.15); border-color: #4fc3f7; }
.disabled-message { background: rgba(217,83,79,.8); color: #fff; padding: 15px; border-radius: 10px; text-align: center; font-weight: 700; margin-bottom: 20px; }
@media (max-width: 1024px) and (min-width: 769px) {
    .banner-hero { padding: 15px; max-width: 90vw; }
    .carousel { height: 280px; }
    .nav-groups { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 768px) {
    .banner-hero { padding: 10px; max-width: 100%; }
    .carousel { height: 200px; }
    .banner-scroll { font-size: 16px; padding: 15px; }
    .copy-btn { padding: 6px 12px; font-size: 14px; }
    .nav-groups { grid-template-columns: 1fr; }
    .bg-selector { bottom: 15px; right: 15px; gap: 8px; }
    .bg-circle { width: 40px; height: 40px; }
}
@media (max-width: 480px) {
    .banner-scroll { font-size: 14px; padding: 12px; min-height: 50px; }
    .contact-card { flex-direction: column; text-align: center; }
    .nav-group { padding: 10px; }
}
</style>

<% if bg_enabled == "0" then %>
    <div class="banner-hero">
        <div class="disabled-message">
            <h3 style="color:#fff;margin-bottom:15px;">⚠️ 服务已暂停</h3>
            <p><%= pcdata(remote_message) %></p>
        </div>
        
        <div class="banner-contacts" style="margin-top:20px;">
            <div class="contact-card"><div class="contact-info"><span>📧 邮箱</span><strong><%=contact_email%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_email%>')">复制</button></div>
            <div class="contact-card"><div class="contact-info"><span>📱 Telegram</span><strong><%=contact_telegram%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_telegram%>')">复制</button></div>
            <div class="contact-card"><div class="contact-info"><span>💬 QQ</span><strong><%=contact_qq%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_qq%>')">复制</button></div>
        </div>
    </div>
    
    <div class="bg-selector">
        <% for i = 0, 2 do %>
        <div class="bg-circle" style="background-image:url(/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>)" onclick="changeBg(<%=i%>)" title="切换背景 <%=i+1%>"></div>
        <% end %>
    </div>
    
<% else %>
    <div class="banner-hero">
        <div class="banner-scroll" id="banner-text"><%= pcdata(text) %></div>
        
        <% if nav_data and nav_data.carousel_files and #nav_data.carousel_files > 0 then %>
        <div class="file-carousel">
            <div class="carousel-track" id="carousel-track">
                <%
                local items_per_page = 15
                local current_page_param = tonumber(luci.http.formvalue("page")) or 1
                local total_items = #nav_data.carousel_files
                local total_pages = math.ceil(total_items / items_per_page)
                if total_pages > 5 then total_pages = 5 end
                if current_page_param > total_pages then current_page_param = 1 end
                local start_idx = (current_page_param - 1) * items_per_page + 1
                local end_idx = math.min(start_idx + items_per_page - 1, math.min(total_items, 75))
                for idx = start_idx, end_idx do
                    local file = nav_data.carousel_files[idx]
                %>
                <div class="file-card">
                    <div class="file-icon">
                        <% if file.type == "pdf" then %>📄
                        <% elseif file.type == "txt" then %>📝
                        <% elseif file.type == "url" then %>🔗
                        <% else %>📦<% end %>
                    </div>
                    <div class="file-info">
                        <div class="file-name"><%=pcdata(file.name)%></div>
                        <div class="file-desc"><%=pcdata(file.desc or '')%></div>
                        <div class="file-size">
                            <% if file.size then %><%=file.size%>
                            <% elseif file.type == "url" then %>链接跳转<% end %>
                        </div>
                    </div>
                    <div class="file-action">
                        <a href="<%=pcdata(file.url)%>" target="_blank" rel="noopener noreferrer" class="action-btn visit-btn">访问</a>
                    </div>
                </div>
                <% end %>
            </div>
            <div class="carousel-controls">
                <button class="carousel-btn" onclick="changePage(<%=current_page_param - 1%>)" <%=current_page_param == 1 and 'disabled' or ''%>>◀ 上一页</button>
                <span class="carousel-indicator"><%=current_page_param%> / <%=total_pages%></span>
                <button class="carousel-btn" onclick="changePage(<%=current_page_param + 1%>)" <%=current_page_param >= total_pages and 'disabled' or ''%>>下一页 ▶</button>
            </div>
        </div>
        <% else %>
        <div class="carousel">
            <% for i = 0, 2 do %><img src="/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>" alt="BG <%=i+1%>" loading="lazy"><% end %>
        </div>
        <% end %>
        
        <div class="banner-contacts">
    <% 
    local contacts = {}
    -- 默认内置联系方式
    table.insert(contacts, {icon="📧", label="邮箱", value=contact_email or "niwo5507@gmail.com"})
    table.insert(contacts, {icon="📱", label="Telegram", value=contact_telegram or "@fgnb111999"})
    table.insert(contacts, {icon="💬", label="QQ", value=contact_qq or "183452852"})
    
    -- 从远程JSON加载额外联系方式
    if nav_data and nav_data.contacts then
        for _, c in ipairs(nav_data.contacts) do
            table.insert(contacts, c)
        end
    end
    
    for _, contact in ipairs(contacts) do
    %>
    <div class="contact-card">
        <div class="contact-info">
            <span><%=contact.icon%> <%=pcdata(contact.label)%></span>
            <strong><%=pcdata(contact.value)%></strong>
        </div>
        <button class="copy-btn" onclick="copyText('<%=pcdata(contact.value)%>')">复制</button>
    </div>
    <% end %>  <!-- 这是循环的结束 -->
    <% end %>  <!-- 这是整个else的结束（这一行是新增的，非常关键！） -->
</div>

<script type="text/javascript">
var images = document.querySelectorAll('.carousel img'), current = 0;
function showImage(index) { images.forEach(function(img, i) { img.classList.toggle('active', i === index); }); }
if (images.length > 1) { showImage(current); setInterval(function() { current = (current + 1) % images.length; showImage(current); }, <%=carousel_interval or 5000%>); } else if (images.length > 0) { showImage(0); }

var bannerTexts = '<%=luci.util.pcdata(banner_texts)%>'.split('|').filter(Boolean), textIndex = 0;
if (bannerTexts.length > 1) {
    var textElem = document.getElementById('banner-text');
    if (textElem) {
        setInterval(function() {
            textIndex = (textIndex + 1) % bannerTexts.length;
            textElem.style.opacity = 0;
            setTimeout(function() { textElem.textContent = bannerTexts[textIndex]; textElem.style.opacity = 1; }, 300);
        }, <%=carousel_interval or 5000%>);
    }
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
    if (window.innerWidth <= 768) {
        // 手机模式下点击标题不折叠，始终展开
        return;
    }
}

// 手机模式初始化：确保当前页的导航组始终展开
function initMobileNav() {
    if (window.innerWidth <= 768) {
        document.querySelectorAll('.nav-group').forEach(function(g) {
            if (g.style.display !== 'none') {
                g.querySelector('.nav-links').classList.add('active');
            }
        });
    }
}

// 页面加载和切换时调用
if (typeof showPage !== 'undefined') {
    var originalShowPage = showPage;
    showPage = function(page) {
        originalShowPage(page);
        initMobileNav();
    };
}
window.addEventListener('DOMContentLoaded', initMobileNav);
window.addEventListener('resize', initMobileNav);

function changeBg(n) {
    var formData = new URLSearchParams();
    formData.append('token', '<%=token%>');
    formData.append('bg', n);
    
    fetch('<%=luci.dispatcher.build_url("admin/status/banner/api_set_bg")%>', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            // 直接刷新页面应用新背景
            window.location.reload();
        } else {
            alert('切换失败: ' + result.message);
        }
    })
    .catch(error => {
        alert('请求失败: ' + error);
    });
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
        alert(success ? '✓ 已复制: ' + text : '✗ 复制失败,请手动复制');
    } catch(e) {
        alert('✗ 复制失败: ' + text);
    }
    document.body.removeChild(textarea);
}

// 手动翻页功能
function changePage(page) {
    window.location.href = window.location.pathname + '?page=' + page;
}
</script>
<%+footer%>
DISPLAYVIEW

# Navigation view
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/navigation.htm" <<'NAVIGATIONVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.nav-container {
    background: rgba(0,0,0,.3);
    border-radius: 15px;
    padding: 20px;
    margin: 20px auto;
    width: 100%;
    max-width: 1200px;
    box-sizing: border-box;
}

.nav-section h2 {
    color: #fff;
    text-align: center;
    margin-bottom: 30px;
    font-size: 28px;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
}

/* 电脑模式：网格布局 */
@media (min-width: 769px) {
    .nav-groups {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 20px;
    }
    
    .nav-group {
        background: rgba(0,0,0,.3);
        border: 1px solid rgba(255,255,255,.15);
        border-radius: 10px;
        padding: 15px;
        transition: all .3s;
    }
    
    .nav-group:hover {
        transform: translateY(-3px);
        border-color: #4fc3f7;
    }
    
    .nav-group-title {
        font-size: 18px;
        font-weight: 700;
        color: #fff;
        text-align: center;
        margin-bottom: 10px;
        padding: 10px;
        background: rgba(102,126,234,.6);
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
    }
    
    .nav-links {
        display: none;
        flex-direction: column;
        padding: 10px 0;
        max-height: 400px;
        overflow-y: auto;
    }
    
    .nav-group:hover .nav-links {
        display: flex !important;
    }
}

/* 手机模式：分页布局 */
@media (max-width: 768px) {
    .nav-groups {
        display: block;
    }
    
    .nav-group {
        background: rgba(0,0,0,.3);
        border: 1px solid rgba(255,255,255,.15);
        border-radius: 10px;
        padding: 15px;
        margin-bottom: 20px;
        display: none; /* 默认隐藏 */
    }
    
    .nav-group.active {
        display: block; /* 只显示当前页 */
    }
    
    .nav-group-title {
        font-size: 18px;
        font-weight: 700;
        color: #fff;
        text-align: center;
        margin-bottom: 15px;
        padding: 12px;
        background: rgba(102,126,234,.6);
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    
    .nav-links {
        display: flex !important; /* 手机模式始终展开 */
        flex-direction: column;
        padding: 10px 0;
        max-height: none; /* 不限制高度 */
        overflow-y: visible;
    }
}

.nav-group-title img {
    width: 24px;
    height: 24px;
    margin-right: 8px;
}

.nav-links a {
    display: block;
    color: #4fc3f7;
    text-decoration: none;
    padding: 12px 15px;
    margin: 5px 0;
    border-radius: 5px;
    background: rgba(255,255,255,.1);
    transition: all .2s;
    font-size: 15px;
}

.nav-links a:hover {
    background: rgba(79,195,247,.3);
    transform: translateX(5px);
}

.pagination {
    text-align: center;
    margin-top: 30px;
    display: none; /* 电脑模式隐藏 */
}

@media (max-width: 768px) {
    .pagination {
        display: block; /* 手机模式显示 */
    }
}

.pagination button {
    background: rgba(66,139,202,.9);
    border: 1px solid rgba(255,255,255,.3);
    color: #fff;
    padding: 10px 20px;
    margin: 0 8px;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 700;
    font-size: 14px;
    transition: all .3s;
}

.pagination button:hover:not(:disabled) {
    background: rgba(66,139,202,1);
    transform: translateY(-2px);
}

.pagination button:disabled {
    background: rgba(100,100,100,.5);
    cursor: not-allowed;
    opacity: 0.5;
}

.page-indicator {
    display: inline-block;
    color: #fff;
    font-weight: 700;
    font-size: 16px;
    vertical-align: middle;
    margin: 0 15px;
}

.disabled-message {
    background: rgba(217,83,79,.8);
    color: #fff;
    padding: 20px;
    border-radius: 10px;
    text-align: center;
    font-weight: 700;
    margin-bottom: 20px;
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
    width: 50px;
    height: 50px;
    border-radius: 50%;
    border: 3px solid rgba(255,255,255,.8);
    background-size: cover;
    cursor: pointer;
    transition: all .3s;
}

.bg-circle:hover {
    transform: scale(1.15);
    border-color: #4fc3f7;
}

@media (max-width: 768px) {
    .bg-selector {
        bottom: 15px;
        right: 15px;
        gap: 8px;
    }
    .bg-circle {
        width: 40px;
        height: 40px;
    }
}
</style>

<% if bg_enabled == "0" then %>
    <div class="nav-container">
        <div class="disabled-message">
            <h3 style="color:#fff;margin-bottom:15px;">⚠️ 服务已暂停</h3>
            <p><%= pcdata(remote_message) %></p>
        </div>
    </div>
<% else %>
    <div class="nav-container">
        <% if nav_data and nav_data.nav_tabs and #nav_data.nav_tabs > 0 then %>
        <div class="nav-section">
            <h2>🚀 快速导航</h2>
            <div class="nav-groups" id="nav-groups">
                <% for i, tab in ipairs(nav_data.nav_tabs) do %>
                <div class="nav-group" data-index="<%=i%>">
                    <div class="nav-group-title">
                        <% if tab.icon then %><img src="<%=pcdata(tab.icon)%>" alt=""><% end %>
                        <%=pcdata(tab.title)%>
                    </div>
                    <div class="nav-links">
                        <% if tab.links and #tab.links > 0 then %>
                            <% for _, link in ipairs(tab.links) do %>
                            <a href="<%=pcdata(link.url)%>" target="_blank" rel="noopener noreferrer" title="<%=pcdata(link.desc or '')%>">
                                <%=pcdata(link.name)%>
                            </a>
                            <% end %>
                        <% else %>
                            <span style="color:#999;padding:10px;">暂无链接</span>
                        <% end %>
                    </div>
                </div>
                <% end %>
            </div>
            
            <div class="pagination">
                <button onclick="changePage(-1)" id="prev-btn">◀ 上一组</button>
                <span class="page-indicator" id="page-info">1 / 1</span>
                <button onclick="changePage(1)" id="next-btn">下一组 ▶</button>
            </div>
        </div>
        <% else %>
        <div style="text-align:center;color:#fff;padding:40px;">
            <p style="font-size:18px;">📭 暂无导航数据</p>
            <p style="color:#aaa;margin-top:10px;">请前往设置页面执行手动更新</p>
        </div>
        <% end %>
    </div>
<% end %>

<div class="bg-selector">
    <% for i = 0, 2 do %>
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>)" onclick="changeBg(<%=i%>)" title="切换背景 <%=i+1%>"></div>
    <% end %>
</div>

<script type="text/javascript">
<% if nav_data and nav_data.nav_tabs and #nav_data.nav_tabs > 0 then %>
var currentPage = 1;
var totalGroups = <%=#nav_data.nav_tabs%>;

function changePage(delta) {
    if (window.innerWidth > 768) return; // 仅手机模式启用分页
    
    currentPage = Math.max(1, Math.min(totalGroups, currentPage + delta));
    showMobilePage(currentPage);
}

function showMobilePage(page) {
    if (window.innerWidth > 768) return;
    
    var groups = document.querySelectorAll('.nav-group');
    groups.forEach(function(group, index) {
        group.classList.toggle('active', (index + 1) === page);
    });
    
    document.getElementById('page-info').textContent = page + ' / ' + totalGroups;
    document.getElementById('prev-btn').disabled = (page === 1);
    document.getElementById('next-btn').disabled = (page === totalGroups);
}

// 响应式处理
function handleResize() {
    if (window.innerWidth <= 768) {
        showMobilePage(currentPage);
    } else {
        // 电脑模式显示所有分组
        document.querySelectorAll('.nav-group').forEach(function(g) {
            g.classList.remove('active');
        });
    }
}

window.addEventListener('DOMContentLoaded', handleResize);
window.addEventListener('resize', handleResize);
<% end %>

function changeBg(n) {
    var formData = new URLSearchParams();
    formData.append('token', '<%=token%>');
    formData.append('bg', n);
    
    fetch('<%=luci.dispatcher.build_url("admin/status/banner/api_set_bg")%>', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            window.location.reload();
        } else {
            alert('切换失败: ' + result.message);
        }
    })
    .catch(error => {
        alert('请求失败: ' + error);
    });
}
</script>
<%+footer%>
NAVIGATIONVIEW
# =================== 核心修正 #2：替換 settings.htm (再次確認為完整版) ===================
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
.cbi-button.spinning, .cbi-button:disabled { pointer-events: none; background: #ccc !important; cursor: not-allowed; }
.cbi-button.spinning:after { content: '...'; display: inline-block; animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.loading-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,.8); display: none; justify-content: center; align-items: center; z-index: 9999; }
.loading-overlay.active { display: flex; }
.spinner { border: 4px solid rgba(255, 255, 255, 0.3); border-top-color: #4fc3f7; border-radius: 50%; width: 50px; height: 50px; margin: 0 auto 20px; animation: spin 1.2s cubic-bezier(0.65, 0, 0.35, 1) infinite; }

/* Toast提示样式 */
.toast { position: fixed; top: 20px; left: 50%; transform: translateX(-50%); padding: 15px 30px; border-radius: 8px; color: #fff; font-weight: 700; z-index: 10000; box-shadow: 0 4px 12px rgba(0,0,0,0.3); transition: opacity 0.3s; animation: slideDown 0.3s ease-out; }
.toast.success { background: rgba(76,175,80,0.95); }
.toast.error { background: rgba(244,67,54,0.95); }
@keyframes slideDown { from { transform: translate(-50%, -100%); opacity: 0; } to { transform: translate(-50%, 0); opacity: 1; } }
</style>

<div class="loading-overlay" id="loadingOverlay">
    <div style="text-align:center;color:#fff">
        <div class="spinner"></div>
        <p>正在处理，请稍候...</p>
    </div>
</div>

<div class="cbi-map">
    <h2>远程更新与背景设置</h2>
    <div class="cbi-section-node">
        <% if remote_message and remote_message ~= "" then %>
        <div style="background:rgba(217,83,79,.8);color:#fff;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center"><%=pcdata(remote_message)%></div>
        <% end %>
        
        <div class="cbi-value">
            <label class="cbi-value-title">背景透明度</label>
            <div class="cbi-value-field">
                <div style="display:flex;align-items:center;gap:10px;">
                    <input type="range" name="opacity" min="0" max="100" value="<%=opacity%>" id="opacity-slider" style="width:60%" onchange="apiCall('api_set_opacity', {opacity: this.value})">
                    <span id="opacity-display" style="color:#fff;"><%=opacity%>%</span>
                </div>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">永久存储背景</label>
            <div class="cbi-value-field">
                <label class="toggle-switch">
                    <input type="checkbox" id="persistent-checkbox" <%=persistent_storage=='1' and ' checked'%> onchange="apiCall('api_set_persistent_storage', {persistent_storage: this.checked ? '1' : '0'})">
                    <span class="toggle-slider"></span>
                </label>
                <span id="persistent-text" style="color:#fff;vertical-align:super;margin-left:10px;"><%=persistent_storage=='1' and '已启用' or '已禁用'%></span>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">轮播间隔(毫秒)</label>
            <div class="cbi-value-field">
                <input type="number" name="carousel_interval" value="<%=carousel_interval%>" min="1000" max="30000" style="width:100px">
                <button class="cbi-button" onclick="apiCall('api_set_carousel_interval', {carousel_interval: this.previousElementSibling.value}, false, this)">应用</button>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">更新源</label>
            <div class="cbi-value-field">
                <select name="selected_url">
                    <% for _, item in ipairs(display_urls) do %>
                    <option value="<%=item.value%>"<%=item.value==selected_url and ' selected'%>><%=item.display%></option>
                    <% end %>
                </select>
                <button class="cbi-button" onclick="apiCall('api_set_update_url', {selected_url: this.previousElementSibling.value}, false, this)">选择</button>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">上次更新</label>
            <div class="cbi-value-field">
                <span style="color:#fff;"><%=last_update=='0' and '从未' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update))%></span>
                <button class="cbi-button" id="manual-update-btn" onclick="apiCall('api_update', {}, true, this)">立即手动更新</button>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">选择背景图组</label>
            <div class="cbi-value-field">
                <select name="group">
                    <% for i = 1, 4 do %>
                    <option value="<%=i%>"<%=bg_group==tostring(i) and ' selected'%>>第 <%=i%> 组 (bg<%=(i-1)*3+1%>-bg<%=i*3%>)</option>
                    <% end %>
                </select>
                <button class="cbi-button" onclick="apiCall('api_load_group', {group: this.previousElementSibling.value}, true, this)">加载背景组</button>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">手动填写背景图链接</label>
            <div class="cbi-value-field">
                <form id="customBgForm" method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
                    <input name="token" type="hidden" value="<%=token%>">
                    <input type="text" name="custom_bg_url" placeholder="https://example.com/image.jpg" style="width:70%">
                    <input type="submit" class="cbi-button" value="应用链接">
                </form>
                <p style="color:#aaa;font-size:12px">📌 仅支持 HTTPS JPG/JPEG 链接 (小于3MB)，应用后覆盖 bg0.jpg</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">从本地上传背景图</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data" id="uploadForm">
                    <input name="token" type="hidden" value="<%=token%>">
                    <select name="bg_index" style="width:80px;margin-right:10px;">
                        <option value="0">bg0.jpg</option>
                        <option value="1">bg1.jpg</option>
                        <option value="2">bg2.jpg</option>
                    </select>
                    <input type="file" name="bg_file" accept="image/jpeg" required>
                    <input type="submit" class="cbi-button" value="上传并应用">
                </form>
                <p style="color:#aaa;font-size:12px">📤 支持上传 3张 JPG (小于3MB)，选择要替换的背景编号，上传后立即生效</p>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">删除缓存图片</label>
            <div class="cbi-value-field">
                <button class="cbi-button cbi-button-remove" onclick="apiCall('api_clear_cache', {}, true, this)">删除缓存</button>
            </div>
        </div>
        
        <div class="cbi-value">
            <label class="cbi-value-title">恢复默认配置</label>
            <div class="cbi-value-field">
                <button class="cbi-button cbi-button-reset" onclick="if(confirm('确定要恢复默认配置吗？')) apiCall('api_reset_defaults', {}, true, this)">恢复默认值</button>
            </div>
        </div>
    </div>
</div>

<!-- 合并后的系统日志区域 -->
<div class="cbi-map" style="margin-top:20px;">
    <h2>系统日志</h2>
    <div class="cbi-section-node">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
            <h3 style="margin:0;">运行日志</h3>
            <button class="cbi-button cbi-button-remove" onclick="clearLogs()">清空日志</button>
        </div>
        <div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:400px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap" id="merged-log-container">
<%
local merged_log = "=== 更新日志 ===\n" .. log .. "\n\n=== 背景加载日志 ===\n" .. bg_log
%><%=pcdata(merged_log)%>
        </div>
    </div>
</div>

<script>
function clearLogs() {
    if (!confirm('确定要清空所有日志吗？')) return;
    
    var formData = new URLSearchParams();
    formData.append('token', '<%=token%>');
    
    fetch('<%=luci.dispatcher.build_url("admin/status/banner/api_clear_logs")%>', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(result => {
        showToast(result.message || '日志已清空', result.success ? 'success' : 'error');
        if (result.success) {
            document.getElementById('merged-log-container').textContent = '日志已清空';
        }
    })
    .catch(error => {
        showToast('清空失败: ' + error.message, 'error');
    });
}
</script>

<script type="text/javascript">
// ==================== Toast 自动消失提示函数 ====================
function showToast(message, type) {
    var toast = document.createElement('div');
    toast.className = 'toast ' + (type || 'success');
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(function() {
        toast.style.opacity = '0';
        setTimeout(function() { 
            if (toast.parentNode) {
                document.body.removeChild(toast); 
            }
        }, 300);
    }, 2500);
}

// ==================== 统一的 API 调用函数 ====================
function apiCall(endpoint, data, reloadOnSuccess, btn) {
    if (btn) btn.classList.add('spinning');
    document.getElementById('loadingOverlay').classList.add('active');

    var formData = new URLSearchParams();
    formData.append('token', '<%=token%>');
    for (var key in data) {
        formData.append(key, data[key]);
    }

    fetch('<%=luci.dispatcher.build_url("admin/status/banner")%>/' + endpoint, {
        method: 'POST',
        body: formData
    })
    .then(response => {
        if (!response.ok) { 
            throw new Error('网络响应异常: ' + response.statusText); 
        }
        return response.json();
    })
    .then(result => {
        if (btn) btn.classList.remove('spinning');
        document.getElementById('loadingOverlay').classList.remove('active');
        
        // 使用 Toast 替代 alert
        var message = result.message || (result.success ? '✓ 操作成功' : '✗ 操作失败');
        showToast(message, result.success ? 'success' : 'error');
        
        if (result.success && reloadOnSuccess) {
            // 针对背景组加载，增加延迟确保文件完全写入
            var delay = (endpoint === 'api_load_group') ? 3000 : 1500;
            setTimeout(function() { window.location.reload(); }, delay);
        }
        
        // 修正点:收到成功响应后,立即更新UI,而不是依赖页面刷新
        if (result.success && endpoint === 'api_set_persistent_storage') {
            document.getElementById('persistent-text').textContent = data.persistent_storage === '1' ? '已启用' : '已禁用';
            document.getElementById('persistent-checkbox').checked = (data.persistent_storage === '1');
        }
    })
    .catch(error => {
        if (btn) btn.classList.remove('spinning');
        document.getElementById('loadingOverlay').classList.remove('active');
        showToast('✗ 请求失败: ' + error.message, 'error');
    });
}

// ==================== 本地表单验证 ====================
document.getElementById('customBgForm').addEventListener('submit', function(e) {
    var url = this.custom_bg_url.value.trim();
    if (!url.match(/^https:\/\/.*\.jpe?g$/i)) {
        e.preventDefault();
        showToast('⚠️ 格式错误:请确保链接以 https:// 开头,并以 .jpg 或 .jpeg 结尾', 'error');
    }
});

document.getElementById('uploadForm').addEventListener('submit', function(e) {
    var file = this.bg_file.files[0];
    if (!file) {
        e.preventDefault();
        showToast('⚠️ 请选择文件', 'error');
        return;
    }
    if (file.size > 3145728) {
        e.preventDefault();
        showToast('⚠️ 文件大小不能超过 3MB', 'error');
        return;
    }
    if (!file.type.match('image/jpeg') && !file.name.match(/\.jpe?g$/i)) {
        e.preventDefault();
        showToast('⚠️ 仅支持 JPG/JPEG 格式', 'error');
    }
});
</script>

<% 
local uci = require("uci").cursor()
local bg_enabled = uci:get("banner", "banner", "bg_enabled") or "1"
if bg_enabled == "1" then 
%>
<style>
.bg-selector { position: fixed; bottom: 30px; right: 30px; display: flex; gap: 12px; z-index: 999; }
.bg-circle { width: 50px; height: 50px; border-radius: 50%; border: 3px solid rgba(255,255,255,.8); background-size: cover; cursor: pointer; transition: all .3s; }
.bg-circle:hover { transform: scale(1.15); border-color: #4fc3f7; }
@media (max-width: 768px) {
    .bg-selector { bottom: 15px; right: 15px; gap: 8px; }
    .bg-circle { width: 40px; height: 40px; }
}
</style>
<div class="bg-selector">
    <% for i = 0, 2 do %>
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>)" onclick="changeBgSettings(<%=i%>)" title="切换背景 <%=i+1%>"></div>
    <% end %>
</div>
<script>
function changeBgSettings(n) {
    var formData = new URLSearchParams();
    formData.append('token', '<%=token%>');
    formData.append('bg', n);
    
    fetch('<%=luci.dispatcher.build_url("admin/status/banner/api_set_bg")%>', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            showToast('✓ 背景已切换到 bg' + n, 'success');
            setTimeout(function() { window.location.reload(); }, 1000);
        } else {
            showToast('✗ 切换失败: ' + result.message, 'error');
        }
    })
    .catch(error => {
        showToast('✗ 请求失败: ' + error.message, 'error');
    });
}
</script>
<% end %>
<%+footer%>
SETTINGSVIEW

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
