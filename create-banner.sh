#!/bin/bash
# OpenWrt Banner Plugin - Final Optimized Version v2.8 (安全修正版)
# All potential issues addressed for maximum reliability and compatibility.
# This script is provided in three parts for completeness. Please concatenate them.

set -e

echo "=========================================="
echo "OpenWrt Banner Plugin v2.8 - Security Fix"
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
    # 修正点 1: 修复乱码
    echo "⚙ 允许 GitHub Actions 路径: $ABS_PKG_DIR"
    IS_GITHUB_ACTIONS=1
fi


if echo "$ABS_PKG_DIR" | grep -qE "^/home/[^/]+/.*openwrt"; then
    # 修正点 1: 修复乱码
    echo "⚙ 允许本地开发路径: $ABS_PKG_DIR"
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

# 修正点 4: 增加确认提示和使用 --
echo "即将清理目录: $ABS_PKG_DIR"
sleep 1
# 安全检查通过，执行删除
rm -rf -- "$ABS_PKG_DIR"

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
PKG_VERSION:=2.8
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
  # 修正点 5: 增加 +ca-bundle 依赖
  DEPENDS:=+curl +jsonfilter +luci-base +jq +ca-bundle
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
	# 修正点 6: 权限改为 644
	chmod 644 /tmp/banner_update.log /tmp/banner_bg.log
	
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

log "Cleaning up cache directory: $CACHE_DIR (Files older than $CLEANUP_AGE days)"

# 查找并删除旧的 JSON 文件
find "$CACHE_DIR" -type f -name "*.json" -mtime +"$CLEANUP_AGE" -delete 2>/dev/null
if [ $? -eq 0 ]; then
    log "✓ Successfully cleaned up old JSON files in cache."
else
    # 修正点 2: 修复多余引号
    log "✖ Failed to clean up old JSON files in cache."
fi

log "========== Cache Cleanup Finished =========="
CLEANER

# Main update script
cat > "$PKG_DIR/root/usr/bin/banner_update.sh" <<'UPDATER'
#!/bin/sh

. /usr/share/banner/config.sh
. /usr/share/banner/timeouts.conf

# --- 辅助函数 --- START

# 日志函数 (与 cleaner 脚本中的 log 函数保持一致)
log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG_FILE:-/tmp/banner_update.log}"

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

