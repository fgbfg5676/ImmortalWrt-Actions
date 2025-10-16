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
        echo "✖ 错误：无法规范化路径 \'$PKG_DIR\'"
        exit 1
    }
else
    echo "⚠ 警告：系统未安装 realpath，路径安全检查可能不够完善。"
    # Fallback: 手动规范化（不完美但聊胜于无）
    ABS_PKG_DIR=$(cd "$(dirname "$PKG_DIR")" 2>/dev/null && pwd)/$(basename "$PKG_DIR") || {
        echo "✖ 错误：路径无效 \'$PKG_DIR\'"
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
    echo "âš™ å…è®¸æœ¬åœ°å¼€å\'è·¯å¾„: $ABS_PKG_DIR"
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
    "/lib/"*|\
    "/boot"|\
    "/boot/"*|\
    "$HOME"|\
    "$HOME/"*)
        echo "✖ 错误：目标目录指向了危险的系统路径 (\'$ABS_PKG_DIR\')，已终止操作。"
        exit 1
        ;;
esac
fi
# 检查路径穿越字符（所有可能的形式）
if echo "$PKG_DIR" | grep -qE \'\.\./|\.\.$|/\.\.\'; then
    echo "✖ 错误：目标目录包含非法的路径穿越符 \'..\' (\'$PKG_DIR\')，已终止操作。"
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
    echo "✖ 错误：目标路径 \'$ABS_PKG_DIR\' 不在允许的目录范围内。"
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
cat > "$PKG_DIR/Makefile" <<\'MAKEFILE\'
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
echo "调试：Makefile 生成成功，大小 $(wc -c < \"$PKG_DIR/Makefile\") 字节"
# UCI Configuration
cat > "$PKG_DIR/root/etc/config/banner" <<\'UCICONF\'
config banner \'banner\'
	option text \'🎉 福利导航的内容会不定时更新，关注作者不迷路\'
	option color \'rainbow\'
	option opacity \'50\' # 0-100
	option carousel_interval \'5000\' # 1000-30000 (ms)
	option bg_group \'1\' # 1-4
	option bg_enabled \'1\' # 0 or 1
	option persistent_storage \'0\' # 0 or 1
	option current_bg \'0\' # 0-2
	list update_urls \'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json\'
	list update_urls \'https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json\'
	option selected_url \'https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json\'
	option update_interval \'10800\' # seconds
	option last_update \'0\'
	option banner_texts \'\'
	option remote_message \'\'
	option cache_dir \'/tmp/banner_cache\' # Cache directory
	option web_dir \'/www/luci-static/banner\' # Web directory
	option persistent_dir \'/overlay/banner\' # Persistent storage directory
	option curl_timeout \'15\' # seconds
	option wait_timeout \'5\' # seconds
	option cleanup_age \'3\' # days
	option restart_delay \'15\' # seconds
	option contact_email \'niwo5507@gmail.com\'
	option contact_telegram \'@fgnb111999\'
	option contact_qq \'183452852\'
UCICONF

cat > "$PKG_DIR/root/usr/share/banner/timeouts.conf" <<\'TIMEOUTS\'

LOCK_TIMEOUT=60

NETWORK_WAIT_TIMEOUT=60

CURL_CONNECT_TIMEOUT=10
CURL_MAX_TIMEOUT=30

RETRY_INTERVAL=5

BOOT_RETRY_INTERVAL=300
TIMEOUTS

# 創建一個全局配置文件，用於存儲可配置的變數
mkdir -p "$PKG_DIR/root/usr/share/banner"
cat > "$PKG_DIR/root/usr/share/banner/config.sh" <<\'CONFIGSH\'
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
cat > "$PKG_DIR/root/usr/bin/banner_cache_cleaner.sh" <<\'CLEANER\'
#!/bin/sh
LOG="/tmp/banner_update.log"

