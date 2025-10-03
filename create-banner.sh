#!/bin/sh
# OpenWrt 横幅福利导航插件 - 云编译安装脚本
# 版本: v2.0 优化版
# 功能: 修复白板、独立更新机制、轮播横幅、多主题兼容

echo "=========================================="
echo "OpenWrt 横幅插件云编译版安装"
echo "版本: v2.0 | 优化版"
echo "=========================================="

# 检测运行环境
if [ -w "/usr/lib" ]; then
    # 真实 OpenWrt 环境或有写权限
    TARGET_ROOT=""
    echo "检测到 OpenWrt 环境，直接安装..."
else
    # 云编译环境，使用相对路径
    if [ -n "$GITHUB_WORKSPACE" ]; then
        TARGET_ROOT="$GITHUB_WORKSPACE/openwrt/package/custom/luci-app-banner"
    elif [ -d "openwrt" ]; then
        TARGET_ROOT="$(pwd)/openwrt/package/custom/luci-app-banner"
    else
        TARGET_ROOT="./luci-app-banner"
    fi
    echo "检测到云编译环境，安装到: $TARGET_ROOT"
    mkdir -p "$TARGET_ROOT"
fi

# 清理旧版本
echo "[1/16] 清理旧版本文件..."
rm -rf "${TARGET_ROOT}/tmp/luci-banner" \
       "${TARGET_ROOT}/www" \
       "${TARGET_ROOT}/etc" \
       "${TARGET_ROOT}/usr" 2>/dev/null || true

# 创建目录结构
echo "[2/16] 创建目录结构..."
mkdir -p "${TARGET_ROOT}/usr/lib/lua/luci/view/banner" \
         "${TARGET_ROOT}/www/luci-static/banner" \
         "${TARGET_ROOT}/tmp/banner_cache" \
         "${TARGET_ROOT}/usr/bin" \
         "${TARGET_ROOT}/etc/config" \
         "${TARGET_ROOT}/etc/cron.d" \
         "${TARGET_ROOT}/etc/init.d" \
         "${TARGET_ROOT}/usr/lib/lua/luci/controller"

# 初始化 UCI 配置
echo "[3/16] 初始化 UCI 配置..."
cat > /etc/config/banner <<'UCICONF'
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
UCICONF

# 手动更新脚本
echo "[4/16] 创建手动更新脚本..."
cat > /usr/bin/banner_manual_update.sh <<'MANUALUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
mkdir -p "$CACHE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

log "========== 手动更新开始 =========="

PRI=$(uci -q get banner.banner.update_url)
BAK=$(uci -q get banner.banner.backup_url)

# GitHub 3次重试
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

# Gitee 3次重试
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

# 更新 UCI
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
MANUALUPDATE
chmod +x /usr/bin/banner_manual_update.sh

# 自动更新脚本
echo "[5/16] 创建自动更新脚本..."
cat > /usr/bin/banner_auto_update.sh <<'AUTOUPDATE'
#!/bin/sh
LOG="/tmp/banner_update.log"
CACHE="/tmp/banner_cache"
LOCK="/tmp/banner_auto_update.lock"
mkdir -p "$CACHE"

# 防重复执行锁
[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap "rm -f $LOCK" EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

LAST=$(uci -q get banner.banner.last_update || echo 0)
NOW=$(date +%s)
INTERVAL=86400

# 距离上次更新不足24小时，跳过
[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0

log "========== 自动更新开始 =========="

PRI="https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"
BAK="https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json"

# GitHub 3次重试
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

# Gitee 3次重试
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

# 更新 UCI
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
AUTOUPDATE
chmod +x /usr/bin/banner_auto_update.sh

# 背景图加载器
echo "[6/16] 创建背景图加载器..."
cat > /usr/bin/banner_bg_loader.sh <<'BGLOADER'
#!/bin/sh
BG_GROUP=${1:-1}
LOG="/tmp/banner_bg.log"
CACHE="/tmp/banner_cache"
WEB="/www/luci-static/banner"
mkdir -p "$CACHE" "$WEB"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    tail -n 20 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

log "加载第 ${BG_GROUP} 组背景图..."

START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))
JSON="$CACHE/nav_data.json"

[ ! -f "$JSON" ] && log "[×] 数据文件未找到" && exit 1

rm -f "$WEB"/bg*.jpg

