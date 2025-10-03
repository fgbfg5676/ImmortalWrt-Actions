#!/bin/bash
#==================================================================================
#  create-banner.sh  —— 云编译专用「单文件」版本
#  用法：bash create-banner.sh
#  输出：$OPENWRT_ROOT/feeds/packages/utils/luci-app-banner（可直接随固件编译）
#==================================================================================
set -e

OPENWRT_ROOT=${OPENWRT_ROOT:-$PWD/openwrt}
FEEDS_PATH=$OPENWRT_ROOT/feeds/packages/utils
PKG_NAME=luci-app-banner
PKG_DIR=$FEEDS_PATH/$PKG_NAME

GITHUB_RAW="https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json"
GITEE_RAW="https://gitee.com/fgbfg5676/openwrt-banner/raw/main/banner.json"
# --- 1. 一次性建完所有深层目录 ---
mkdir -p "$PKG_DIR"/root/{etc/{config,init.d},usr/bin}
mkdir -p "$PKG_DIR"/luasrc/{controller,view/banner}
mkdir -p "$PKG_DIR"/htdocs/luci-static/banner
# 1. 生成目录
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"/root/etc/config
mkdir -p "$PKG_DIR"/root/etc/init.d
mkdir -p "$PKG_DIR"/root/usr/bin
mkdir -p "$PKG_DIR"/luasrc/controller
mkdir -p "$PKG_DIR"/luasrc/view
mkdir -p "$PKG_DIR"/htdocs/luci-static/banner

