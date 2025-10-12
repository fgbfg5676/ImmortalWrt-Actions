
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
if echo "$ABS_PKG_DIR" | grep -q "^/home/runner/work/ImmortalWrt-Actions"; then
    echo "⚙ 允许 GitHub Actions 路径: $ABS_PKG_DIR"
else

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
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"
    
    # URL和IP脱敏(如果需要)
    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    # 防止日志写入失败导致脚本中断
    {
        echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null
    } || {
        # 写入失败,尝试写到stderr,但不中断脚本
        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null || true
        return 1
    }
    
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
log "[√] Removed JPEG files older than $CLEANUP_AGE days from $CACHE_DIR"
CLEANER

cat > "$PKG_DIR/root/usr/bin/banner_manual_update.sh" <<'MANUALUPDATE'
LOG="/tmp/banner_update.log"
CACHE=$(uci -q get banner.banner.cache_dir || echo "/tmp/banner_cache")

# 日志函数（保持不变）
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"
    
    # URL和IP脱敏(如果需要)
    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    # 防止日志写入失败导致脚本中断
    {
        echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null
    } || {
        # 写入失败,尝试写到stderr,但不中断脚本
        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null || true
        return 1
    }
    
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
# ==================== 🔐 URL验证函数 ====================
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

# 获取锁（带超时）
acquire_lock() {
    local timeout="${1:-60}"
    
    # 确保锁文件目录存在
    mkdir -p /var/lock 2>/dev/null
    
    # 打开文件描述符
    eval "exec $LOCK_FD>$LOCK_FILE" || {
        log "[ERROR] Failed to open lock file"
        return 1
    }
    
    # 尝试获取独占锁（带超时）
    if flock -w "$timeout" "$LOCK_FD"; then
        log "[LOCK] Successfully acquired lock (FD: $LOCK_FD)"
        return 0
    else
        log "[ERROR] Failed to acquire lock after ${timeout}s timeout"
        eval "exec $LOCK_FD>&-"  # 关闭文件描述符
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
        http://*|https://*  ) return 0;;
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

cat > "$PKG_DIR/root/usr/bin/banner_auto_update.sh" <<'AUTOUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
BOOT_FLAG="/tmp/banner_first_boot"
RETRY_FLAG="/tmp/banner_retry_count"
RETRY_TIMER="/tmp/banner_retry_timer"

log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"
    
    # URL和IP脱敏(如果需要)
    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    # 防止日志写入失败导致脚本中断
    {
        echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null
    } || {
        # 写入失败,尝试写到stderr,但不中断脚本
        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null || true
        return 1
    }
    
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

# ==================== 新的 flock 锁机制 ====================
LOCK_FD=201  # 使用不同的文件描述符避免冲突
LOCK_FILE="/var/lock/banner_auto_update.lock"

acquire_lock() {
    local timeout="${1:-60}"
    mkdir -p /var/lock 2>/dev/null
    
    eval "exec $LOCK_FD>$LOCK_FILE" || {
        log "[ERROR] Failed to open lock file"
        return 1
    }
    
    if flock -w "$timeout" "$LOCK_FD"; then
        log "[LOCK] Successfully acquired auto-update lock (FD: $LOCK_FD)"
        return 0
    else
        log "[ERROR] Failed to acquire lock after ${timeout}s"
        eval "exec $LOCK_FD>&-"
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
}
trap cleanup EXIT INT TERM

# 网络检查函数（保持不变）
check_network() {
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1; then
        return 0
    fi
    if curl -sL --connect-timeout 5 --max-time 3 --head https://www.baidu.com >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 检查 UCI
if ! command -v uci >/dev/null 2>&1; then
    log "[×] UCI command not found in auto_update script. Exiting."
    exit 0
fi

# 获取锁
if ! acquire_lock 60; then
    log "[ERROR] Failed to acquire lock, exiting"
    exit 1
fi

# 检查是否被禁用
BG_ENABLED=$(uci -q get banner.banner.bg_enabled || echo "1")
if [ "$BG_ENABLED" = "0" ]; then
    log "[INFO] Service is disabled, auto-update skipped"
    exit 0
fi

# ==================== 🚀 开机首次更新机制（时间容错版） ====================
if [ ! -f "$BOOT_FLAG" ]; then
    log "========== 🔥 First Boot Auto Update =========="
    log "[BOOT] Detected first boot after restart, waiting for network..."
    
    # 记录启动时系统运行时间（秒）- 不受时间跳变影响
    BOOT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    echo "$BOOT_UPTIME" > /tmp/banner_boot_uptime
    log "[BOOT] System uptime at boot: ${BOOT_UPTIME}s"
    
    # 等待网络就绪（最多等待60秒）
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt 30 ]; do
        if check_network; then
            log "[BOOT] ✓ Network is ready after ${WAIT_COUNT}s"
            break
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ $WAIT_COUNT -ge 30 ]; then
       log "[BOOT] ⚠ Network not ready after 60s, will retry later"
        # 记录当前系统运行时间作为重试基准
        CURRENT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
        echo "$CURRENT_UPTIME" > "$RETRY_TIMER"
        echo "0" > "$RETRY_FLAG"
        touch "$BOOT_FLAG"
        log "[BOOT] Retry scheduled at uptime: ${CURRENT_UPTIME}s (will check in 5min)"
        exit 0
    fi
    
    # 网络就绪，执行首次更新（最多3次重试）
    RETRY_COUNT=0
    UPDATE_SUCCESS=0
    
    while [ $RETRY_COUNT -lt 3 ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        log "[BOOT] Update attempt $RETRY_COUNT/3..."
        
        if /usr/bin/banner_manual_update.sh; then
            log "[BOOT] ✓ First boot update successful on attempt $RETRY_COUNT"
            UPDATE_SUCCESS=1
            break
        else
            log "[BOOT] × Update attempt $RETRY_COUNT failed"
            [ $RETRY_COUNT -lt 3 ] && sleep 5
        fi
    done
    
    if [ $UPDATE_SUCCESS -eq 1 ]; then
        # 更新成功，清除所有标记
        touch "$BOOT_FLAG"
        rm -f "$RETRY_FLAG" "$RETRY_TIMER"
        log "[BOOT] First boot update completed successfully"
    else
        # 3次都失败，设置5分钟后重试
        log "[BOOT] ⚠ All 3 attempts failed, scheduling retry in 5 minutes"
        CURRENT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
        echo "$CURRENT_UPTIME" > "$RETRY_TIMER"
        echo "0" > "$RETRY_FLAG"
        touch "$BOOT_FLAG"
        log "[BOOT] Retry scheduled at uptime: ${CURRENT_UPTIME}s"
    fi
    
    exit 0
fi

# ==================== ⏰ 5分钟重试机制（基于系统运行时间） ====================
# 辅助函数: 获取启动ID (用于检测重启)
get_boot_id() {
    # 优先使用boot_id (更可靠)
    if [ -f /proc/sys/kernel/random/boot_id ]; then
        cat /proc/sys/kernel/random/boot_id 2>/dev/null
        return 0
    fi
    
    # Fallback: 使用PID 1的启动时间
    if [ -f /proc/1/stat ]; then
        awk '{print $22}' /proc/1/stat 2>/dev/null
        return 0
    fi
    
    # 最后的fallback: 返回空
    echo ""
    return 1
}

# 检测系统是否重启
detect_reboot() {
    local saved_boot_id_file="/tmp/banner_boot_id"
    local current_boot_id=$(get_boot_id)
    
    if [ -z "$current_boot_id" ]; then
        log "[WARN] Cannot determine boot ID, skipping reboot detection"
        return 1  # 无法确定,假设未重启
    fi
    
    if [ -f "$saved_boot_id_file" ]; then
        local saved_boot_id=$(cat "$saved_boot_id_file")
        if [ "$current_boot_id" != "$saved_boot_id" ]; then
            # Boot ID不同,系统已重启
            log "[REBOOT] System reboot detected (boot_id changed)"
            echo "$current_boot_id" > "$saved_boot_id_file"
            return 0  # 检测到重启
        fi
    else
        # 首次运行,保存boot ID
        echo "$current_boot_id" > "$saved_boot_id_file"
    fi
    
    return 1  # 未重启
}

# 重试逻辑主体
if [ -f "$RETRY_TIMER" ]; then
    # 首先检测是否重启
    if detect_reboot; then
        log "[RETRY] System rebooted, clearing retry schedule"
        rm -f "$RETRY_TIMER" "$RETRY_FLAG"
        exit 0
    fi
    
    # 读取保存的uptime
    RETRY_UPTIME=$(cat "$RETRY_TIMER" 2>/dev/null)
    CURRENT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    
    # 基本合法性检查
    if [ -z "$RETRY_UPTIME" ] || [ -z "$CURRENT_UPTIME" ]; then
        log "[ERROR] Invalid uptime values, clearing retry"
        rm -f "$RETRY_TIMER" "$RETRY_FLAG"
        exit 0
    fi
    
    # 检查uptime是否异常(当前uptime远小于保存的uptime)
    # 这可能表示系统重启或时间异常
    if [ "$CURRENT_UPTIME" -lt "$((RETRY_UPTIME - 3600))" ]; then
        log "[RETRY] Uptime anomaly detected (current: ${CURRENT_UPTIME}s < saved: ${RETRY_UPTIME}s - 1h)"
        log "[RETRY] Possible system reboot or time issue, clearing retry schedule"
        rm -f "$RETRY_TIMER" "$RETRY_FLAG"
        exit 0
    fi
    
    # 计算时间差
    TIME_DIFF=$((CURRENT_UPTIME - RETRY_UPTIME))
    
    # 时间差合法性检查(不应该是负数)
    if [ $TIME_DIFF -lt 0 ]; then
        log "[ERROR] Negative time diff: ${TIME_DIFF}s, clearing retry"
        rm -f "$RETRY_TIMER" "$RETRY_FLAG"
        exit 0
    fi
    
    log "[DEBUG] Retry check: current=${CURRENT_UPTIME}s, saved=${RETRY_UPTIME}s, diff=${TIME_DIFF}s"
    
    # 检查是否到达重试时间(5分钟 = 300秒)
    if [ $TIME_DIFF -ge 300 ]; then
        log "========== 🔄 Retry Update (5min elapsed) =========="
        
        # 检查网络
        if ! check_network; then
            log "[RETRY] ⚠ Network still not ready, rescheduling"
            # 重新设置重试时间
            CURRENT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
            echo "$CURRENT_UPTIME" > "$RETRY_TIMER"
            log "[RETRY] Rescheduled at uptime: ${CURRENT_UPTIME}s"
            exit 0
        fi
        
        # 执行重试更新
        log "[RETRY] Executing update attempt..."
        if /usr/bin/banner_manual_update.sh; then
            # 更新成功
            log "[RETRY] ✓ Retry update successful"
            rm -f "$RETRY_FLAG" "$RETRY_TIMER"
            exit 0
        else
            # 更新失败,检查重试次数
            log "[RETRY] ✗ Retry update failed"
            RETRY_COUNT=$(cat "$RETRY_FLAG" 2>/dev/null || echo 0)
            RETRY_COUNT=$((RETRY_COUNT + 1))
            
            if [ $RETRY_COUNT -ge 3 ]; then
                # 达到最大重试次数
                log "[RETRY] ⚠ Max retries (3) reached, giving up until next cycle"
                rm -f "$RETRY_FLAG" "$RETRY_TIMER"
                exit 0
            else
                # 更新重试计数和时间
                echo "$RETRY_COUNT" > "$RETRY_FLAG"
                CURRENT_UPTIME=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
                echo "$CURRENT_UPTIME" > "$RETRY_TIMER"
                log "[RETRY] Scheduled next retry (attempt $((RETRY_COUNT + 1))/3) at uptime: ${CURRENT_UPTIME}s"
                exit 0
            fi
        fi
    else
        # 尚未到重试时间
        log "[DEBUG] Retry not yet due (${TIME_DIFF}s / 300s elapsed)"
    fi
fi

# ==================== 📅 正常3小时间隔更新 ====================
LAST_UPDATE=$(uci -q get banner.banner.last_update || echo 0)
CURRENT_TIME=$(date +%s)
INTERVAL=$(uci -q get banner.banner.update_interval || echo 10800)

if [ $((CURRENT_TIME - LAST_UPDATE)) -lt "$INTERVAL" ]; then
    log "[√] 未到更新时间,跳过自动更新"
    exit 0
fi

log "========== Auto Update Started (3h cycle) =========="

# 检查网络
if ! check_network; then
    log "[×] Network not available, skipping scheduled update"
    exit 0
fi

# 执行更新
/usr/bin/banner_manual_update.sh
if [ $? -ne 0 ]; then
    log "[×] 自动更新失败,查看 /tmp/banner_update.log 获取详情"
fi
AUTOUPDATE

cat > "$PKG_DIR/root/usr/bin/banner_bg_loader.sh" <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}