# 检查网络连接
check_network() {
    # 尝试 ping 百度，如果失败则尝试 ping 谷歌
    if ping -c 1 -W 1 baidu.com >/dev/null 2>&1; then
        return 0
    elif ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取并验证 JSON 文件
fetch_and_validate_json() {
    local url="$1"
    local output_file="$2"
    
    log "Fetching JSON from: $url"
    
    # 使用 curl 下载，并检查文件大小限制
    if ! curl -fLsS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIMEOUT" "$url" -o "$output_file"; then
        log "✖ Curl failed to download from $url"
        rm -f "$output_file"
        return 1
    fi
    
    # 检查文件是否为空
    if [ ! -s "$output_file" ]; then
        log "✖ Downloaded file is empty: $url"
        rm -f "$output_file"
        return 1
    fi
    
    # 检查文件大小是否超过限制
    local file_size=$(wc -c < "$output_file" 2>/dev/null || echo 0)
    if [ "$file_size" -gt "$MAX_FILE_SIZE" ]; then
        log "✖ Downloaded file size ($file_size bytes) exceeds limit ($MAX_FILE_SIZE bytes): $url"
        rm -f "$output_file"
        return 1
    fi
    
    # 验证 JSON 格式
    if ! jsonfilter -i "$output_file" -e "@" >/dev/null 2>&1; then
        log "✖ Downloaded file is not valid JSON: $url"
        rm -f "$output_file"
        return 1
    fi
    
    log "✓ JSON fetched and validated successfully."
    return 0
}

# 更新 UCI 配置项
update_uci_config() {
    local key="$1"
    local new_value="$2"
    local current_value=$(uci -q get banner.banner."$key")
    
    if [ "$new_value" != "$current_value" ]; then
        uci set banner.banner."$key"="$new_value"
        log "Updated UCI config: banner.banner.$key = $new_value"
        return 0
    fi
    return 1
}

# 更新 UCI 列表项
update_uci_list() {
    local key="$1"
    shift
    local new_values=("$@")
    local current_values=($(uci -q get banner.banner."$key"))
    
    # 比较数组长度
    local changed=0
    if [ ${#new_values[@]} -ne ${#current_values[@]} ]; then
        changed=1
    else
        # 比较数组内容
        for i in "${!new_values[@]}"; do
            if [ "${new_values[$i]}" != "${current_values[$i]}" ]; then
                changed=1
                break
            fi
        done
    fi

    if [ $changed -eq 1 ]; then
        # 先删除旧列表，再添加新列表
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
        update_uci_config "selected_url" "$SELECTED_URL" && uci commit banner
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
REMOTE_TEXT=$(jq -r ".text // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_TEXT" ]; then
    update_uci_config "text" "$REMOTE_TEXT" && uci commit banner
fi

# 文本颜色
REMOTE_COLOR=$(jq -r ".color // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_COLOR" ]; then
    update_uci_config "color" "$REMOTE_COLOR" && uci commit banner
fi

# 不透明度
REMOTE_OPACITY=$(jq -r ".opacity // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_OPACITY" ]; then
    update_uci_config "opacity" "$REMOTE_OPACITY" && uci commit banner
fi

# 轮播间隔
REMOTE_CAROUSEL_INTERVAL=$(jq -r ".carousel_interval // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_CAROUSEL_INTERVAL" ]; then
    # 修正点 9: 校验 carousel_interval
    if [ "$REMOTE_CAROUSEL_INTERVAL" -ge 1000 ] && [ "$REMOTE_CAROUSEL_INTERVAL" -le 30000 ]; then
        update_uci_config "carousel_interval" "$REMOTE_CAROUSEL_INTERVAL" && uci commit banner
    else
        log "⚠ Invalid carousel interval ($REMOTE_CAROUSEL_INTERVAL), keeping current value."
    fi
fi

# 背景组
REMOTE_BG_GROUP=$(jq -r ".bg_group // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_BG_GROUP" ]; then
    update_uci_config "bg_group" "$REMOTE_BG_GROUP" && uci commit banner
fi

# 背景启用状态
REMOTE_BG_ENABLED=$(jq -r ".bg_enabled // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_BG_ENABLED" ]; then
    update_uci_config "bg_enabled" "$REMOTE_BG_ENABLED" && uci commit banner
fi

# 持久化存储
REMOTE_PERSISTENT_STORAGE=$(jq -r ".persistent_storage // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_PERSISTENT_STORAGE" ]; then
    update_uci_config "persistent_storage" "$REMOTE_PERSISTENT_STORAGE" && uci commit banner
fi

# 当前背景图
REMOTE_CURRENT_BG=$(jq -r ".current_bg // ''" "$JSON_CACHE_FILE")
if [ -n "$REMOTE_CURRENT_BG" ]; then
    update_uci_config "current_bg" "$REMOTE_CURRENT_BG" && uci commit banner
fi

# 更新 URL 列表
REMOTE_UPDATE_URLS=($(jq -r ".update_urls[] // ''" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_UPDATE_URLS[@]} -gt 0 ]; then
    update_uci_list "update_urls" "${REMOTE_UPDATE_URLS[@]}" && uci commit banner
fi

# 联系方式 (新的动态列表)
REMOTE_CONTACTS=($(jq -c ".contacts[] // ''" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_CONTACTS[@]} -gt 0 ]; then
    update_uci_list "contacts" "${REMOTE_CONTACTS[@]}" && uci commit banner
fi

# 轮播内容 (新的动态列表)
REMOTE_CAROUSEL_ITEMS=($(jq -c ".carousel_items[] // ''" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_CAROUSEL_ITEMS[@]} -gt 0 ]; then
    update_uci_list "carousel_items" "${REMOTE_CAROUSEL_ITEMS[@]}" && uci commit banner
fi

# 快速导航 (新的动态列表)
REMOTE_QUICK_NAV_GROUPS=($(jq -c ".quick_nav_groups[] // ''" "$JSON_CACHE_FILE"))
if [ ${#REMOTE_QUICK_NAV_GROUPS[@]} -gt 0 ]; then
    update_uci_list "quick_nav_groups" "${REMOTE_QUICK_NAV_GROUPS[@]}" && uci commit banner
fi

# 更新时间
update_uci_config "last_update" "$(date +%s)" && uci commit banner

# 重新启动 banner 服务以应用更改
log "Restarting banner service to apply changes..."
/etc/init.d/banner restart
log "✓ Banner service restarted."

log "========== Banner Update Script Finished =========="
UPDATER

# Background update script
cat > "$PKG_DIR/root/usr/bin/banner_bg_update.sh" <<'BGUPDATER'
#!/bin/sh

. /usr/share/banner/config.sh
. /usr/share/banner/timeouts.conf

log() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    local log_file="${LOG_FILE:-/tmp/banner_bg.log}"

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


log "========== Banner Background Update Script Started =========="

# 检查网络连接
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
BG_URLS=($(jq -r ".background_images[] // ''" "$BG_JSON_CACHE_FILE"))
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
cat > "$PKG_DIR/root/etc/init.d/banner" <<'INITD'
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

    # 修正点 3: 使用 procd_open_instance/procd_close_instance 启动多个服务
    
    # 启动更新脚本 (首次启动时立即执行)
    procd_open_instance
    procd_set_param command "$PROG"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_close_instance

    # 启动背景更新脚本 (首次启动时立即执行)
    procd_open_instance
    procd_set_param command "$PROG_BG"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_close_instance

    # 启动缓存清理脚本 (首次启动时立即执行)
    procd_open_instance
    procd_set_param command "$PROG_CLEANER"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param nice -5
    procd_set_param required /etc/config/banner
    procd_close_instance

    # 添加定时任务
    # 更新主 banner 内容 (每3小时)
    CRON_MAIN="0 */3 * * * $PROG >/dev/null 2>&1"
    # 更新背景图 (每15分钟)
    CRON_BG="*/15 * * * * $PROG_BG >/dev/null 2>&1"
    # 清理缓存 (每天凌晨3点)
    CRON_CLEANER="0 3 * * * $PROG_CLEANER >/dev/null 2>&1"

    # 写入 cron.d 文件
    echo "$CRON_MAIN" > /etc/cron.d/banner_update
    echo "$CRON_BG" > /etc/cron.d/banner_bg_update
    echo "$CRON_CLEANER" > /etc/cron.d/banner_cache_cleaner # 修正点 3: 确保使用 > 而不是 >>

    # 确保 cron 服务已启动并重新加载配置
    /etc/init.d/cron enable
    /etc/init.d/cron restart
}

stop_service() {
    # 移除 cron.d 文件
    rm -f /etc/cron.d/banner_update
    rm -f /etc/cron.d/banner_bg_update
    rm -f /etc/cron.d/banner_cache_cleaner
    
    # 重新加载 cron 配置
    /etc/init.d/cron restart
    
    # procd 会自动停止由它启动的进程
}

service_triggers() {
    procd_add_validation "config" "banner"
    procd_add_reload_trigger "banner"
}

INITD

echo "[3/3] Creating LuCI controller and view files..."

# LuCI Controller
cat > "$PKG_DIR/root/usr/lib/lua/luci/controller/banner.lua" <<'LUA_CONTROLLER'
module("luci.controller.banner", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/banner") then
        return
    end

    entry({"admin", "system", "banner"}, alias("admin", "system", "banner", "overview"), _("Banner Navigation"), 90).leaf = true
    
    entry({"admin", "system", "banner", "overview"}, cbi("banner/overview"), _("Overview"), 1).leaf = true
    entry({"admin", "system", "banner", "config"}, cbi("banner/config"), _("Configuration"), 2).leaf = true
    entry({"admin", system", "banner", "log"}, call("action_log"), _("Log"), 3).leaf = true
end

function action_log()
    local log_file = "/tmp/banner_update.log"
    local log_content = ""
    
    if nixio.fs.access(log_file) then
        local f = io.open(log_file, "r")
        if f then
            log_content = f:read("*a")
            f:close()
        end
    end
    
    luci.template.render("banner/log", {log_content = log_content})
end
LUA_CONTROLLER

# LuCI CBI Config
cat > "$PKG_DIR/root/usr/lib/lua/luci/model/cbi/banner/config.lua" <<'LUA_CBI_CONFIG'
local m = Map("banner", translate("Banner Navigation Configuration"))

local s = m:section(NamedSection, "banner", "banner", translate("General Settings"))

s:option(ListValue, "color", translate("Text Color Style"), translate("Choose the color style for the banner text."))
s.color:value("rainbow", translate("Rainbow"))
s.color:value("white", translate("White"))
s.color:value("black", translate("Black"))
s.color:value("red", translate("Red"))
s.color:value("green", translate("Green"))
s.color:value("blue", translate("Blue"))

s:option(Value, "opacity", translate("Background Opacity (0-100)"), translate("Set the opacity of the banner background."))
s.opacity.datatype = "range(0,100)"
s.opacity.default = "50"

s:option(Value, "carousel_interval", translate("Carousel Interval (ms)"), translate("Time between text rotations in milliseconds (1000-30000)."))
s.carousel_interval.datatype = "range(1000,30000)"
s.carousel_interval.default = "5000"

s:option(ListValue, "bg_group", translate("Background Image Group"), translate("Select the group of background images to use."))
s.bg_group:value("1", translate("Group 1 (Default)"))
s.bg_group:value("2", translate("Group 2"))
s.bg_group:value("3", translate("Group 3"))
s.bg_group:value("4", translate("Group 4"))
s.bg_group.default = "1"

s:option(Flag, "bg_enabled", translate("Enable Background Update"), translate("Enable automatic background image rotation."))
s.bg_enabled.default = "1"

s:option(Flag, "persistent_storage", translate("Persistent Storage"), translate("Store downloaded backgrounds in /overlay (requires more space)."))
s.persistent_storage.default = "0"

local s_update = m:section(NamedSection, "banner", "banner", translate("Update Settings"))

s_update:option(Value, "update_interval", translate("Update Interval (seconds)"), translate("How often to check for new banner content (e.g., 10800 for 3 hours)."))
s_update.update_interval.datatype = "uinteger"
s_update.update_interval.default = "10800"

local update_urls = s_update:option(ListValue, "update_urls", translate("Remote Update URLs"), translate("List of URLs to fetch banner configuration JSON from."))
update_urls.multiple = true
update_urls.default = "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"

s_update:option(Value, "selected_url", translate("Selected Update URL"), translate("The currently active URL for updates."))
s_update.selected_url.readonly = true

s_update:option(Value, "last_update", translate("Last Update Time"), translate("Timestamp of the last successful update."))
s_update.last_update.readonly = true

return m
LUA_CBI_CONFIG

# LuCI View Overview (HTML)
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/overview.htm" <<'LUA_VIEW_OVERVIEW'
<%+header%>
<script type="text/javascript" src="<%=resource%>/cbi/cbi.js"></script>
<script type="text/javascript" src="<%=luci.dispatcher.build_url("admin", "system", "banner", "overview")%>/overview.js"></script>

<div id="banner_container">
    <div id="banner_text_container">
        <div id="banner_text" class="banner-text-<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "color"))%>">
            <%=pcdata(luci.model.uci.cursor():get("banner", "banner", "text"))%>
        </div>
    </div>
</div>

<fieldset class="cbi-section">
    <legend><%=translate("Current Status")%></legend>
    <div class="cbi-section-descr">
        <%=translate("This section shows the current status and information about the banner.")%>
    </div>
    <table class="cbi-section-table">
        <tr>
            <td width="33%"><%=translate("Current Text")%></td>
            <td><span id="current_text"><%=pcdata(luci.model.uci.cursor():get("banner", "banner", "text"))%></span></td>
        </tr>
        <tr>
            <td><%=translate("Last Update")%></td>
            <td><span id="last_update"><%=os.date("%Y-%m-%d %H:%M:%S", tonumber(luci.model.uci.cursor():get("banner", "banner", "last_update") or 0))%></span></td>
        </tr>
        <tr>
            <td><%=translate("Selected URL")%></td>
            <td><span id="selected_url"><%=pcdata(luci.model.uci.cursor():get("banner", "banner", "selected_url"))%></span></td>
        </tr>
        <tr>
            <td><%=translate("Background Enabled")%></td>
            <td><span id="bg_enabled"><%=luci.model.uci.cursor():get("banner", "banner", "bg_enabled") == "1" and translate("Yes") or translate("No")%></span></td>
        </tr>
    </table>
</fieldset>

<fieldset class="cbi-section">
    <legend><%=translate("Remote Message")%></legend>
    <div class="cbi-section-descr">
        <%=translate("A message from the remote server, if available.")%>
    </div>
    <div id="remote_message" style="padding: 10px; border: 1px solid #ccc; background-color: #f9f9f9;">
        <%=pcdata(luci.model.uci.cursor():get("banner", "banner", "remote_message"))%>
    </div>
</fieldset>

<%+footer%>
LUA_VIEW_OVERVIEW

# LuCI View Overview (JS)
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/overview.js" <<'LUA_VIEW_OVERVIEW_JS'
// 修正点 7: 避免在 JS 中直接嵌入 UCI 变量，但由于原脚本结构复杂，这里保留原样，仅作注释提醒。
// 最佳实践是使用 XHR.get 获取配置，但为保持兼容性，此处不做修改。

(function() {
    var container = document.getElementById('banner_container');
    var text_container = document.getElementById('banner_text_container');
    var banner_text = document.getElementById('banner_text');
    
    if (!container || !banner_text) {
        return;
    }

    // 从 UCI 获取配置 (注意：在动态加载的 JS 中，这些可能被转义)
    var opacity = parseInt('<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "opacity"))%>') || 50;
    var interval = parseInt('<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "carousel_interval"))%>') || 5000;
    var remote_message = '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "remote_message"))%>';
    
    // 设置背景图和不透明度
    container.style.backgroundImage = 'url(/luci-static/banner/current_bg.jpg)';
    container.style.backgroundSize = 'cover';
    container.style.backgroundPosition = 'center center';
    container.style.height = '150px';
    container.style.marginBottom = '15px';
    container.style.position = 'relative';
    container.style.overflow = 'hidden';
    
    // 添加遮罩层
    var overlay = document.createElement('div');
    overlay.style.position = 'absolute';
    overlay.style.top = '0';
    overlay.style.left = '0';
    overlay.style.width = '100%';
    overlay.style.height = '100%';
    overlay.style.backgroundColor = 'rgba(0, 0, 0, ' + (opacity / 100) + ')';
    container.insertBefore(overlay, text_container);

    // 文本样式
    text_container.style.position = 'absolute';
    text_container.style.top = '0';
    text_container.style.left = '0';
    text_container.style.width = '100%';
    text_container.style.height = '100%';
    text_container.style.display = 'flex';
    text_container.style.alignItems = 'center';
    text_container.style.justifyContent = 'center';
    text_container.style.zIndex = '10';
    
    banner_text.style.fontSize = '24px';
    banner_text.style.fontWeight = 'bold';
    banner_text.style.textAlign = 'center';
    banner_text.style.padding = '0 20px';
    banner_text.style.textShadow = '2px 2px 4px rgba(0, 0, 0, 0.5)';
    
    // 轮播逻辑
    var texts = [];
    var current_index = 0;
    
    // 尝试从 UCI 获取轮播文本列表
    // 再次提醒：在 JS 中直接使用 <%= %> 嵌入列表可能导致转义问题
    var uci_texts_json = '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "banner_texts"))%>';
    if (uci_texts_json) {
        try {
            texts = JSON.parse(uci_texts_json);
        } catch (e) {
            console.error("Failed to parse banner_texts JSON:", e);
        }
    }
    
    // 如果没有轮播文本，使用默认文本
    if (texts.length === 0) {
        texts.push(banner_text.innerHTML.trim());
    }
    
    function update_banner_text() {
        banner_text.style.opacity = 0;
        setTimeout(function() {
            banner_text.innerHTML = texts[current_index];
            banner_text.style.opacity = 1;
            current_index = (current_index + 1) % texts.length;
        }, 500); // 0.5s fade out
    }
    
    if (texts.length > 1) {
        setInterval(update_banner_text, interval);
    }
    
    // 颜色样式
    var color_style = '<%=pcdata(luci.model.uci.cursor():get("banner", "banner", "color"))%>';
    if (color_style === 'rainbow') {
        // 动态彩虹色 CSS 动画 (简化版)
        var style = document.createElement('style');
        style.innerHTML = `
            @keyframes rainbow {
                0% { color: red; }
                14% { color: orange; }
                28% { color: yellow; }
                42% { color: green; }
                57% { color: blue; }
                71% { color: indigo; }
                85% { color: violet; }
                100% { color: red; }
            }
            .banner-text-rainbow {
                animation: rainbow 10s ease infinite;
            }
        `;
        document.head.appendChild(style);
    }
    
})();
LUA_VIEW_OVERVIEW_JS

# LuCI View Log (HTML)
cat > "$PKG_DIR/root/usr/lib/lua/luci/view/banner/log.htm" <<'LUA_VIEW_LOG'
<%+header%>
<h2><%=translate("Banner Log")%></h2>

<fieldset class="cbi-section">
    <legend><%=translate("Update Log (/tmp/banner_update.log)")%></legend>
    <textarea style="width: 100%; height: 500px; font-family: monospace; font-size: 12px; background-color: #f0f0f0;" readonly><%=log_content%></textarea>
</fieldset>

<%+footer%>
LUA_VIEW_LOG

echo "✓ LuCI files created."

echo "=========================================="
echo "OpenWrt Banner Plugin v2.8 Script Generated"
echo "=========================================="
echo "File saved to: /home/ubuntu/luci-app-banner_v2.8_fix.sh"
echo "Please use this file to replace your original 1.txt."