for i in 0 1 2; do
    KEY="background_$((START_IDX + i))"
    URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
    if [ -n "$URL" ]; then
        log "  下载 $KEY..."
        curl -sL --max-time 15 "$URL" -o "$WEB/bg$i.jpg" 2>/dev/null
        if [ -s "$WEB/bg$i.jpg" ]; then
            chmod 644 "$WEB/bg$i.jpg"
            log "  [√] bg$i.jpg"
        else
            log "  [×] bg$i.jpg 失败"
        fi
    fi
done

cp "$WEB/bg0.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
log "[完成] 第 ${BG_GROUP} 组"
BGLOADER
chmod +x /usr/bin/banner_bg_loader.sh

# 定时任务
echo "[7/16] 配置定时任务..."
cat > /etc/cron.d/banner <<'CRON'
0 * * * * root /usr/bin/banner_auto_update.sh
CRON

# 开机自启动
echo "[8/16] 配置开机自启动..."
cat > /etc/init.d/banner <<'INIT'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    /usr/bin/banner_auto_update.sh >/dev/null 2>&1 &
    sleep 2
    BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
    /usr/bin/banner_bg_loader.sh "$BG_GROUP" >/dev/null 2>&1 &
}
INIT
chmod +x /etc/init.d/banner
/etc/init.d/banner enable

# LuCI 控制器
echo "[9/16] 创建 LuCI 控制器..."
cat > /usr/lib/lua/luci/controller/banner.lua <<'CONTROLLER'
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
    entry({"admin", "status", "banner", "do_set_opacity"}, post("action_do_set_opacity")).leaf = true
    entry({"admin", "status", "banner", "do_upload_bg"}, post("action_do_upload_bg")).leaf = true
    entry({"admin", "status", "banner", "do_apply_url"}, post("action_do_apply_url")).leaf = true
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
        current_bg = uci:get("banner", "banner", "current_bg") or "0",
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
        luci.sys.call(string.format("cp /www/luci-static/banner/bg%s.jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null", bg))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_clear_cache()
    luci.sys.call("rm -rf /tmp/banner_cache/*.jpg /www/luci-static/banner/bg*.jpg")
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

function action_do_set_opacity()
    local uci = require "luci.model.uci".cursor()
    local opacity = luci.http.formvalue("opacity")
    if opacity then
        uci:set("banner", "banner", "opacity", opacity)
        uci:commit("banner")
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end

function action_do_upload_bg()
    local fs = require "nixio.fs"
    local http = require "luci.http"
    http.setfilehandler(function(meta, chunk, eof)
        if not meta then return end
        if meta.name == "bg_file" then
            local path = "/www/luci-static/banner/upload_temp.jpg"
            if chunk then
                local fp = io.open(path, meta.file and "ab" or "wb")
                if fp then fp:write(chunk); fp:close() end
            end
            if eof and fs.stat(path) then
                luci.sys.call("cp " .. path .. " /www/luci-static/banner/bg0.jpg")
                luci.sys.call("rm -f " .. path)
                local log = fs.readfile("/tmp/banner_bg.log") or ""
                fs.writefile("/tmp/banner_bg.log", log .. "\n[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] 本地上传成功")
            end
        end
    end)
    http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end

function action_do_apply_url()
    local url = luci.http.formvalue("custom_bg_url")
    if url and url:match("^https://") then
        luci.sys.call(string.format("curl -sL --max-time 15 '%s' -o /www/luci-static/banner/bg0.jpg 2>/dev/null", url))
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end
CONTROLLER

# 全局样式（修复白板问题）
echo "[10/16] 创建全局样式模板..."
cat > /usr/lib/lua/luci/view/banner/global_style.htm <<'GLOBALSTYLE'
<%
local uci = require "luci.model.uci".cursor()
local opacity = tonumber(uci:get("banner", "banner", "opacity") or "50")
local alpha = (100 - opacity) / 100
local bg_num = tonumber(uci:get("banner", "banner", "current_bg") or "0")
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
                url(/luci-static/banner/bg<%=bg_num%>.jpg?t=<%=os.time()%>) center/cover fixed !important;
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
                'url(/luci-static/banner/bg<%=bg_num%>.jpg?t=<%=os.time()%>) center/cover fixed';
            var display = document.getElementById('opacity-display');
            if (display) display.textContent = val + '%';
        });
    });
})();
</script>
GLOBALSTYLE