log() {
    local msg="$1"
    local timestamp=$(date \'+%Y-%m-%d %H:%M:%S\' 2>/dev/null || date)
    local log_file="${LOG:-/tmp/banner_update.log}"

    if echo "$msg" | grep -qE \'https?://|[0-9]{1,3}\.[0-9]{1,3}\'; then
        msg=$(echo "$msg" | sed -E \'s|https?://[^[:space:]]+|[URL]|g\' | sed -E \'s|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g\')
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
find "$CACHE_DIR" -type f -name \'*.jpg\' -mtime +"$CLEANUP_AGE" -delete
if [ $? -eq 0 ]; then
    log "✓ Old JPG files in cache cleaned up successfully."
else
    log "✖ Failed to clean up old JPG files in cache."
fi

# 清理旧的JSON文件
find "$CACHE_DIR" -type f -name \'*.json\' -mtime +"$CLEANUP_AGE" -delete
if [ $? -eq 0 ]; then
    log "✓ Old JSON files in cache cleaned up successfully."
else
    log "✖ Failed to clean up old JSON files in cache.""
fi

log "========== Cache Cleanup Finished =========="
CLEANER

# Update script
cat > "$PKG_DIR/root/usr/bin/banner_update.sh" <<\'UPDATER\'
#!/bin/sh

. /usr/share/banner/config.sh
. /usr/share/banner/timeouts.conf

log() {
    local msg="$1"
    local timestamp=$(date \'+%Y-%m-%d %H:%M:%S\' 2>/dev/null || date)
    local log_file="${LOG_FILE:-/tmp/banner_update.log}"

    if echo "$msg" | grep -qE \'https?://|[0-9]{1,3}\.[0-9]{1,3}\'; then
        msg=$(echo "$msg" | sed -E \'s|https?://[^[:space:]]+|[URL]|g\' | sed -E \'s|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g\')
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



# --- 辅助函数 --- START

# 获取一个随机的缓存文件名
get_random_cache_filename() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16
}

# 检查网络连接
check_network() {
    log "Checking network connectivity..."
    local timeout=$NETWORK_WAIT_TIMEOUT
    local count=0
    while [ $count -lt $timeout ]; do
        if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            log "Network is up."
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    log "Network is down after $timeout seconds."
    return 1
}

# 获取并验证 JSON 数据
fetch_and_validate_json() {
    local url="$1"
    local cache_file="$2"
    log "Fetching JSON from: $url"

    local tmp_json_file="$CACHE_DIR/$(get_random_cache_filename).json"

    if ! curl -fLsS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIMEOUT" "$url" -o "$tmp_json_file"; then
        log "✖ Failed to download JSON from $url"
        rm -f "$tmp_json_file"
        return 1
    fi

    # 检查文件大小
    local file_size=$(wc -c < "$tmp_json_file" 2>/dev/null || echo 0)
    if [ "$file_size" -eq 0 ]; then
        log "✖ Downloaded JSON file is empty: $url"
        rm -f "$tmp_json_file"
        return 1
    fi
    if [ "$file_size" -gt "$MAX_FILE_SIZE" ]; then
        log "✖ Downloaded JSON file is too large ($file_size bytes): $url"
        rm -f "$tmp_json_file"
        return 1
    fi

    # 验证 JSON 格式
    if ! jq -e . >/dev/null 2>&1 < "$tmp_json_file"; then
        log "✖ Invalid JSON format for $url"
        rm -f "$tmp_json_file"
        return 1
    fi

    mv "$tmp_json_file" "$cache_file"
    log "✓ Successfully fetched and validated JSON from $url"
    return 0
}

# 更新 UCI 配置
update_uci_config() {
    local key="$1"
    local value="$2"
    local current_value=$(uci -q get banner.banner."$key")

    if [ "$current_value" != "$value" ]; then
        uci set banner.banner."$key"="$value"
        log "Updated UCI: banner.banner.$key = $value"
        return 0
    fi
    return 1
}

# 更新 UCI 列表配置
update_uci_list() {
    local key="$1"
    shift
    local new_values=("$@")
    local current_values=($(uci -q get banner.banner."$key"))

    # 比较数组内容
    local changed=0
    if [ ${#new_values[@]} -ne ${#current_values[@]} ]; then
        changed=1
    else
        for i in "${!new_values[@]}"; do
            if [ "${new_values[$i]}" != "${current_values[$i]}" ]; then
                changed=1
                break
            fi
        done
    fi

    if [ $changed -eq 1 ]; then
        uci del_list banner.banner."$key" 2>/dev/null
        for val in "${new_values[@]}"; do
            uci add_list banner.banner."$key"="$val"
        done
        log "Updated UCI list: banner.banner.$key = ${new_values[*]}"
        return 0
    fi
    return 1
}

# --- 辅助函数 --- END


log "========== Banner Update Script Started =========="

# 确保缓存目录存在
mkdir -p "$CACHE_DIR"
chmod 755 "$CACHE_DIR"

# 检查网络连接
if ! check_network; then
    log "✖ Network is not available, exiting."
    exit 1
fi

# 获取配置的更新 URL 列表
UPDATE_URLS=($(uci -q get banner.banner.update_urls))
SELECTED_URL=$(uci -q get banner.banner.selected_url)

if [ -z "$SELECTED_URL" ]; then
    log "⚠ No selected_url found in UCI config, trying first available URL."
    if [ ${#UPDATE_URLS[@]} -gt 0 ]; then
        SELECTED_URL="${UPDATE_URLS[0]}"
        uci set banner.banner.selected_url="$SELECTED_URL"
        uci commit banner
        log "Set selected_url to: $SELECTED_URL"
    else
        log "✖ No update URLs configured, exiting."
        exit 1
    fi
fi

# 尝试从 SELECTED_URL 获取 JSON
JSON_CACHE_FILE="$CACHE_DIR/banner_config.json"
if ! fetch_and_validate_json "$SELECTED_URL" "$JSON_CACHE_FILE"; then
    log "✖ Failed to fetch from selected URL: $SELECTED_URL. Trying other URLs."
    # 如果选定的 URL 失败，尝试其他 URL
    for url in "${UPDATE_URLS[@]}"; do
        if [ "$url" != "$SELECTED_URL" ]; then
            if fetch_and_validate_json "$url" "$JSON_CACHE_FILE"; then
                log "✓ Successfully fetched from alternative URL: $url"
                update_uci_config "selected_url" "$url" && uci commit banner
                break
            fi
        fi
    done
    # 如果所有 URL 都失败
    if [ ! -f "$JSON_CACHE_FILE" ]; then
        log "✖ All configured URLs failed to provide valid JSON, exiting."
        exit 1
    fi
fi

# 解析 JSON 数据并更新 UCI 配置
log "Parsing JSON and updating UCI config..."

# 文本内容
REMOTE_TEXT=$(jq -r ".text // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_TEXT" ]; then
    update_uci_config "text" "$REMOTE_TEXT" && uci commit banner
fi

# 文本颜色
REMOTE_COLOR=$(jq -r ".color // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_COLOR" ]; then
    update_uci_config "color" "$REMOTE_COLOR" && uci commit banner
fi

# 不透明度
REMOTE_OPACITY=$(jq -r ".opacity // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_OPACITY" ]; then
    update_uci_config "opacity" "$REMOTE_OPACITY" && uci commit banner
fi

# 轮播间隔
REMOTE_CAROUSEL_INTERVAL=$(jq -r ".carousel_interval // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_CAROUSEL_INTERVAL" ]; then
    update_uci_config "carousel_interval" "$REMOTE_CAROUSEL_INTERVAL" && uci commit banner
fi

# 背景组
REMOTE_BG_GROUP=$(jq -r ".bg_group // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_BG_GROUP" ]; then
    update_uci_config "bg_group" "$REMOTE_BG_GROUP" && uci commit banner
fi

# 背景启用状态
REMOTE_BG_ENABLED=$(jq -r ".bg_enabled // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_BG_ENABLED" ]; then
    update_uci_config "bg_enabled" "$REMOTE_BG_ENABLED" && uci commit banner
fi

# 持久化存储
REMOTE_PERSISTENT_STORAGE=$(jq -r ".persistent_storage // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_PERSISTENT_STORAGE" ]; then
    update_uci_config "persistent_storage" "$REMOTE_PERSISTENT_STORAGE" && uci commit banner
fi

# 当前背景图
REMOTE_CURRENT_BG=$(jq -r ".current_bg // \'\'" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_CURRENT_BG" ]; then
    update_uci_config "current_bg" "$REMOTE_CURRENT_BG" && uci commit banner
fi

# 更新 URL 列表
REMOTE_UPDATE_URLS=($(jq -r ".update_urls[] // \'\'" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_UPDATE_URLS[@]} -gt 0 ]; then
    update_uci_list "update_urls" "${REMOTE_UPDATE_URLS[@]}" && uci commit banner
fi

# 联系方式 (新的动态列表)
REMOTE_CONTACTS=($(jq -c ".contacts[] // \'\'" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_CONTACTS[@]} -gt 0 ]; then
    update_uci_list "contacts" "${REMOTE_CONTACTS[@]}" && uci commit banner
fi

# 轮播内容 (新的动态列表)
REMOTE_CAROUSEL_ITEMS=($(jq -c ".carousel_items[] // \'\'" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_CAROUSEL_ITEMS[@]} -gt 0 ]; then
    update_uci_list "carousel_items" "${REMOTE_CAROUSEL_ITEMS[@]}" && uci commit banner
fi

# 快速导航 (新的动态列表)
REMOTE_QUICK_NAV_GROUPS=($(jq -c ".quick_nav_groups[] // \'\'" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_QUICK_NAV_GROUPS[@]} -gt 0 ]; then
    update_uci_list "quick_nav_groups" "${REMOTE_QUICK_NAV_GROUPS[@]}" && uci commit banner
fi

# 更新时间
update_uci_config "last_update" "$(date +%s)" && uci commit banner

log "✓ UCI config updated from remote JSON."

# 重新启动 banner 服务以应用更改
log "Restarting banner service to apply changes..."
/etc/init.d/banner restart
log "✓ Banner service restarted."

log "========== Banner Update Script Finished =========="
UPDATER

# Background update script
cat > "$PKG_DIR/root/usr/bin/banner_bg_update.sh" <<\'BGUPDATER\'
#!/bin/sh

. /usr/share/banner/config.sh
. /usr/share/banner/timeouts.conf

log() {
    local msg="$1"
    local timestamp=$(date \'+%Y-%m-%d %H:%M:%S\' 2>/dev/null || date)
    local log_file="${LOG_FILE:-/tmp/banner_bg.log}"

    if echo "$msg" | grep -qE \'https?://|[0-9]{1,3}\.[0-9]{1,3}\'; then
        msg=$(echo "$msg" | sed -E \'s|https?://[^[:space:]]+|[URL]|g\' | sed -E \'s|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[IP]|g\')
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


log "========== Banner Background Update Script Started =========="

# 确保网络连接
if ! check_network; then
    log "✖ Network is not available, exiting."
    exit 1
fi

# 获取当前背景组和背景启用状态
BG_ENABLED=$(uci -q get banner.banner.bg_enabled)
if [ "$BG_ENABLED" != "1" ]; then
    log "Background update is disabled, exiting."
    exit 0
fi

BG_GROUP=$(uci -q get banner.banner.bg_group)
if [ -z "$BG_GROUP" ]; then
    log "✖ Background group not configured, exiting."
    exit 1
fi

# 构造背景图 JSON URL
BG_JSON_URL="https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/bg_group_${BG_GROUP}.json"
BG_JSON_CACHE_FILE="$CACHE_DIR/bg_group_${BG_GROUP}.json"

# 获取并验证背景图 JSON
if ! fetch_and_validate_json "$BG_JSON_URL" "$BG_JSON_CACHE_FILE"; then
    log "✖ Failed to fetch background JSON for group $BG_GROUP, exiting."
    exit 1
fi

# 解析背景图 URL 列表
BG_URLS=($(jq -r ".background_images[] // \'\'" "$BG_JSON_CACHE_FILE"))
if [ ${#BG_URLS[@]} -eq 0 ]; then
    log "✖ No background images found in JSON for group $BG_GROUP, exiting."
    exit 1
fi

# 获取当前背景图索引
CURRENT_BG_INDEX=$(uci -q get banner.banner.current_bg || echo 0)

# 计算下一个背景图索引
NEXT_BG_INDEX=$(( (CURRENT_BG_INDEX + 1) % ${#BG_URLS[@]} ))
NEXT_BG_URL="${BG_URLS[$NEXT_BG_INDEX]}"

log "Next background image URL: $NEXT_BG_URL (Index: $NEXT_BG_INDEX)"

# 下载下一个背景图
TMP_BG_FILE="$CACHE_DIR/next_bg.jpg"
if ! curl -fLsS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIMEOUT" "$NEXT_BG_URL" -o "$TMP_BG_FILE"; then
    log "✖ Failed to download background image from $NEXT_BG_URL"
    rm -f "$TMP_BG_FILE"
    exit 1
fi

# 检查下载的图片是否有效 (简单检查文件大小)
if [ ! -s "$TMP_BG_FILE" ]; then
    log "✖ Downloaded background image is empty or invalid: $NEXT_BG_URL"
    rm -f "$TMP_BG_FILE"
    exit 1
fi

# 部署新背景图
cp -f "$TMP_BG_FILE" "$DEFAULT_BG_PATH/current_bg.jpg"
chmod 644 "$DEFAULT_BG_PATH/current_bg.jpg"
rm -f "$TMP_BG_FILE"

# 更新 UCI 配置中的当前背景图索引
update_uci_config "current_bg" "$NEXT_BG_INDEX" && uci commit banner

log "✓ Background image updated successfully to $NEXT_BG_URL"

log "========== Banner Background Update Script Finished =========="
BGUPDATER

# Init script
cat > "$PKG_DIR/root/etc/init.d/banner" <<\'INITD\'
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=95
STOP=05

SERVICE_DAEMONIZE=1

PROG=/usr/bin/banner_update.sh
PROG_BG=/usr/bin/banner_bg_update.sh
PROG_CLEANER=/usr/bin/banner_cache_cleaner.sh

start_service() {
    # 确保必要的目录存在
    mkdir -p /www/luci-static/banner /overlay/banner /tmp/banner_cache /usr/share/banner
    chmod 755 /www/luci-static/banner /overlay/banner /tmp/banner_cache /usr/share/banner

    # 部署内置背景图（如果不存在）
    if [ ! -f /www/luci-static/banner/current_bg.jpg ] && [ -f /usr/share/banner/bg0.jpg ]; then
        cp -f /usr/share/banner/bg0.jpg /www/luci-static/banner/current_bg.jpg
        chmod 644 /www/luci-static/banner/current_bg.jpg
        echo "Deployed initial built-in background."
    fi

    # 启动更新脚本 (首次启动时立即执行)
    procd_set_param command "$PROG"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_start_service

    # 启动背景更新脚本 (首次启动时立即执行)
    procd_set_param command "$PROG_BG"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_start_service

    # 启动缓存清理脚本 (首次启动时立即执行)
    procd_set_param command "$PROG_CLEANER"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_start_service

    # 添加定时任务
    # 更新主 banner 内容 (每3小时)
    CRON_MAIN="0 */3 * * * $PROG >/dev/null 2>&1"
    # 更新背景图 (每15分钟)
    CRON_BG="*/15 * * * * $PROG_BG >/dev/null 2>&1"
    # 清理缓存 (每天凌晨3点)
    CRON_CLEANER="0 3 * * * $PROG_CLEANER >/dev/null 2>&1"

    # 写入 cron.d 文件
    echo "$CRON_MAIN" > /etc/cron.d/banner_update
    echo "$CRON_BG" >> /etc/cron.d/banner_bg_update
    echo "$CRON_CLEANER" >> /etc/cron.d/banner_cache_cleaner

    # 确保 cron 服务已启动并重新加载配置
    /etc/init.d/cron enable
    /etc/init.d/cron restart

    echo "Banner service started with cron jobs."
}

stop_service() {
    # 停止 procd 托管的服务
    procd_kill_service

    # 移除 cron.d 文件
    rm -f /etc/cron.d/banner_update
    rm -f /etc/cron.d/banner_bg_update
    rm -f /etc/cron.d/banner_cache_cleaner

    # 重新加载 cron 配置
    /etc/init.d/cron restart

    echo "Banner service stopped and cron jobs removed."
}

reload_service() {
    stop_service
    start_service
}

INITD

# Controller file
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<\'CONTROLLER\'
module("luci.controller.banner", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/banner") then
        return
    end

    entry({"admin", "system", "banner"}, firstchild(), "Banner", 40).dependent = true

    entry({"admin", "system", "banner", "overview"}, call("action_overview"), _("Overview"), 10)
    entry({"admin", "system", "banner", "settings"}, cbi("banner/settings"), _("Settings"), 20)
    entry({"admin", "system", "banner", "welfare"}, call("action_welfare"), _("Welfare Share"), 30)

    entry({"admin", "system", "banner", "update_status"}, call("action_update_status")).leaf = true
    entry({"admin", "system", "banner", "bg_status"}, call("action_bg_status")).leaf = true
    entry({"admin", "system", "banner", "do_update"}, call("action_do_update")).leaf = true
    entry({"admin", "system", "banner", "do_bg_update"}, call("action_do_bg_update")).leaf = true
    entry({"admin", "system", "banner", "get_contacts"}, call("action_get_contacts")).leaf = true
    entry({"admin", "system", "banner", "get_carousel_items"}, call("action_get_carousel_items")).leaf = true
    entry({"admin", "system", "banner", "get_quick_nav_groups"}, call("action_get_quick_nav_groups")).leaf = true
end

function action_overview()
    local page = luci.template.render("banner/overview")
    luci.http.write(page)
end

function action_welfare()
    local page = luci.template.render("banner/welfare")
    luci.http.write(page)
end

function action_update_status()
    local log_file = "/tmp/banner_update.log"
    local status = ""
    if nixio.fs.access(log_file) then
        status = nixio.fs.readfile(log_file)
    else
        status = "No update log available."
    end
    luci.http.prepare_content("text/plain")
    luci.http.write(status)
end

function action_bg_status()
    local log_file = "/tmp/banner_bg.log"
    local status = ""
    if nixio.fs.access(log_file) then
        status = nixio.fs.readfile(log_file)
    else
        status = "No background update log available."
    end
    luci.http.prepare_content("text/plain")
    luci.http.write(status)
end

function action_do_update()
    luci.sys.call("/usr/bin/banner_update.sh >/dev/null 2>&1 &")
    luci.http.prepare_content("application/json")
    luci.http.write("{ \"status\": \"Update initiated\" }")
end

function action_do_bg_update()
    luci.sys.call("/usr/bin/banner_bg_update.sh >/dev/null 2>&1 &")
    luci.http.prepare_content("application/json")
    luci.http.write("{ \"status\": \"Background update initiated\" }")
end

function action_get_contacts()
    local uci = require "luci.model.uci".cursor()
    local contacts = uci:get_list("banner", "banner", "contacts")
    local contact_data = {}
    for _, c_json in ipairs(contacts) do
        local ok, data = pcall(luci.json.decode, c_json)
        if ok and type(data) == "table" then
            table.insert(contact_data, data)
        end
    end
    luci.http.prepare_content("application/json")
    luci.http.write(luci.json.encode(contact_data))
end

function action_get_carousel_items()
    local uci = require "luci.model.uci".cursor()
    local carousel_items = uci:get_list("banner", "banner", "carousel_items")
    local item_data = {}
    for _, item_json in ipairs(carousel_items) do
        local ok, data = pcall(luci.json.decode, item_json)
        if ok and type(data) == "table" then
            table.insert(item_data, data)
        end
    end
    luci.http.prepare_content("application/json")
    luci.http.write(luci.json.encode(item_data))
end

function action_get_quick_nav_groups()
    local uci = require "luci.model.uci".cursor()
    local quick_nav_groups = uci:get_list("banner", "banner", "quick_nav_groups")
    local group_data = {}
    for _, group_json in ipairs(quick_nav_groups) do
        local ok, data = pcall(luci.json.decode, group_json)
        if ok and type(data) == "table" then
            table.insert(group_data, data)
        end
    end
    luci.http.prepare_content("application/json")
    luci.http.write(luci.json.encode(group_data))
end

CONTROLLER

# CBI Model
cat > "$PKG_DIR/root/usr/lib/lua/luci/model/cbi/banner/settings.lua" <<\'CBIMODEL\'
m = Map("banner", "Banner Settings", "Configure the OpenWrt banner plugin.")

s = m:section(NamedSection, "banner", "banner", "General Settings")

s.addremove = false

o = s:option(Value, "text", "Banner Text")
o.datatype = "string"
o.placeholder = "Enter banner text here"
o.default = "🎉 福利导航的内容会不定时更新，关注作者不迷路"

o = s:option(ListValue, "color", "Text Color")
o:value("rainbow", "Rainbow")
o:value("red", "Red")
o:value("green", "Green")
o:value("blue", "Blue")
o:value("white", "White")
o.default = "rainbow"

o = s:option(Value, "opacity", "Background Opacity (0-100)")
o.datatype = "range(0,100)"
o.default = "50"

o = s:option(Value, "carousel_interval", "Carousel Interval (ms)")
o.datatype = "range(1000,30000)"
o.default = "5000"

o = s:option(ListValue, "bg_group", "Background Image Group")
o:value("1", "Group 1")
o:value("2", "Group 2")
o:value("3", "Group 3")
o:value("4", "Group 4")
o.default = "1"

o = s:option(Flag, "bg_enabled", "Enable Background Image Rotation")
o.default = "1"

o = s:option(Flag, "persistent_storage", "Enable Persistent Storage for Backgrounds")
o.default = "0"

o = s:option(Value, "current_bg", "Current Background Index")
o.datatype = "uinteger"
o.default = "0"
o.readonly = true

s = m:section(NamedSection, "banner", "banner", "Remote Update Settings")
s.addremove = false

urls_option = s:option(DynamicList, "update_urls", "Remote Update URLs")
urls_option.datatype = "string"
urls_option.placeholder = "https://example.com/banner.json"
urls_option.default = "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"

o = s:option(Value, "selected_url", "Selected Update URL")
o.datatype = "string"
o.placeholder = "Currently active URL"
o.readonly = true

update_interval_option = s:option(Value, "update_interval", "Update Interval (seconds)")
update_interval_option.datatype = "range(300,86400)"
update_interval_option.default = "10800"

o = s:option(Value, "last_update", "Last Update Time (Unix Timestamp)")
o.datatype = "uinteger"
o.default = "0"
o.readonly = true

return m
CBIMODEL

# Overview View
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/overview.htm" <<\'OVERVIEWHTML\'
<%+header%>
<style type="text/css">
    .banner-hero {
        position: relative;
        width: 100%;
        height: 200px;
        overflow: hidden;
        background-size: cover;
        background-position: center;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
        color: white;
        font-size: 2em;
        font-weight: bold;
        text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.7);
        transition: background-image 1s ease-in-out;
        box-sizing: border-box; /* Added for responsive design */
        max-width: 1200px; /* Adjusted from min(1200px, 95vw) */
        margin: 0 auto; /* Center the banner */
    }
    .banner-text {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        z-index: 2;
        white-space: nowrap; /* Prevent text wrapping */
    }
    .banner-text.rainbow {
        background: linear-gradient(to right, red, orange, yellow, green, blue, indigo, violet);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }
    .banner-text.red { color: red; }
    .banner-text.green { color: green; }
    .banner-text.blue { color: blue; }
    .banner-text.white { color: white; }

    .contact-card {
        display: flex;
        flex-wrap: wrap; /* Added for responsive design */
        gap: 10px;
        margin-top: 20px;
        justify-content: center;
    }
    .contact-item {
        background-color: rgba(0, 0, 0, 0.6);
        padding: 10px 15px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        transition: background-color 0.3s ease;
    }
    .contact-item:hover {
        background-color: rgba(0, 0, 0, 0.8);
    }
    .contact-item i {
        font-size: 1.2em;
    }
    .contact-item span {
        font-size: 0.9em;
    }
    .copy-tooltip {
        position: absolute;
        background-color: #333;
        color: #fff;
        padding: 5px 10px;
        border-radius: 4px;
        font-size: 0.8em;
        z-index: 1000;
        opacity: 0;
        transition: opacity 0.3s ease-in-out;
        pointer-events: none;
    }
    .carousel-container {
        margin-top: 30px;
        background-color: rgba(0, 0, 0, 0.6);
        padding: 20px;
        border-radius: 8px;
        max-width: 1200px;
        margin-left: auto;
        margin-right: auto;
        position: relative;
        overflow: hidden;
    }
    .carousel-item {
        display: none;
        text-align: center;
        font-size: 1.1em;
        line-height: 1.5;
        min-height: 80px; /* Ensure consistent height */
        align-items: center;
        justify-content: center;
        color: white;
    }
    .carousel-item.active {
        display: flex;
    }
    .carousel-dots {
        text-align: center;
        margin-top: 10px;
    }
    .carousel-dot {
        display: inline-block;
        width: 10px;
        height: 10px;
        margin: 0 5px;
        background-color: rgba(255, 255, 255, 0.5);
        border-radius: 50%;
        cursor: pointer;
    }
    .carousel-dot.active {
        background-color: rgba(255, 255, 255, 1);
    }
    .section-title {
        font-size: 1.5em;
        color: #fff;
        margin-top: 40px;
        margin-bottom: 20px;
        text-align: center;
    }
    .quick-nav-group-container {
        display: flex;
        flex-wrap: wrap;
        gap: 15px;
        justify-content: center;
        margin-top: 20px;
    }
    .quick-nav-group-item {
        background-color: rgba(0, 0, 0, 0.6);
        padding: 15px 20px;
        border-radius: 10px;
        cursor: pointer;
        transition: background-color 0.3s ease;
        color: white;
        font-weight: bold;
        text-align: center;
        min-width: 120px;
    }
    .quick-nav-group-item:hover {
        background-color: rgba(0, 0, 0, 0.8);
    }
</style>

<div class="cbi-map">
    <div class="cbi-section-descr">
        <div class="banner-hero" id="banner-hero">
            <div class="banner-text" id="banner-text"></div>
        </div>

        <div class="section-title"><%=translate("Contact Information")%></div>
        <div class="contact-card" id="contact-card"></div>

        <div class="section-title"><%=translate("Carousel Content")%></div>
        <div class="carousel-container">
            <div id="carousel-items"></div>
            <div class="carousel-dots" id="carousel-dots"></div>
        </div>

        <div class="section-title"><%=translate("Quick Navigation")%></div>
        <div class="quick-nav-group-container" id="quick-nav-group-container"></div>

        <script type="text/javascript" src="<%=resource%>/luci-static/banner/overview.js"></script>
        <script type="text/javascript">
            // Initial load of banner data
            document.addEventListener('DOMContentLoaded', function() {
                loadBannerData();
                loadContactInfo();
                loadCarouselItems();
                loadQuickNavGroups();
            });

            // Function to load banner data (text, color, opacity)
            function loadBannerData() {
                XHR.poll(5, '<%=luci.dispatcher.build_url("admin", "system", "banner", "overview")%>', null, function(xhr, data) {
                    var bannerText = data.banner_text || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "text") or "")%>';
                    var bannerColor = data.banner_color || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "color") or "rainbow")%>';
                    var bannerOpacity = data.banner_opacity || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "opacity") or "50")%>';
                    var bgEnabled = data.bg_enabled || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "bg_enabled") or "0")%>';

                    var bannerHero = document.getElementById('banner-hero');
                    var bannerTextElement = document.getElementById('banner-text');

                    bannerTextElement.textContent = bannerText;
                    bannerTextElement.className = 'banner-text ' + bannerColor;

                    if (bgEnabled === '1') {
                        bannerHero.style.backgroundColor = 'rgba(0, 0, 0, ' + (bannerOpacity / 100) + ')';
                        // Background image is handled by CSS and current_bg.jpg
                    } else {
                        bannerHero.style.backgroundColor = 'rgba(0, 0, 0, 0.5)'; // Default if disabled
                        bannerHero.style.backgroundImage = 'none';
                    }
                });
            }

            // Function to load contact information
            function loadContactInfo() {
                XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_contacts")%>', null, function(xhr, contacts) {
                    var contactCard = document.getElementById('contact-card');
                    contactCard.innerHTML = ''; // Clear existing contacts

                    if (contacts && contacts.length > 0) {
                        contacts.forEach(function(contact) {
                            var item = document.createElement('div');
                            item.className = 'contact-item';
                            item.setAttribute('data-value', contact.value);
                            item.innerHTML = '<i class="' + contact.icon + '"></i><span>' + contact.label + ': ' + contact.value + '</span>';
                            item.onclick = function() {
                                copyToClipboard(contact.value, item);
                            };
                            contactCard.appendChild(item);
                        });
                    } else {
                        contactCard.innerHTML = '<p style="color: white;"><%=translate("No contact information available.")%></p>';
                    }
                });
            }

            // Function to load carousel items
            var currentCarouselIndex = 0;
            var carouselInterval;
            function loadCarouselItems() {
                XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_carousel_items")%>', null, function(xhr, items) {
                    var carouselContainer = document.getElementById('carousel-items');
                    var carouselDots = document.getElementById('carousel-dots');
                    carouselContainer.innerHTML = '';
                    carouselDots.innerHTML = '';

                    if (carouselInterval) {
                        clearInterval(carouselInterval);
                    }

                    if (items && items.length > 0) {
                        items.forEach(function(item, index) {
                            var div = document.createElement('div');
                            div.className = 'carousel-item';
                            div.textContent = item.content;
                            carouselContainer.appendChild(div);

                            var dot = document.createElement('span');
                            dot.className = 'carousel-dot';
                            dot.setAttribute('data-index', index);
                            dot.onclick = function() {
                                showCarouselItem(index, items.length);
                                resetCarouselInterval(items.length);
                            };
                            carouselDots.appendChild(dot);
                        });

                        showCarouselItem(currentCarouselIndex, items.length);
                        resetCarouselInterval(items.length);
                    } else {
                        carouselContainer.innerHTML = '<p style="color: white;"><%=translate("No carousel content available.")%></p>';
                    }
                });
            }

            function showCarouselItem(index, totalItems) {
                var items = document.querySelectorAll('#carousel-items .carousel-item');
                var dots = document.querySelectorAll('#carousel-dots .carousel-dot');

                items.forEach(function(item, i) {
                    if (i === index) {
                        item.classList.add('active');
                    } else {
                        item.classList.remove('active');
                    }
                });

                dots.forEach(function(dot, i) {
                    if (i === index) {
                        dot.classList.add('active');
                    } else {
                        dot.classList.remove('active');
                    }
                });
                currentCarouselIndex = index;
            }

            function resetCarouselInterval(totalItems) {
                if (carouselInterval) {
                    clearInterval(carouselInterval);
                }
                var interval = parseInt('<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "carousel_interval") or "5000")%>');
                if (totalItems > 1 && interval > 0) {
                    carouselInterval = setInterval(function() {
                        currentCarouselIndex = (currentCarouselIndex + 1) % totalItems;
                        showCarouselItem(currentCarouselIndex, totalItems);
                    }, interval);
                }
            }

            // Function to load quick navigation groups
            function loadQuickNavGroups() {
                XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_quick_nav_groups")%>', null, function(xhr, groups) {
                    var quickNavGroupContainer = document.getElementById('quick-nav-group-container');
                    quickNavGroupContainer.innerHTML = ''; // Clear existing groups

                    if (groups && groups.length > 0) {
                        groups.forEach(function(group) {
                            var item = document.createElement('div');
                            item.className = 'quick-nav-group-item';
                            item.textContent = group.name;
                            item.onclick = function() {
                                // Navigate to a new page for welfare share, passing group ID or name
                                window.location.href = '<%=luci.dispatcher.build_url("admin", "system", "banner", "welfare")%>?group=' + encodeURIComponent(group.id || group.name);
                            };
                            quickNavGroupContainer.appendChild(item);
                        });
                    } else {
                        quickNavGroupContainer.innerHTML = '<p style="color: white;"><%=translate("No quick navigation groups available.")%></p>';
                    }
                });
            }

            // Copy to clipboard function with tooltip
            function copyToClipboard(text, element) {
                var textarea = document.createElement('textarea');
                textarea.value = text;
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);

                var tooltip = document.createElement('div');
                tooltip.className = 'copy-tooltip';
                tooltip.textContent = '<%=translate("Copied!")%>';
                element.appendChild(tooltip);

                var rect = element.getBoundingClientRect();
                tooltip.style.left = (rect.width / 2) + 'px';
                tooltip.style.top = '-30px';
                tooltip.style.transform = 'translateX(-50%)';

                tooltip.style.opacity = '1';
                setTimeout(function() {
                    tooltip.style.opacity = '0';
                    setTimeout(function() {
                        element.removeChild(tooltip);
                    }, 300);
                }, 1500);
            }

            // Function to handle auto-refresh after update
            function handleAutoRefresh(actionType) {
                var message = (actionType === 'update') ? '<%=translate("Update initiated, refreshing page...")%>' : '<%=translate("Background update initiated, refreshing page...")%>';
                alert(message); // Use a simple alert for now, can be replaced with a more elegant UI notification
                setTimeout(function() {
                    location.reload();
                }, 2000); // Refresh after 2 seconds
            }

            // Override XHR.poll to handle auto-refresh for update actions
            var originalXHRPoll = XHR.poll;
            XHR.poll = function(interval, url, data, callback) {
                if (url.includes('do_update') || url.includes('do_bg_update')) {
                    return originalXHRPoll(interval, url, data, function(xhr, response) {
                        callback(xhr, response);
                        if (response && response.status) {
                            handleAutoRefresh(url.includes('do_update') ? 'update' : 'bg_update');
                        }
                    });
                } else {
                    return originalXHRPoll(interval, url, data, callback);
                }
            };

        </script>
    </div>
</div>
<%+footer%>
OVERVIEWHTML

# Welfare View (New Page for Quick Navigation Links)
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/welfare.htm" <<\'WELFAREHTML\'
<%+header%>
<style type="text/css">
    .welfare-container {
        max-width: 1200px;
        margin: 20px auto;
        padding: 20px;
        background-color: rgba(0, 0, 0, 0.6);
        border-radius: 8px;
        color: white;
    }
    .welfare-title {
        font-size: 2em;
        text-align: center;
        margin-bottom: 20px;
        color: #4CAF50; /* Green color for welfare */
    }
    .nav-group-title {
        font-size: 1.5em;
        margin-top: 30px;
        margin-bottom: 15px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.3);
        padding-bottom: 5px;
    }
    .nav-links-container {
        display: flex;
        flex-wrap: wrap;
        gap: 15px;
    }
    .nav-link-item {
        background: linear-gradient(135deg, #6a11cb 0%, #2575fc 100%); /* Gradient background */
        padding: 15px 20px;
        border-radius: 10px;
        text-align: center;
        color: white;
        text-decoration: none;
        font-weight: bold;
        transition: all 0.3s ease;
        flex: 1 1 calc(33% - 30px); /* Three items per row, with gap */
        box-sizing: border-box;
        min-width: 180px; /* Minimum width for items */
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
    }
    .nav-link-item:hover {
        transform: translateY(-5px) scale(1.02);
        box-shadow: 0 6px 12px rgba(0, 0, 0, 0.5);
        background: linear-gradient(135deg, #2575fc 0%, #6a11cb 100%); /* Reverse gradient on hover */
    }
    .nav-link-item i {
        margin-right: 8px;
        font-size: 1.2em;
    }
    /* Responsive adjustments */
    @media (max-width: 768px) {
        .nav-link-item {
            flex: 1 1 calc(50% - 15px); /* Two items per row on medium screens */
        }
    }
    @media (max-width: 480px) {
        .nav-link-item {
            flex: 1 1 100%; /* One item per row on small screens */
        }
    }
</style>

<div class="welfare-container">
    <h2 class="welfare-title"><%=translate("Welfare Share - Quick Navigation")%></h2>

    <div id="welfare-content"></div>

    <script type="text/javascript">
        document.addEventListener('DOMContentLoaded', function() {
            loadWelfareContent();
        });

        function loadWelfareContent() {
            XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_quick_nav_groups")%>', null, function(xhr, groups) {
                var welfareContent = document.getElementById('welfare-content');
                welfareContent.innerHTML = '';

                if (groups && groups.length > 0) {
                    groups.forEach(function(group) {
                        var groupDiv = document.createElement('div');
                        groupDiv.className = 'nav-group';
                        groupDiv.innerHTML = '<h3 class="nav-group-title">' + group.name + '</h3>';

                        var linksContainer = document.createElement('div');
                        linksContainer.className = 'nav-links-container';

                        if (group.links && group.links.length > 0) {
                            group.links.forEach(function(link) {
                                var linkItem = document.createElement('a');
                                linkItem.className = 'nav-link-item';
                                linkItem.href = link.url;
                                linkItem.target = '_blank'; // Open in new tab
                                linkItem.rel = 'noopener noreferrer';
                                linkItem.innerHTML = (link.icon ? '<i class="' + link.icon + '"></i>' : '') + link.label;
                                linksContainer.appendChild(linkItem);
                            });
                        } else {
                            linksContainer.innerHTML = '<p><%=translate("No links available for this group.")%></p>';
                        }
                        groupDiv.appendChild(linksContainer);
                        welfareContent.appendChild(groupDiv);
                    });
                } else {
                    welfareContent.innerHTML = '<p><%=translate("No quick navigation groups available.")%></p>';
                }
            });
        }
    </script>
</div>
<%+footer%>
WELFAREHTML

# Overview JS (Moved from inline script)
cat > "$PKG_DIR/root/www/luci-static/banner/overview.js" <<\'OVERVIEWJS\'
// This file contains JavaScript functions for the banner overview page.
// It is loaded dynamically by overview.htm.

// Function to load banner data (text, color, opacity)
function loadBannerData() {
    XHR.poll(5, '<%=luci.dispatcher.build_url("admin", "system", "banner", "overview")%>', null, function(xhr, data) {
        var bannerText = data.banner_text || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "text") or "")%>';
        var bannerColor = data.banner_color || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "color") or "rainbow")%>';
        var bannerOpacity = data.banner_opacity || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "opacity") or "50")%>';
        var bgEnabled = data.bg_enabled || '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "bg_enabled") or "0")%>';

        var bannerHero = document.getElementById('banner-hero');
        var bannerTextElement = document.getElementById('banner-text');

        bannerTextElement.textContent = bannerText;
        bannerTextElement.className = 'banner-text ' + bannerColor;

        if (bgEnabled === '1') {
            bannerHero.style.backgroundColor = 'rgba(0, 0, 0, ' + (bannerOpacity / 100) + ')';
            // Background image is handled by CSS and current_bg.jpg
        } else {
            bannerHero.style.backgroundColor = 'rgba(0, 0, 0, 0.5)'; // Default if disabled
            bannerHero.style.backgroundImage = 'none';
        }
    });
}