# 首先加载配置文件（如果存在）
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

# 日志函数
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"
    
    # URL和IP脱敏(如果需要)
    if echo "$msg" | grep -qE 'https?://|[0-9]{1,3}\.[0-9]{1,3}'; then
        msg=$(echo "$msg" | sed -E 's|https?://[^[:space:]]+|[URL]|g' | sed -E 's|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g')
    fi
    
    # 防止日志写入失败导致脚本中断
    {
        echo "[$timestamp] $msg" >> "$log_file" 2>/dev/null
    } || {
        # 写入失败,尝试写到stderr,但不中断脚本
        echo "[$timestamp] LOG_ERROR: $msg" >&2 2>/dev/null || true
        return 1
    }
    
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
# ==================== 🔍 JPEG验证函数 ====================
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
        # 如果没有 file 命令，检查文件头部魔术字节
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

# ==================== 🔐 URL验证函数 ====================
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
LOCK_FD=202  # 使用独立的文件描述符
LOCK_FILE="/var/lock/banner_bg_loader.lock"

acquire_lock() {
    local timeout="${1:-60}"
    mkdir -p /var/lock 2>/dev/null
    
    eval "exec $LOCK_FD>$LOCK_FILE" || {
        log "[ERROR] Failed to open lock file"
        return 1
    }
    
    if flock -w "$timeout" "$LOCK_FD"; then
        log "[LOCK] Successfully acquired bg_loader lock (FD: $LOCK_FD)"
        return 0
    else
        log "[ERROR] Failed to acquire lock after ${timeout}s"
        eval "exec $LOCK_FD>&-"
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

MAX_SIZE=$(uci -q get banner.banner.max_file_size || echo "$MAX_FILE_SIZE")
log "Using max file size limit: $MAX_SIZE bytes."

DOWNLOAD_SUCCESS=0
for i in 0 1 2; do
    KEY="background_$((START_IDX + i))"
    URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
    if [ -n "$URL" ] && validate_url "$URL"; then
        log "  Downloading image for bg${i}.jpg..."
        TMPFILE="$DEST/bg$i.tmp"
        
       log "  Attempting download from: $(echo "$URL" | sed 's|https?://[^/]*/|.../|' )"
        
        # 修复: 简化HTTP请求,使用3次重试
        DOWNLOAD_OK=0
        for attempt in 1 2 3; do
            HTTP_CODE=$(curl -sL --connect-timeout 10 --max-time 20 -w "%{http_code}" -o "$TMPFILE" "$URL" 2>/dev/null)
            
            if [ "$HTTP_CODE" = "200" ] && [ -s "$TMPFILE" ]; then
                DOWNLOAD_OK=1
                log "  [√] Download successful on attempt $attempt (HTTP $HTTP_CODE)"
                break
            else
                log "  [×] Attempt $attempt failed (HTTP: ${HTTP_CODE:-timeout})"
                rm -f "$TMPFILE"
                [ $attempt -lt 3 ] && sleep 2
            fi
        done
        
        if [ $DOWNLOAD_OK -eq 0 ]; then
            log "  [×] All 3 download attempts failed"
            continue
        fi
        
        if [ ! -s "$TMPFILE" ]; then
            log "  [×] Download failed for $URL (empty file)"
            rm -f "$TMPFILE"
            continue
        fi
        
        FILE_SIZE=$(stat -c %s "$TMPFILE" 2>/dev/null || wc -c < "$TMPFILE" 2>/dev/null || echo 999999999)
        if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
            log "  [×] File too large: $FILE_SIZE bytes (limit: $MAX_SIZE)"
            rm -f "$TMPFILE"
            continue
        fi

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
            # 如果启用了永久存储，也复制一份到 Web 目录
            if [ "$(uci -q get banner.banner.persistent_storage)" = "1" ]; then
                cp "$DEST/bg$i.jpg" "$WEB/bg$i.jpg" 2>/dev/null
            fi
            # 总是将第一张成功下载的图片设为默认的 current_bg
            if [ ! -f "$WEB/current_bg.jpg" ]; then
                cp "$DEST/bg$i.jpg" "$WEB/current_bg.jpg" 2>/dev/null
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
    log "[!] No images were downloaded for group ${BG_GROUP}. Keeping existing images if any."
fi

# 强制更新逻辑:如果有新图下载成功,自动设为 bg0
if [ $DOWNLOAD_SUCCESS -eq 1 ]; then
    if [ -s "$DEST/bg0.jpg" ]; then
        # 第一步：更新 current_bg.jpg
        cp "$DEST/bg0.jpg" "$WEB/current_bg.jpg" 2>/dev/null
        log "[✓] Auto-updated current_bg.jpg to bg0.jpg from new group"
        
        # 第二步：🪄 同步到初始化背景目录（关键步骤）
        if [ -d "/usr/share/banner" ]; then
            cp "$DEST/bg0.jpg" "/usr/share/banner/bg0.jpg" 2>/dev/null
            log "[✓] Synced to initialization background (/usr/share/banner/bg0.jpg)"
        fi
        
        # 第三步：更新 UCI 配置
        if command -v uci >/dev/null 2>&1; then
            uci set banner.banner.current_bg='0' 2>/dev/null
            uci commit banner 2>/dev/null
            log "[✓] UCI updated: current_bg set to 0"
        fi
    fi
else
    # 兜底：如果没下载成功，保持现有背景
    if [ ! -s "$WEB/current_bg.jpg" ]; then
        log "[!] current_bg.jpg is missing. Attempting to restore from existing backgrounds."
        for i in 0 1 2; do
            if [ -s "$DEST/bg${i}.jpg" ]; then
                cp "$DEST/bg${i}.jpg" "$WEB/current_bg.jpg" 2>/dev/null
                log "[i] Restored current_bg.jpg from bg${i}.jpg"
                break
            fi
        done
    fi
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

# 强制同步背景图到 web 目录
if [ "$PERSISTENT" = "1" ] && [ -d "/overlay/banner" ]; then
    for i in 0 1 2; do
        if [ -f "/overlay/banner/bg${i}.jpg" ]; then
            cp "/overlay/banner/bg${i}.jpg" "/www/luci-static/banner/bg${i}.jpg" 2>/dev/null
        fi
    done
fi

# 🪄 初始化背景机制：确保开机时总是显示初始化背景
if [ -f "/usr/share/banner/bg0.jpg" ]; then
    # 第一步：初始化 current_bg.jpg（无论是否存在都覆盖）
    cp "/usr/share/banner/bg0.jpg" "/www/luci-static/banner/current_bg.jpg"
    log_msg "[Init Background] Applied initialization background from /usr/share/banner/bg0.jpg"
    
    # 第二步：如果启用了永久存储，也同步到 /overlay/banner/
    if [ "$PERSISTENT" = "1" ]; then
        mkdir -p /overlay/banner
        cp "/usr/share/banner/bg0.jpg" "/overlay/banner/bg0.jpg" 2>/dev/null
        log_msg "[Init Background] Synced to persistent storage"
    fi
else
    log_msg "[Init Background] WARNING: Initialization background not found at /usr/share/banner/bg0.jpg"
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

# =================== 核心修正 #1：替換整個 banner.lua (再次確認為完整版) ===================
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<'CONTROLLER'
module("luci.controller.banner", package.seeall)

function index()
    entry({"admin", "status", "banner"}, alias("admin", "status", "banner", "display"), _("福利导航"), 98).dependent = false
    entry({"admin", "status", "banner", "display"}, call("action_display"), _("首页展示"), 1)
    entry({"admin", "status", "banner", "settings"}, call("action_settings"), _("远程更新"), 2)
    entry({"admin", "status", "banner", "background"}, call("action_background"), _("背景设置"), 3)
    
    -- 重构为纯 API 接口，供前端 AJAX 调用
    entry({"admin", "status", "banner", "api_update"}, post("api_update")).leaf = true
    entry({"admin", "status", "banner", "api_set_bg"}, post("api_set_bg")).leaf = true
    entry({"admin", "status", "banner", "api_clear_cache"}, post("api_clear_cache")).leaf = true
    entry({"admin", "status", "banner", "api_load_group"}, post("api_load_group")).leaf = true
    entry({"admin", "status", "banner", "api_set_persistent_storage"}, post("api_set_persistent_storage")).leaf = true
    entry({"admin", "status", "banner", "api_set_opacity"}, post("api_set_opacity")).leaf = true
    entry({"admin", "status", "banner", "api_set_carousel_interval"}, post("api_set_carousel_interval")).leaf = true
    entry({"admin", "status", "banner", "api_set_update_url"}, post("api_set_update_url")).leaf = true
    entry({"admin", "status", "banner", "api_reset_defaults"}, post("api_reset_defaults")).leaf = true
    
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
    if uci:get("banner", "banner", "bg_enabled") == "0" then
        local contact_email = uci:get("banner", "banner", "contact_email") or "example@email.com"
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
    local contact_email = uci:get("banner", "banner", "contact_email") or "example@email.com"
    local contact_telegram = uci:get("banner", "banner", "contact_telegram") or "@fgnb111999"
    local contact_qq = uci:get("banner", "banner", "contact_qq") or "183452852"
    luci.template.render("banner/display", { text = text, color = uci:get("banner", "banner", "color"), opacity = opacity, carousel_interval = uci:get("banner", "banner", "carousel_interval"), current_bg = uci:get("banner", "banner", "current_bg"), bg_enabled = "1", banner_texts = banner_texts, nav_data = nav_data, persistent = persistent, bg_path = (persistent == "1") and "/overlay/banner" or "/www/luci-static/banner", token = luci.dispatcher.context.authsession, contact_email = contact_email, contact_telegram = contact_telegram, contact_qq = contact_qq })
end

function action_settings()
    local uci = require("uci").cursor()
    local urls = uci:get("banner", "banner", "update_urls") or {}; if type(urls) ~= "table" then urls = { urls } end
    local display_urls = {}; for _, url in ipairs(urls) do local name = "Unknown"; if url:match("github") then name = "GitHub" elseif url:match("gitee") then name = "Gitee" end; table.insert(display_urls, { value = url, display = name }) end
    local log = luci.sys.exec("tail -c 5000 /tmp/banner_update.log 2>/dev/null") or "暫無日誌"; if log == "" then log = "暫無日誌" end
    luci.template.render("banner/settings", { text = uci:get("banner", "banner", "text"), opacity = uci:get("banner", "banner", "opacity"), carousel_interval = uci:get("banner", "banner", "carousel_interval"), persistent_storage = uci:get("banner", "banner", "persistent_storage"), last_update = uci:get("banner", "banner", "last_update"), remote_message = uci:get("banner", "banner", "remote_message"), display_urls = display_urls, selected_url = uci:get("banner", "banner", "selected_url"), token = luci.dispatcher.context.authsession, log = log })
end

function action_background()
    local uci = require("uci").cursor()
    local log = luci.sys.exec("tail -c 5000 /tmp/banner_bg.log 2>/dev/null") or "暫無日誌"; if log == "" then log = "暫無日誌" end
    luci.template.render("banner/background", { bg_group = uci:get("banner", "banner", "bg_group"), opacity = uci:get("banner", "banner", "opacity"), current_bg = uci:get("banner", "banner", "current_bg"), persistent_storage = uci:get("banner", "banner", "persistent_storage"), token = luci.dispatcher.context.authsession, log = log })
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
                if persistent == "1" then
                    local sync_target = string.format("/www/luci-static/banner/bg%s.jpg", bg_index)
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
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
        return
    end
    
    -- 验证URL格式（必须是HTTPS的JPEG图片）
    if not custom_url:match("^https://.*%.jpe?g$") then
        luci.http.status(400, "Invalid URL format. Must be HTTPS and end with .jpg or .jpeg")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
        return
    end
    
    -- 验证文件大小
    local file_stat = fs.stat(tmp_file)
    if not file_stat or file_stat.size > max_size then
        fs.remove(tmp_file)
        luci.http.status(400, "Downloaded file exceeds 3MB limit")
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
        luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
        return
    end
    
    -- 重定向回背景设置页面
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
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
.banner-hero { background: rgba(0,0,0,.3); border-radius: 15px; padding: 20px; margin: 20px auto; max-width: min(1200px, 95vw); }
.carousel { position: relative; width: 100%; height: 300px; overflow: hidden; border-radius: 10px; margin-bottom: 20px; }
.carousel img { width: 100%; height: 100%; object-fit: cover; position: absolute; opacity: 0; transition: opacity .5s; }
.carousel img.active { opacity: 1; }
/* 文件轮播样式 */
.file-carousel { position: relative; width: 100%; min-height: 280px; background: rgba(0,0,0,.25); border-radius: 10px; margin-bottom: 20px; padding: 20px; overflow: hidden; }
.carousel-track { display: flex; gap: 15px; transition: transform .4s ease; }
.file-card { min-width: calc(33.333% - 10px); background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.2); border-radius: 8px; padding: 15px; display: flex; align-items: center; gap: 12px; backdrop-filter: blur(5px); transition: all .3s; }
.file-card:hover { transform: translateY(-3px); background: rgba(255,255,255,.18); border-color: #4fc3f7; }
.file-icon { font-size: 36px; flex-shrink: 0; }
.file-info { flex: 1; min-width: 0; }
.file-name { color: #fff; font-weight: 700; font-size: 15px; margin-bottom: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-desc { color: #ddd; font-size: 12px; margin-bottom: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.file-size { color: #aaa; font-size: 11px; }
.file-action { flex-shrink: 0; }
.action-btn { padding: 8px 16px; border: 0; border-radius: 5px; font-weight: 700; cursor: pointer; transition: all .3s; font-size: 13px; text-decoration: none; display: inline-block; }
.download-btn { background: rgba(76,175,80,.9); color: #fff; }
.download-btn:hover { background: rgba(76,175,80,1); transform: scale(1.05); }
.visit-btn { background: rgba(33,150,243,.9); color: #fff; }
.visit-btn:hover { background: rgba(33,150,243,1); transform: scale(1.05); }
.carousel-controls { display: flex; align-items: center; justify-content: center; gap: 15px; margin-top: 15px; }
.carousel-btn { background: rgba(255,255,255,.15); border: 1px solid rgba(255,255,255,.3); color: #fff; padding: 8px 15px; border-radius: 5px; cursor: pointer; transition: all .3s; font-weight: 700; }
.carousel-btn:hover { background: rgba(255,255,255,.25); transform: scale(1.05); }
.carousel-btn:disabled { opacity: .5; cursor: not-allowed; }
.carousel-indicator { color: #fff; font-weight: 700; }

/* 响应式 */
@media (max-width: 1024px) {
    .file-card { min-width: calc(50% - 7.5px); }
}
@media (max-width: 768px) {
    .file-carousel { min-height: 240px; padding: 15px; }
    .file-card { min-width: 100%; flex-direction: column; text-align: center; }
    .file-info { width: 100%; }
    .file-action { width: 100%; }
    .action-btn { width: 100%; }
}
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
                <% for idx, file in ipairs(nav_data.carousel_files) do %>
                <div class="file-card" data-index="<%=idx%>">
                    <div class="file-icon">
                        <% if file.type == "pdf" then %>
                            📄
                        <% elseif file.type == "txt" then %>
                            📝
                        <% elseif file.type == "url" then %>
                            🔗
                        <% else %>
                            📦
                        <% end %>
                    </div>
                    <div class="file-info">
                        <div class="file-name"><%=pcdata(file.name)%></div>
                        <div class="file-desc"><%=pcdata(file.desc or '')%></div>
                        <div class="file-size">
                            <% if file.size then %>
                                <%=file.size%>
                            <% elseif file.type == "url" then %>
                                链接跳转
                            <% end %>
                        </div>
                    </div>
                    <div class="file-action">
                        <% if file.type == "url" then %>
                            <a href="<%=pcdata(file.url)%>" target="_blank" rel="noopener noreferrer" class="action-btn visit-btn">访问</a>
                        <% else %>
                            <button class="action-btn download-btn" onclick="downloadFile('<%=pcdata(file.url)%>', '<%=pcdata(file.name)%>')">下载</button>
                        <% end %>
                    </div>
                </div>
                <% end %>
            </div>
            <div class="carousel-controls">
                <button class="carousel-btn prev-btn" onclick="slideCarousel(-1)">◀</button>
                <span class="carousel-indicator" id="carousel-indicator">1 / 1</span>
                <button class="carousel-btn next-btn" onclick="slideCarousel(1)">▶</button>
            </div>
        </div>
        <% else %>
        <div class="carousel">
            <% for i = 0, 2 do %><img src="/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>" alt="BG <%=i+1%>" loading="lazy"><% end %>
        </div>
        <% end %>
        
        <div class="banner-contacts">
            <div class="contact-card"><div class="contact-info"><span>📧 邮箱</span><strong><%=contact_email%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_email%>')">复制</button></div>
            <div class="contact-card"><div class="contact-info"><span>📱 Telegram</span><strong><%=contact_telegram%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_telegram%>')">复制</button></div>
            <div class="contact-card"><div class="contact-info"><span>💬 QQ</span><strong><%=contact_qq%></strong></div><button class="copy-btn" onclick="copyText('<%=contact_qq%>')">复制</button></div>
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
                        <a href="<%=pcdata(link.url)%>" target="_blank" rel="noopener noreferrer" title="<%=pcdata(link.desc or '')%>"><%=pcdata(link.name)%></a>
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
        el.querySelector('.nav-links').classList.toggle('active'); 
    }
}

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
// 文件轮播功能
var carouselIndex = 0;
var carouselItems = document.querySelectorAll('.file-card').length;
var carouselItemsPerView = window.innerWidth > 1024 ? 3 : (window.innerWidth > 768 ? 2 : 1);

function slideCarousel(direction) {
    var track = document.getElementById('carousel-track');
    var indicator = document.getElementById('carousel-indicator');
    if (!track || !indicator) return;
    
    carouselIndex += direction;
    var maxIndex = Math.ceil(carouselItems / carouselItemsPerView) - 1;
    
    if (carouselIndex < 0) carouselIndex = 0;
    if (carouselIndex > maxIndex) carouselIndex = maxIndex;
    
    var cardWidth = track.querySelector('.file-card').offsetWidth;
    var gap = 15;
    var offset = -(carouselIndex * carouselItemsPerView * (cardWidth + gap));
    track.style.transform = 'translateX(' + offset + 'px)';
    
    indicator.textContent = (carouselIndex + 1) + ' / ' + (maxIndex + 1);
    
    document.querySelector('.prev-btn').disabled = (carouselIndex === 0);
    document.querySelector('.next-btn').disabled = (carouselIndex === maxIndex);
}

// 自动轮播
if (carouselItems > carouselItemsPerView) {
    setInterval(function() {
        var maxIndex = Math.ceil(carouselItems / carouselItemsPerView) - 1;
        if (carouselIndex >= maxIndex) {
            carouselIndex = -1;
        }
        slideCarousel(1);
    }, 5000);
}

// 下载文件函数
function downloadFile(url, filename) {
    // 显示下载提示
    var loadingMsg = document.createElement('div');
    loadingMsg.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:rgba(0,0,0,.8);color:#fff;padding:20px 40px;border-radius:10px;z-index:9999;font-weight:700;';
    loadingMsg.textContent = '正在下载 ' + filename + '...';
    document.body.appendChild(loadingMsg);
    
    // 创建隐藏的下载链接
    var link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // 2秒后移除提示
    setTimeout(function() {
        document.body.removeChild(loadingMsg);
    }, 2000);
}

// 响应式调整
window.addEventListener('resize', function() {
    carouselItemsPerView = window.innerWidth > 1024 ? 3 : (window.innerWidth > 768 ? 2 : 1);
    carouselIndex = 0;
    slideCarousel(0);
});

// 初始化
if (document.querySelector('.file-carousel')) {
    slideCarousel(0);
}
</script>
<%+footer%>
DISPLAYVIEW
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
</style>
<div class="cbi-map">
    <h2>远程更新设置</h2>
    <div class="cbi-section-node">
        <% if remote_message and remote_message ~= "" then %>
        <div style="background:rgba(217,83,79,.8);color:#fff;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center"><%=pcdata(remote_message)%></div>
        <% end %>
        <div class="cbi-value"><label class="cbi-value-title">背景透明度</label><div class="cbi-value-field">
            <div style="display:flex;align-items:center;gap:10px;">
                <input type="range" name="opacity" min="0" max="100" value="<%=opacity%>" id="opacity-slider" style="width:60%" onchange="apiCall('api_set_opacity', {opacity: this.value})">
                <span id="opacity-display" style="color:#fff;"><%=opacity%>%</span>
            </div>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">永久存储背景</label><div class="cbi-value-field">
            <label class="toggle-switch"><input type="checkbox" id="persistent-checkbox" <%=persistent_storage=='1' and ' checked'%> onchange="apiCall('api_set_persistent_storage', {persistent_storage: this.checked ? '1' : '0'})"><span class="toggle-slider"></span></label>
            <span id="persistent-text" style="color:#fff;vertical-align:super;margin-left:10px;"><%=persistent_storage=='1' and '已启用' or '已禁用'%></span>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">轮播间隔(毫秒)</label><div class="cbi-value-field">
            <input type="number" name="carousel_interval" value="<%=carousel_interval%>" min="1000" max="30000" style="width:100px">
            <button class="cbi-button" onclick="apiCall('api_set_carousel_interval', {carousel_interval: this.previousElementSibling.value}, false, this)">应用</button>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">更新源</label><div class="cbi-value-field">
            <select name="selected_url"><% for _, item in ipairs(display_urls) do %><option value="<%=item.value%>"<%=item.value==selected_url and ' selected'%>><%=item.display%></option><% end %></select>
            <button class="cbi-button" onclick="apiCall('api_set_update_url', {selected_url: this.previousElementSibling.value}, false, this)">选择</button>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">上次更新</label><div class="cbi-value-field"><input readonly value="<%=last_update=='0' and '从未' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update))%>"></div></div>
        <div class="cbi-value"><div class="cbi-value-field">
            <button class="cbi-button" id="manual-update-btn" onclick="apiCall('api_update', {}, true, this)">立即手动更新</button>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">恢复默认配置</label><div class="cbi-value-field">
            <button class="cbi-button cbi-button-reset" onclick="if(confirm('确定要恢复默认配置吗？')) apiCall('api_reset_defaults', {}, true, this)">恢复默认值</button>
        </div></div>
        <h3>更新日志</h3><div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap" id="log-container"><%=pcdata(log)%></div>
    </div>
</div>
<script type="text/javascript">
    // 统一的 API 调用函数
    function apiCall(endpoint, data, reloadOnSuccess, btn) {
        if (btn) btn.classList.add('spinning');

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
            if (!response.ok) { throw new Error('Network response was not ok: ' + response.statusText); }
            return response.json();
        })
        .then(result => {
            if (btn) btn.classList.remove('spinning');
            alert(result.message || (result.success ? '操作成功' : '操作失败'));
            if (result.success && reloadOnSuccess) {
                // 延迟刷新，给后台留出足够的时间
                setTimeout(function() { window.location.reload(); }, 1500);
            }
            // 修正点：收到成功响应后，立即更新UI，而不是依赖页面刷新
            if (result.success && endpoint === 'api_set_persistent_storage') {
                document.getElementById('persistent-text').textContent = data.persistent_storage === '1' ? '已启用' : '已禁用';
                document.getElementById('persistent-checkbox').checked = (data.persistent_storage === '1');
            }
        })
        .catch(error => {
            if (btn) btn.classList.remove('spinning');
            alert('请求失败: ' + error);
        });
    }

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
<% end %>
<%+footer%>
SETTINGSVIEW