# 首页展示（带轮播横幅）
echo "[11/16] 创建首页展示模板..."
cat > /usr/lib/lua/luci/view/banner/display.htm <<'DISPLAYVIEW'
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
<div class="banner-hero">
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
        <div class="nav-groups">
            <% for i, tab in ipairs(nav_data.nav_tabs) do %>
            <div class="nav-group" onmouseenter="showLinks(this)" onclick="toggleLinks(this)">
                <div class="nav-group-title"><%=pcdata(tab.title)%></div>
                <div class="nav-links">
                    <% for _, link in ipairs(tab.links) do %>
                    <a href="<%=pcdata(link.url)%>" target="_blank"><%=pcdata(link.name)%></a>
                    <% end %>
                </div>
            </div>
            <% end %>
        </div>
    </div>
    <% end %>
</div>
<div class="bg-selector">
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg0.jpg?t=<%=os.time()%>)" onclick="changeBg(0)"></div>
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg1.jpg?t=<%=os.time()%>)" onclick="changeBg(1)"></div>
    <div class="bg-circle" style="background-image:url(/luci-static/banner/bg2.jpg?t=<%=os.time()%>)" onclick="changeBg(2)"></div>
</div>
<script>
// 轮播横幅（每5秒切换）
(function() {
    var bannerTexts = '<%=banner_texts%>'.split('|').filter(function(t) { return t.trim(); });
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
        }, 5000);
        elem.style.transition = 'opacity 0.3s';
    }
})();

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
echo "[12/16] 创建设置页面模板..."
cat > /usr/lib/lua/luci/view/banner/settings.htm <<'SETTINGSVIEW'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
    <h2>远程更新设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <div class="cbi-value">
            <label class="cbi-value-title">实时透明度调节</label>
            <div class="cbi-value-field">
                <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%" />
                <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                <p style="color:#aaa;font-size:12px">拖动即刻生效（刷新页面恢复）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">公告文本</label>
            <div class="cbi-value-field">
                <textarea readonly style="width:100%;height:80px;background:rgba(255,255,255,0.9);color:#333"><%=pcdata(text)%></textarea>
                <p style="color:#aaa;font-size:12px">由远程仓库控制</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">自动更新间隔</label>
            <div class="cbi-value-field">
                <input type="text" value="86400 秒 (24小时)" disabled style="background:rgba(200,200,200,0.5);color:#333">
                <p style="color:#5cb85c;font-size:12px">已启用（系统锁定，不可修改）</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">HTTPS 强制</label>
            <div class="cbi-value-field">
                <span style="background:#d4edda;color:#155724;padding:5px 10px;border-radius:5px;font-weight:bold">已启用</span>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">上次更新</label>
            <div class="cbi-value-field">
                <input type="text" value="<%= last_update == '0' and '从未更新' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update)) %>" readonly style="width:100%;background:rgba(255,255,255,0.9);color:#333">
            </div>
        </div>
        <div class="cbi-value">
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_update')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="submit" class="cbi-button cbi-button-apply" value="立即手动更新" />
                </form>
                <p style="color:#aaa;font-size:12px">不受24小时限制，立即执行</p>
            </div>
        </div>
        <h3 style="color:white">更新日志（最近20条）</h3>
        <div style="background:rgba(0,0,0,0.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,0.1)"><%=pcdata(log)%></div>
    </div></div>
</div>
<%+footer%>
SETTINGSVIEW