// Function to load contact information
function loadContactInfo() {
    XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_contacts")%>', null, function(xhr, contacts) {
        var contactCard = document.getElementById('contact-card');
        contactCard.innerHTML = ''; // Clear existing contacts

        if (contacts && contacts.length > 0) {
            contacts.forEach(function(contact) {
                var item = document.createElement('div');
                item.className = 'contact-item';
                item.setAttribute('data-value', contact.value);
                item.innerHTML = '<i class="' + contact.icon + '"></i><span>' + contact.label + ': ' + contact.value + '</span>';
                item.onclick = function() {
                    copyToClipboard(contact.value, item);
                };
                contactCard.appendChild(item);
            });
        } else {
            contactCard.innerHTML = '<p style="color: white;"><%=translate("No contact information available.")%></p>';
        }
    });
}

// Function to load carousel items
var currentCarouselIndex = 0;
var carouselInterval;
function loadCarouselItems() {
    XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_carousel_items")%>', null, function(xhr, items) {
        var carouselContainer = document.getElementById('carousel-items');
        var carouselDots = document.getElementById('carousel-dots');
        carouselContainer.innerHTML = '';
        carouselDots.innerHTML = '';

        if (carouselInterval) {
            clearInterval(carouselInterval);
        }

        if (items && items.length > 0) {
            items.forEach(function(item, index) {
                var div = document.createElement('div');
                div.className = 'carousel-item';
                div.textContent = item.content;
                carouselContainer.appendChild(div);

                var dot = document.createElement('span');
                dot.className = 'carousel-dot';
                dot.setAttribute('data-index', index);
                dot.onclick = function() {
                    showCarouselItem(index, items.length);
                    resetCarouselInterval(items.length);
                };
                carouselDots.appendChild(dot);
            });

            showCarouselItem(currentCarouselIndex, items.length);
            resetCarouselInterval(items.length);
        } else {
            carouselContainer.innerHTML = '<p style="color: white;"><%=translate("No carousel content available.")%></p>';
        }
    });
}