# =================== 核心修正 #3：替換 background.htm (完整版) ===================
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/background.htm" <<'BGVIEW'
<%+header%>
<%+banner/global_style%>
<style>
.loading-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,.8); display: none; justify-content: center; align-items: center; z-index: 9999; }
.loading-overlay.active { display: flex; }
.spinner { border: 4px solid rgba(255, 255, 255, 0.3); border-top-color: #4fc3f7; border-radius: 50%; width: 50px; height: 50px; margin: 0 auto 20px; animation: spin 1.2s cubic-bezier(0.65, 0, 0.35, 1) infinite; }
@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
.cbi-button.spinning, .cbi-button:disabled { pointer-events: none; background: #ccc !important; cursor: not-allowed; }
.cbi-button.spinning:after { content: '...'; display: inline-block; animation: spin 1s linear infinite; }
</style>
<div class="loading-overlay" id="loadingOverlay"><div style="text-align:center;color:#fff"><div class="spinner"></div><p>正在处理，请稍候...</p></div></div>
<div class="cbi-map">
    <h2>背景图设置</h2>
    <div class="cbi-section-node">
        <div class="cbi-value"><label class="cbi-value-title">选择背景图组</label><div class="cbi-value-field">
            <select name="group">
                <% for i = 1, 4 do %><option value="<%=i%>"<%=bg_group==tostring(i) and ' selected'%>><%=i..'-'..i*3%></option><% end %>
            </select>
            <button class="cbi-button" onclick="apiCall('api_load_group', {group: this.previousElementSibling.value}, true, this)">加载背景组</button>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">手动填写背景图链接</label><div class="cbi-value-field">
            <form id="customBgForm" method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
                <input name="token" type="hidden" value="<%=token%>">
                <input type="text" name="custom_bg_url" placeholder="https://..." style="width:70%">
                <input type="submit" class="cbi-button" value="应用链接">
            </form>
            <p style="color:#aaa;font-size:12px">📌 仅支持 HTTPS JPG/JPEG 链接 (小于3MB ), 应用后覆盖 bg0.jpg</p>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">从本地上传背景图</label><div class="cbi-value-field">
            <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data" id="uploadForm">
                <input name="token" type="hidden" value="<%=token%>">
                <select name="bg_index" style="width:80px;margin-right:10px;"><option value="0">bg0.jpg</option><option value="1">bg1.jpg</option><option value="2">bg2.jpg</option></select>
                <input type="file" name="bg_file" accept="image/jpeg" required>
                <input type="submit" class="cbi-button" value="上传并应用">
            </form>
            <p style="color:#aaa;font-size:12px">📤 支持上传3张 JPG (小于3MB), 选择要替换的背景编号,上传后立即生效</p>
        </div></div>
        <div class="cbi-value"><label class="cbi-value-title">删除缓存图片</label><div class="cbi-value-field">
            <button class="cbi-button cbi-button-remove" onclick="apiCall('api_clear_cache', {}, true, this)">删除缓存</button>
        </div></div>
        <h3>背景日志</h3>
        <div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap"><%=pcdata(log)%></div>
    </div>
</div>
<script type="text/javascript">
    // 统一的 API 调用函数
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
            if (!response.ok) { throw new Error('Network response was not ok: ' + response.statusText); }
            return response.json();
        })
        .then(result => {
            if (btn) btn.classList.remove('spinning');
            document.getElementById('loadingOverlay').classList.remove('active');
            alert(result.message || (result.success ? '操作成功' : '操作失败'));
            if (result.success && reloadOnSuccess) {
                // 针对背景组加载，增加延迟确保文件完全写入
                var delay = (endpoint === 'api_load_group') ? 3000 : 1500;
                setTimeout(function() { window.location.reload(); }, delay);
            }
        })
        .catch(error => {
            if (btn) btn.classList.remove('spinning');
            document.getElementById('loadingOverlay').classList.remove('active');
            alert('请求失败: ' + error);
        });
    }

    // 本地表单验证 (保持不变)
    document.getElementById('customBgForm').addEventListener('submit', function(e) {
        var url = this.custom_bg_url.value.trim();
        if (!url.match(/^https:\/\/.*\.jpe?g$/i  )) {
            e.preventDefault();
            alert('⚠️ 格式錯誤！請確保鏈接以 https:// 開頭  ，並以 .jpg 或 .jpeg 結尾。');
        }
    });

    document.getElementById('uploadForm').addEventListener('submit', function(e) {
        var file = this.bg_file.files[0];
        if (!file) {
            e.preventDefault();
            alert('⚠️ 请选择文件');
            return;
        }
        if (file.size > 3145728) {
            e.preventDefault();
            alert('⚠️ 文件大小不能超过 3MB');
            return;
        }
        if (!file.type.match('image/jpeg') && !file.name.match(/\.jpe?g$/i)) {
            e.preventDefault();
            alert('⚠️ 仅支持 JPG/JPEG 格式');
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
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg<%=i%>.jpg?t=<%=os.time()%>)" onclick="changeBgBackground(<%=i%>)" title="切换背景 <%=i+1%>"></div>
    <% end %>
</div>
<script>
function changeBgBackground(n) {
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
<% end %>
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