# 背景设置页面
echo "[13/16] 创建背景设置页面模板..."
cat > /usr/lib/lua/luci/view/banner/background.htm <<'BGVIEW'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
    <h2>背景图设置</h2>
    <div class="cbi-section"><div class="cbi-section-node">
        <div class="cbi-value">
            <label class="cbi-value-title">实时透明度调节</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_opacity')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="range" name="opacity" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:60%" />
                    <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
                    <input type="submit" class="cbi-button cbi-button-apply" value="保存透明度" />
                </form>
                <p style="color:#aaa;font-size:12px">拖动滑块实时预览，点击保存以持久化</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">选择背景图组</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_load_group')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <select name="group" style="flex:1;background:rgba(255,255,255,0.9);color:#333">
                        <option value="1" <%=bg_group=='1' and 'selected' or ''%>>第 1 组（背景1-3）</option>
                        <option value="2" <%=bg_group=='2' and 'selected' or ''%>>第 2 组（背景4-6）</option>
                        <option value="3" <%=bg_group=='3' and 'selected' or ''%>>第 3 组（背景7-9）</option>
                        <option value="4" <%=bg_group=='4' and 'selected' or ''%>>第 4 组（背景10-12）</option>
                    </select>
                    <input type="submit" class="cbi-button cbi-button-apply" value="加载背景组" />
                </form>
                <p style="color:#aaa;font-size:12px">选择后自动下载并缓存对应组的三张图片</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">远程数据源</label>
            <div class="cbi-value-field">
                <span style="background:#d4edda;color:#155724;padding:5px 10px;border-radius:5px;font-weight:bold">当前数据源: GitHub（HTTPS）</span>
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
                <p style="color:#aaa;font-size:12px">仅支持 HTTPS 链接（JPG/PNG），应用后覆盖 bg0.jpg</p>
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
                <p style="color:#aaa;font-size:12px">支持 JPG/PNG，上传后覆盖 bg0.jpg</p>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title">删除缓存图片</label>
            <div class="cbi-value-field">
                <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_clear_cache')%>">
                    <input type="hidden" name="token" value="<%=token%>" />
                    <input type="submit" class="cbi-button cbi-button-remove" value="删除缓存" />
                </form>
                <p style="color:#aaa;font-size:12px">清空所有 bg*.jpg 缓存</p>
            </div>
        </div>
        <h3 style="color:white">背景日志（最近20条）</h3>
        <div style="background:rgba(0,0,0,0.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,0.1)"><%=pcdata(log)%></div>
    </div></div>
</div>
<script>
// 实时透明度预览（当前页面生效，保存后持久化）
(function() {
    var slider = document.querySelector('input[type="range"][data-realtime="opacity"]');
    var display = document.getElementById('opacity-display');
    if (slider && display) {
        slider.addEventListener('input', function() {
            var val = parseInt(this.value);
            var a = (100 - val) / 100;
            document.body.style.background = 
                'linear-gradient(rgba(0,0,0,' + a + '), rgba(0,0,0,' + a + ')), ' +
                'url(/luci-static/banner/bg<%=current_bg or 0%>.jpg?t=<%=os.time()%>) center/cover fixed';
            display.textContent = val + '%';
        });
    }
})();
</script>
<%+footer%>
BGVIEW

# 检查依赖
echo "[14/16] 检查系统依赖..."
MISSING_DEPS=""
for cmd in curl jsonfilter; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "警告：缺少依赖项:$MISSING_DEPS"
    echo "请执行: opkg update && opkg install$MISSING_DEPS"
fi

# 重启 LuCI
echo "[15/16] 重启 LuCI 服务..."
/etc/init.d/nginx restart 2>/dev/null || /etc/init.d/uhttpd restart 2>/dev/null || true

# 首次执行更新和背景加载
echo "[16/16] 执行首次数据更新..."
/usr/bin/banner_manual_update.sh >/dev/null 2>&1 &
sleep 3
/usr/bin/banner_bg_loader.sh 1 >/dev/null 2>&1 &

echo ""
echo "=========================================="
echo "安装完成"
echo "=========================================="
echo ""
echo "访问路径: LuCI > 状态 > 福利导航"
echo ""
echo "主要功能:"
echo "  [1] 三个页面统一背景显示（修复白板问题）"
echo "  [2] 独立更新机制:"
echo "      - 手动更新: 立即执行，无需等待"
echo "      - 自动更新: 开机一次 + 每24小时一次"
echo "  [3] 轮播横幅: 彩虹渐变，每5秒切换"
echo "  [4] 多主题兼容: Argon、Bootstrap等"
echo "  [5] 本地上传/远程链接双重支持"
echo "  [6] 12张背景图支持（4组，每组3张）"
echo ""
echo "JSON 数据结构示例:"
echo "{"
echo '  "text": "默认横幅文本",'
echo '  "color": "rainbow",'
echo '  "banner_texts": ['
echo '    "横幅文本1",'
echo '    "横幅文本2",'
echo '    "横幅文本3"'
echo "  ],"
echo '  "background_1": "https://...",'
echo "  ..."
echo '  "background_12": "https://...",'
echo '  "nav_tabs": ['
echo "    {"
echo '      "title": "工具",'
echo '      "links": ['
echo '        {"name": "Google", "url": "https://www.google.com"}'
echo "      ]"
echo "    }"
echo "  ]"
echo "}"
echo ""
echo "仓库地址:"
echo "  GitHub: https://github.com/fgbfg5676/openwrt-banner"
echo "  Gitee:  https://gitee.com/fgbfg5676/openwrt-banner"
echo ""
echo "=========================================="

exit 0