# 2. Makefile
cat > "$PKG_DIR/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk
PKG_NAME:=luci-app-banner
PKG_VERSION:=1.0
PKG_RELEASE:=1
LUCI_TITLE:=Banner福利导航（云编译版）
LUCI_DEPENDS:=+curl +jsonfilter
LUCI_PKGARCH:=all
include $(TOPDIR)/feeds/luci/luci.mk
define Package/luci-app-banner/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller $(1)/usr/lib/lua/luci/view/banner
	$(INSTALL_DIR) $(1)/www/luci-static/banner
	$(INSTALL_CONF) ./root/etc/config/banner $(1)/etc/config/banner
	$(INSTALL_BIN) ./root/etc/init.d/banner $(1)/etc/init.d/banner
	$(INSTALL_BIN) ./root/usr/bin/banner_{manual,auto}_update ./root/usr/bin/banner_bg_loader $(1)/usr/bin/
	$(INSTALL_DATA) ./luasrc/controller/banner.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/view/*.htm $(1)/usr/lib/lua/luci/view/banner/
	$(INSTALL_DATA) ./htdocs/luci-static/banner/* $(1)/www/luci-static/banner/
endef
$(eval $(call BuildPackage,luci-app-banner))
EOF

# 3. 默认配置（自动更新参数锁定）
cat > "$PKG_DIR/root/etc/config/banner" <<EOF
config banner 'banner'
	option text '🎉 新春特惠 · 技术支持24/7 · 已服务500+用户 · 安全稳定运行'
	option color 'rainbow'
	option opacity '50'
	option bg_group '1'
	option bg_enabled '1'
	option current_bg '0'
	option update_url '$GITHUB_RAW'
	option backup_url '$GITEE_RAW'
	option update_interval '86400'
	option last_update '0'
	option banner_texts ''
EOF

# 4. 手动更新脚本（无锁，立即执行，覆盖缓存）
cat > "$PKG_DIR/root/usr/bin/banner_manual_update" <<'EOF'
#!/bin/sh
CACHE="/tmp/banner_cache"; mkdir -p "$CACHE"
LOG="$CACHE/manual.log"; exec 1>>"$LOG" 2>&1
echo "[$(date '+%F %T')] ===== 手动更新开始 ====="
PRI=$(uci -q get banner.banner.update_url); BAK=$(uci -q get banner.banner.backup_url)
download(){
  local url=$1 name=$2
  for i in 1 2 3; do
    curl -sL --max-time 15 "$url" -o "$CACHE/banner_new.json" && \
    grep -q '"text"' "$CACHE/banner_new.json" && { echo "[✓] $name 第$i次成功"; return 0; }
    echo "[×] $name 第$i次失败"; sleep 2
  done; return 1
}
download "$PRI" "GitHub" || download "$BAK" "Gitee" || { echo "[×] 所有源失败"; exit 1; }
TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
COLOR=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null)
TEXTS=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
[ -n "$TEXT" ] && {
  uci set banner.banner.text="$TEXT"
  uci set banner.banner.color="${COLOR:-rainbow}"
  [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
  uci set banner.banner.last_update=$(date +%s)
  uci commit banner
  cp -f "$CACHE/banner_new.json" "$CACHE/nav_data.json"
  echo "[✓] 手动更新完成"
}
EOF
chmod +x "$PKG_DIR/root/usr/bin/banner_manual_update"

# 5. 自动更新脚本（procd 服务，开机+24h）
cat > "$PKG_DIR/root/usr/bin/banner_auto_update" <<'EOF'
#!/bin/sh
CACHE="/tmp/banner_cache"; LOCK="/tmp/banner_auto.lock"
[ -f "$LOCK" ] && exit 0; trap "rm -f $LOCK" EXIT; touch "$LOCK"
mkdir -p "$CACHE"; LOG="$CACHE/auto.log"; exec 1>>"$LOG" 2>&1
LAST=$(uci -q get banner.banner.last_update || echo 0); NOW=$(date +%s); INTERVAL=86400
[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0
echo "[$(date '+%F %T')] ===== 自动更新开始 ====="
PRI=$(uci -q get banner.banner.update_url); BAK=$(uci -q get banner.banner.backup_url)
download(){
  local url=$1 name=$2
  for i in 1 2 3; do
    curl -sL --max-time 15 "$url" -o "$CACHE/banner_new.json" && \
    grep -q '"text"' "$CACHE/banner_new.json" && { echo "[✓] $name 第$i次成功"; return 0; }
    echo "[×] $name 第$i次失败"; sleep 3
  done; return 1
}
download "$PRI" "GitHub" || download "$BAK" "Gitee" || { echo "[×] 所有源失败"; exit 1; }
TEXT=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.text' 2>/dev/null)
COLOR=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.color' 2>/dev/null)
TEXTS=$(jsonfilter -i "$CACHE/banner_new.json" -e '@.banner_texts[*]' 2>/dev/null | tr '\n' '|')
[ -n "$TEXT" ] && {
  uci set banner.banner.text="$TEXT"
  uci set banner.banner.color="${COLOR:-rainbow}"
  [ -n "$TEXTS" ] && uci set banner.banner.banner_texts="$TEXTS"
  uci set banner.banner.last_update=$NOW
  uci commit banner
  cp -f "$CACHE/banner_new.json" "$CACHE/nav_data.json"
  echo "[✓] 自动更新完成"
}
EOF
chmod +x "$PKG_DIR/root/usr/bin/banner_auto_update"

# 6. 背景图加载器
cat > "$PKG_DIR/root/usr/bin/banner_bg_loader" <<'EOF'
#!/bin/sh
BG_GROUP=${1:-1}; CACHE="/tmp/banner_cache"; WEB="/www/luci-static/banner"
mkdir -p "$CACHE" "$WEB"; JSON="$CACHE/nav_data.json"; [ ! -f "$JSON" ] && exit 1
rm -f "$WEB"/bg*.jpg; START_IDX=$(( (BG_GROUP - 1) * 3 + 1 ))
for i in 0 1 2; do
  KEY="background_$((START_IDX + i))"
  URL=$(jsonfilter -i "$JSON" -e "@.$KEY" 2>/dev/null)
  [ -n "$URL" ] && { curl -sL --max-time 15 "$URL" -o "$WEB/bg$i.jpg" && chmod 644 "$WEB/bg$i.jpg"; }
done
cp -f "$WEB/bg0.jpg" "$CACHE/current_bg.jpg" 2>/dev/null
EOF
chmod +x "$PKG_DIR/root/usr/bin/banner_bg_loader"

# 7. procd 启动脚本（开机+24h）
cat > "$PKG_DIR/root/etc/init.d/banner" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/banner_auto_update
  procd_set_param respawn
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
  # 开机立即执行一次
  /usr/bin/banner_auto_update &
  # 加载默认背景组
  sleep 2
  BG_GROUP=$(uci -q get banner.banner.bg_group || echo 1)
  /usr/bin/banner_bg_loader "$BG_GROUP" &
}
EOF
chmod +x "$PKG_DIR/root/etc/init.d/banner"

# 8. LuCI 控制器
cat > "$PKG_DIR/luasrc/controller/banner.lua" <<'EOF'
module("luci.controller.banner", package.seeall)
function index()
  entry({"admin", "status", "banner"}, alias("admin", "status", "banner", "display"), _("福利导航"), 98).dependent=false
  entry({"admin", "status", "banner", "display"}, call("action_display"), _("首页展示"), 1)
  entry({"admin", "status", "banner", "settings"}, call("action_settings"), _("远程更新"), 2)
  entry({"admin", "status", "banner", "background"}, call("action_background"), _("背景设置"), 3)
  entry({"admin", "status", "banner", "do_update"}, post("action_do_update")).leaf=true
  entry({"admin", "status", "banner", "do_set_bg"}, post("action_do_set_bg")).leaf=true
  entry({"admin", "status", "banner", "do_clear_cache"}, post("action_do_clear_cache")).leaf=true
  entry({"admin", "status", "banner", "do_load_group"}, post("action_do_load_group")).leaf=true
  entry({"admin", "status", "banner", "do_set_opacity"}, post("action_do_set_opacity")).leaf=true
  entry({"admin", "status", "banner", "do_upload_bg"}, post("action_do_upload_bg")).leaf=true
  entry({"admin", "status", "banner", "do_apply_url"}, post("action_do_apply_url")).leaf=true
end
local function read_json()
  local fs=require"nixio.fs"
  local jsonc=require"luci.jsonc"
  local f=fs.readfile("/tmp/banner_cache/nav_data.json")
  return f and jsonc.parse(f) or nil
end
function action_display()
  local uci=require"luci.model.uci".cursor()
  local nav_data=read_json()
  luci.template.render("banner/display",{
    text=uci:get("banner","banner","text") or "欢迎访问福利导航",
    color=uci:get("banner","banner","color") or "rainbow",
    opacity=uci:get("banner","banner","opacity") or "50",
    current_bg=uci:get("banner","banner","current_bg") or "0",
    banner_texts=uci:get("banner","banner","banner_texts") or "",
    nav_data=nav_data
  })
end
function action_settings()
  local uci=require"luci.model.uci".cursor()
  local fs=require"nixio.fs"
  luci.template.render("banner/settings",{
    text=uci:get("banner","banner","text") or "",
    opacity=uci:get("banner","banner","opacity") or "50",
    last_update=uci:get("banner","banner","last_update") or "0",
    log=fs.readfile("/tmp/banner_cache/manual.log") or "暂无日志"
  })
end
function action_background()
  local uci=require"luci.model.uci".cursor()
  local fs=require"nixio.fs"
  luci.template.render("banner/background",{
    bg_group=uci:get("banner","banner","bg_group") or "1",
    opacity=uci:get("banner","banner","opacity") or "50",
    log=fs.readfile("/tmp/banner_cache/bg.log") or "暂无日志"
  })
end
function action_do_update()
  luci.sys.call("/usr/bin/banner_manual_update >/dev/null 2>&1 &")
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/settings"))
end
function action_do_set_bg()
  local uci=require"luci.model.uci".cursor()
  local bg=luci.http.formvalue("bg")
  if bg then
    uci:set("banner","banner","current_bg",bg)
    uci:commit("banner")
    luci.sys.call("cp /www/luci-static/banner/bg"..bg..".jpg /tmp/banner_cache/current_bg.jpg 2>/dev/null")
  end
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end
function action_do_clear_cache()
  luci.sys.call("rm -f /www/luci-static/banner/bg*.jpg /tmp/banner_cache/*.jpg")
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end
function action_do_load_group()
  local uci=require"luci.model.uci".cursor()
  local group=luci.http.formvalue("group")
  if group then
    uci:set("banner","banner","bg_group",group)
    uci:commit("banner")
    luci.sys.call("/usr/bin/banner_bg_loader "..group.." >/dev/null 2>&1 &")
  end
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end
function action_do_set_opacity()
  local uci=require"luci.model.uci".cursor()
  local opacity=luci.http.formvalue("opacity")
  if opacity then
    uci:set("banner","banner","opacity",opacity)
    uci:commit("banner")
  end
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/display"))
end
function action_do_upload_bg()
  local fs=require"nixio.fs"
  local http=require"luci.http"
  http.setfilehandler(function(meta,chunk,eof)
    if not meta or meta.name~="bg_file" then return end
    local path="/www/luci-static/banner/upload_temp.jpg"
    local fp=io.open(path,chunk and "ab" or "wb")
    if fp then fp:write(chunk); fp:close() end
    if eof and fs.stat(path) then
      luci.sys.call("cp "..path.." /www/luci-static/banner/bg0.jpg; rm -f "..path)
    end
  end)
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end
function action_do_apply_url()
  local url=luci.http.formvalue("custom_bg_url")
  if url and url:match("^https://") then
    luci.sys.call("curl -sL --max-time 15 '"..url.."' -o /www/luci-static/banner/bg0.jpg")
  end
  luci.http.redirect(luci.dispatcher.build_url("admin/status/banner/background"))
end
EOF

# 9. 全局样式（修复白板）
cat > "$PKG_DIR/luasrc/view/banner/global_style.htm" <<<'EOF'
<%
local uci=require"luci.model.uci".cursor()
local opacity=tonumber(uci:get("banner","banner","opacity") or "50")
local alpha=(100-opacity)/100
local bg_num=uci:get("banner","banner","current_bg") or "0"
%>
<style>
html,body,#maincontent,.container,.cbi-map,.cbi-section,#maincontent>.container>.cbi-map>*{
  background:transparent!important;
}
body{
  background:linear-gradient(rgba(0,0,0,<%=alpha%>),rgba(0,0,0,<%=alpha%>)),url(/luci-static/banner/bg<%=bg_num%>.jpg?t=<%=os.time()%>) center/cover fixed!important;
  min-height:100vh;
}
.cbi-map{
  background:rgba(0,0,0,.3)!important;border:1px solid rgba(255,255,255,.1);border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,.2);padding:15px;
}
.cbi-section{
  background:rgba(0,0,0,.2)!important;border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:10px;margin:10px 0;
}
.cbi-value-title,.cbi-section h2,.cbi-map h2{color:white!important;text-shadow:0 2px 4px rgba(0,0,0,.6);}
input[type=text],textarea,select{background:rgba(255,255,255,.9)!important;border:1px solid rgba(255,255,255,.3)!important;color:#333!important;}
.cbi-button{
  background:rgba(66,139,202,.9)!important;border:1px solid rgba(255,255,255,.3)!important;color:white!important;
}
</style>
<script>
(function(){
  var s=document.querySelectorAll('input[type=range][data-realtime=opacity]');
  s.forEach(function(el){
    el.addEventListener('input',function(){
      var v=parseInt(this.value),a=(100-v)/100;
      document.body.style.background='linear-gradient(rgba(0,0,0,'+a+'),rgba(0,0,0,'+a+')),url(/luci-static/banner/bg<%=bg_num%>.jpg?t=<%=os.time()%>) center/cover fixed';
      var d=document.getElementById('opacity-display'); if(d) d.textContent=v+'%';
    });
  });
})();
</script>
EOF

# 10. 首页展示（彩虹渐变+5s轮播）
cat > "$PKG_DIR/luasrc/view/banner/display.htm" <<<'EOF'
<%+header%>
<%+banner/global_style%>
<style>
.banner-hero{background:rgba(0,0,0,.3);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.12);border-radius:15px;padding:25px;margin:20px auto;max-width:1200px;}
.banner-scroll{padding:25px;margin-bottom:50px;text-align:center;font-weight:bold;font-size:20px;border-radius:10px;min-height:60px;display:flex;align-items:center;justify-content:center;
<% if color=='rainbow' then %>background:linear-gradient(90deg,#ff0000,#ff7f00,#ffff00,#00ff00,#0000ff,#4b0082,#9400d3);background-size:400% 400%;animation:rainbow 8s ease infinite;color:white;text-shadow:2px 2px 4px rgba(0,0,0,.5);
<% else %>background:rgba(255,255,255,.15);color:<%=color%>;<% end %>}
@keyframes rainbow{0%,100%{background-position:0% 50%}50%{background-position:100% 50%}}
.banner-contacts{display:flex;justify-content:space-around;gap:25px;margin-bottom:50px;flex-wrap:wrap;}
.contact-card{flex:1;min-width:200px;background:rgba(0,0,0,.3);backdrop-filter:blur(6px);border:1px solid rgba(255,255,255,.18);border-radius:10px;padding:15px;text-align:center;color:white;}
.copy-btn{background:rgba(76,175,80,.9);color:white;border:none;padding:8px 18px;border-radius:5px;cursor:pointer;margin-top:10px;font-weight:bold;}
.copy-btn:hover{background:rgba(76,175,80,1);}
.nav-groups{display:flex;gap:30px;flex-wrap:wrap;justify-content:center;}
.nav-group{min-width:220px;background:rgba(0,0,0,.3);backdrop-filter:blur(6px);border:1px solid rgba(255,255,255,.15);border-radius:10px;padding:15px;cursor:pointer;transition:all .3s;}
.nav-group:hover{background:rgba(0,0,0,.4);transform:translateY(-5px);border-color:#4fc3f7;}
.nav-group-title{font-size:18px;font-weight:bold;color:white;text-align:center;margin-bottom:10px;padding:10px;background:rgba(102,126,234,.6);border-radius:8px;}
.nav-links{display:none;padding:10px;}
.nav-links.active{display:block;}
.nav-links a{display:block;color:#4fc3f7;text-decoration:none;padding:10px;margin:5px 0;border-radius:5px;background:rgba(255,255,255,.1);transition:all .2s;}
.nav-links a:hover{background:rgba(79,195,247,.3);transform:translateX(5px);}
.bg-selector{position:fixed;bottom:30px;right:30px;display:flex;gap:12px;z-index:999;}
.bg-circle{width:60px;height:60px;border-radius:50%;border:3px solid rgba(255,255,255,.8);background-size:cover;cursor:pointer;transition:all .3s;box-shadow:0 4px 15px rgba(0,0,0,.5);}
.bg-circle:hover{transform:scale(1.15);border-color:#4fc3f7;}
</style>
<div class="banner-hero">
  <div class="banner-scroll" id="banner-text"><%=pcdata(text:gsub("\\n"," · "))%></div>
  <div class="banner-contacts">
    <div class="contact-card"><span>📱 Telegram</span><strong>@fgnb111999</strong><button class="copy-btn" onclick="copyText('@fgnb111999')">复制</button></div>
    <div class="contact-card"><span>💬 QQ</span><strong>183452852</strong><button class="copy-btn" onclick="copyText('183452852')">复制</button></div>
    <div class="contact-card"><span>📧 Email</span><strong>niwo5507@gmail.com</strong><button class="copy-btn" onclick="copyText('niwo5507@gmail.com')">复制</button></div>
  </div>
  <% if nav_data and nav_data.nav_tabs then %>
  <div style="margin-top:30px">
    <h3 style="color:white;text-align:center;text-shadow:2px 2px 4px rgba(0,0,0,.6)">🚀 快速导航</h3>
    <div class="nav-groups">
      <% for i,tab in ipairs(nav_data.nav_tabs) do %>
      <div class="nav-group" onmouseenter="showLinks(this)" onclick="toggleLinks(this)">
        <div class="nav-group-title"><%=pcdata(tab.title)%></div>
        <div class="nav-links">
          <% for _,link in ipairs(tab.links) do %>
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
// 5s 轮播
(function(){
  var texts='<%=banner_texts%>'.split('|').filter(function(t){return t.trim();});
  if(texts.length>1){
    var idx=0,el=document.getElementById('banner-text');
    setInterval(function(){
      idx=(idx+1)%texts.length;
      el.style.opacity='0';
      setTimeout(function(){el.textContent=texts[idx];el.style.opacity='1';},300);
    },5000);
    el.style.transition='opacity .3s';
  }
})();
function showLinks(el){document.querySelectorAll('.nav-links').forEach(function(l){l.classList.remove('active');});el.querySelector('.nav-links').classList.add('active');}
function toggleLinks(el){el.querySelector('.nav-links').classList.toggle('active');}
function changeBg(n){
  var f=document.createElement('form');f.method='POST';f.action='<%=luci.dispatcher.build_url("admin/status/banner/do_set_bg")%>';
  f.innerHTML='<input type="hidden" name="token" value="<%=token%>"><input type="hidden" name="bg" value="'+n+'">';
  document.body.appendChild(f);f.submit();
}
function copyText(txt){
  var ta=document.createElement('textarea');ta.value=txt;ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();
  try{document.execCommand('copy');alert('已复制: '+txt);}catch(e){prompt('请手动复制：',txt);}
  document.body.removeChild(ta);
}
</script>
<%+footer%>
EOF

# 11. 设置页面
cat > "$PKG_DIR/luasrc/view/banner/settings.htm" <<<'EOF'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
  <h2>远程更新设置</h2>
  <div class="cbi-section"><div class="cbi-section-node">
    <div class="cbi-value">
      <label class="cbi-value-title">实时透明度调节</label>
      <div class="cbi-value-field">
        <input type="range" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:70%"/>
        <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
        <p style="color:#aaa;font-size:12px">💡 拖动即刻生效（刷新页面恢复）</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">公告文本</label>
      <div class="cbi-value-field">
        <textarea readonly style="width:100%;height:80px;background:rgba(255,255,255,.9);color:#333"><%=pcdata(text)%></textarea>
        <p style="color:#aaa;font-size:12px">📌 由远程仓库控制</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">自动更新间隔</label>
      <div class="cbi-value-field">
        <input type="text" value="86400 秒 (24小时)" disabled style="background:rgba(200,200,200,.5);color:#333">
        <p style="color:#5cb85c;font-size:12px">✓ 已启用 (系统锁定，不可修改)</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">上次更新</label>
      <div class="cbi-value-field">
        <input type="text" value="<%= last_update=='0' and '从未更新' or os.date('%Y-%m-%d %H:%M:%S', tonumber(last_update)) %>" readonly style="width:100%;background:rgba(255,255,255,.9);color:#333">
      </div>
    </div>
    <div class="cbi-value">
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_update')%>">
          <input type="hidden" name="token" value="<%=token%>"/>
          <input type="submit" class="cbi-button cbi-button-apply" value="立即手动更新"/>
        </form>
        <p style="color:#aaa;font-size:12px">🔄 不受24小时限制，立即执行</p>
      </div>
    </div>
    <h3 style="color:white">更新日志 (最近20条)</h3>
    <div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,.1)"><%=pcdata(log)%></div>
  </div></div>
</div>
<%+footer%>
EOF

# 12. 背景设置页面
cat > "$PKG_DIR/luasrc/view/banner/background.htm" <<<'EOF'
<%+header%>
<%+banner/global_style%>
<div class="cbi-map">
  <h2>背景图设置</h2>
  <div class="cbi-section"><div class="cbi-section-node">
    <div class="cbi-value">
      <label class="cbi-value-title">实时透明度调节</label>
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_set_opacity')%>">
          <input type="hidden" name="token" value="<%=token%>"/>
          <input type="range" name="opacity" min="0" max="100" value="<%=opacity%>" data-realtime="opacity" style="width:60%"/>
          <span id="opacity-display" style="color:white;margin-left:10px;font-weight:bold"><%=opacity%>%</span>
          <input type="submit" class="cbi-button cbi-button-apply" value="保存透明度"/>
        </form>
        <p style="color:#aaa;font-size:12px">💡 拖动滑块实时预览，点击保存以持久化</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">选择背景图组</label>
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_load_group')%>">
          <input type="hidden" name="token" value="<%=token%>"/>
          <select name="group" style="flex:1;background:rgba(255,255,255,.9);color:#333">
            <option value="1" <%=bg_group=='1' and 'selected' or ''%>>第 1 组 (背景1-3)</option>
            <option value="2" <%=bg_group=='2' and 'selected' or ''%>>第 2 组 (背景4-6)</option>
            <option value="3" <%=bg_group=='3' and 'selected' or ''%>>第 3 组 (背景7-9)</option>
            <option value="4" <%=bg_group=='4' and 'selected' or ''%>>第 4 组 (背景10-12)</option>
          </select>
          <input type="submit" class="cbi-button cbi-button-apply" value="加载背景组"/>
        </form>
        <p style="color:#aaa;font-size:12px">💡 选择后自动下载并缓存对应组的三张图片</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">远程数据源</label>
      <div class="cbi-value-field">
        <span style="background:#d4edda;color:#155724;padding:5px 10px;border-radius:5px;font-weight:bold">当前数据源: GitHub (🔒 HTTPS)</span>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">手动填写背景图链接</label>
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_apply_url')%>">
          <input type="hidden" name="token" value="<%=token%>"/>
          <input type="text" name="custom_bg_url" placeholder="https://example.com/image.jpg" style="width:65%;background:rgba(255,255,255,.9);color:#333"/>
          <input type="submit" class="cbi-button cbi-button-apply" value="应用链接"/>
        </form>
        <p style="color:#aaa;font-size:12px">📌 仅支持 HTTPS 链接（JPG/PNG），应用后覆盖 bg0.jpg</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">从本地上传背景图</label>
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_upload_bg')%>" enctype="multipart/form-data">
          <input type="hidden" name="token" value="<%=token%>"/>
          <input type="file" name="bg_file" accept="image/jpeg,image/png"/>
          <input type="submit" class="cbi-button cbi-button-apply" value="上传并应用"/>
        </form>
        <p style="color:#aaa;font-size:12px">📤 支持 JPG/PNG，上传后覆盖 bg0.jpg</p>
      </div>
    </div>
    <div class="cbi-value">
      <label class="cbi-value-title">删除缓存图片</label>
      <div class="cbi-value-field">
        <form method="post" action="<%=luci.dispatcher.build_url('admin/status/banner/do_clear_cache')%>">
          <input type="hidden" name="token" value="<%=token%>"/>
          <input type="submit" class="cbi-button cbi-button-remove" value="删除缓存"/>
        </form>
        <p style="color:#aaa;font-size:12px">🗑️ 清空所有 bg*.jpg 缓存</p>
      </div>
    </div>
    <h3 style="color:white">背景日志 (最近20条)</h3>
    <div style="background:rgba(0,0,0,.5);padding:12px;border-radius:8px;max-height:250px;overflow-y:auto;font-family:monospace;font-size:12px;color:#0f0;white-space:pre-wrap;border:1px solid rgba(255,255,255,.1)"><%=pcdata(log)%></div>
  </div></div>
</div>
<%+footer%>
EOF

# 13. 默认占位背景（1x1 透明像素，避免 404）
echo -ne '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0bIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd4c\x00\x00\x00\x00IEND\xaeB`\x82' \
> "$PKG_DIR/htdocs/luci-static/banner/bg0.jpg"

echo "=========================================="
echo "✓ 已生成完整软件包目录："
echo "    $PKG_DIR"
echo "下一步："
echo "    cd $OPENWRT_ROOT"
echo "    ./scripts feeds update -a"
echo "    ./scripts feeds install -a"
echo "    make menuconfig  # 选 LuCI -> Applications -> luci-app-banner"
echo "    make package/feeds/packages/luci-app-banner/compile V=s"
echo "=========================================="