function showCarouselItem(index, totalItems) {
    var items = document.querySelectorAll('#carousel-items .carousel-item');
    var dots = document.querySelectorAll('#carousel-dots .carousel-dot');

    items.forEach(function(item, i) {
        if (i === index) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    dots.forEach(function(dot, i) {
        if (i === index) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });
    currentCarouselIndex = index;
}

function resetCarouselInterval(totalItems) {
    if (carouselInterval) {
        clearInterval(carouselInterval);
    }
    var interval = parseInt('<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "carousel_interval") or "5000")%>');
    if (totalItems > 1 && interval > 0) {
        carouselInterval = setInterval(function() {
            currentCarouselIndex = (currentCarouselIndex + 1) % totalItems;
            showCarouselItem(currentCarouselIndex, totalItems);
        }, interval);
    }
}

// Function to load quick navigation groups
function loadQuickNavGroups() {
    XHR.get('<%=luci.dispatcher.build_url("admin", "system", "banner", "get_quick_nav_groups")%>', null, function(xhr, groups) {
        var quickNavGroupContainer = document.getElementById('quick-nav-group-container');
        quickNavGroupContainer.innerHTML = ''; // Clear existing groups

        if (groups && groups.length > 0) {
            groups.forEach(function(group) {
                var item = document.createElement('div');
                item.className = 'quick-nav-group-item';
                item.textContent = group.name;
                item.onclick = function() {
                    // Navigate to a new page for welfare share, passing group ID or name
                    window.location.href = '<%=luci.dispatcher.build_url("admin", "system", "banner", "welfare")%>?group=' + encodeURIComponent(group.id || group.name);
                };
                quickNavGroupContainer.appendChild(item);
            });
        } else {
            quickNavGroupContainer.innerHTML = '<p style="color: white;"><%=translate("No quick navigation groups available.")%></p>';
        }
    });
}

// Copy to clipboard function with tooltip
function copyToClipboard(text, element) {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);

    var tooltip = document.createElement('div');
    tooltip.className = 'copy-tooltip';
    tooltip.textContent = '<%=translate("Copied!")%>';
    element.appendChild(tooltip);

    var rect = element.getBoundingClientRect();
    tooltip.style.left = (rect.width / 2) + 'px';
    tooltip.style.top = '-30px';
    tooltip.style.transform = 'translateX(-50%)';

    tooltip.style.opacity = '1';
    setTimeout(function() {
        tooltip.style.opacity = '0';
        setTimeout(function() {
            element.removeChild(tooltip);
        }, 300);
    }, 1500);
}

// Function to handle auto-refresh after update
function handleAutoRefresh(actionType) {
    var message = (actionType === 'update') ? '<%=translate("Update initiated, refreshing page...")%>' : '<%=translate("Background update initiated, refreshing page...")%>';
    alert(message); // Use a simple alert for now, can be replaced with a more elegant UI notification
    setTimeout(function() {
        location.reload();
    }, 2000); // Refresh after 2 seconds
}

// Override XHR.poll to handle auto-refresh for update actions
var originalXHRPoll = XHR.poll;
XHR.poll = function(interval, url, data, callback) {
    if (url.includes('do_update') || url.includes('do_bg_update')) {
        return originalXHRPoll(interval, url, data, function(xhr, response) {
            callback(xhr, response);
            if (response && response.status) {
                handleAutoRefresh(url.includes('do_update') ? 'update' : 'bg_update');
            }
        });
    } else {
        return originalXHRPoll(interval, url, data, callback);
    }
};

// Initial load of banner data
document.addEventListener('DOMContentLoaded', function() {
    loadBannerData();
    loadContactInfo();
    loadCarouselItems();
    loadQuickNavGroups();
});
OVERVIEWJS

echo "[3/3] Generating LuCI views and controllers..."

# Create the index.htm view file
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/index.htm" <<\'INDEXHTML\'
<%+header%>
<div class="cbi-map">
    <h2 name="content"><%=translate("Banner Plugin")%></h2>
    <div class="cbi-section-descr">
        <p><%=translate("This plugin allows you to display a customizable banner on your OpenWrt router's web interface.")%></p>
        <p><%=translate("Use the tabs above to navigate between Overview, Settings, and Welfare Share.")%></p>
    </div>
</div>
<%+footer%>
INDEXHTML


echo "✓ LuCI views and controllers generated."


echo "=========================================="
echo "OpenWrt Banner Plugin v2.7 Setup Complete!"
echo "=========================================="

echo "To install the package, navigate to your OpenWrt SDK/buildroot directory and run:"
echo "  make package/custom/luci-app-banner/compile V=s"
echo "Then install the generated .ipk file via LuCI or opkg."
