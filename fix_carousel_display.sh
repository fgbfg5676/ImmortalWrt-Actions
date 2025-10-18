#!/bin/bash

echo "=== 修复轮播显示问题 ==="
echo "问题：首页轮播内容显示区域只识别了JSON里的3个文件，实际有15个文件"
echo ""

# 1. 检查当前的JSON文件
echo "1. 检查当前缓存的JSON文件..."
CACHE_JSON="/tmp/banner_cache/nav_data.json"
if [ -f "$CACHE_JSON" ]; then
    echo "找到缓存JSON文件: $CACHE_JSON"
    echo "文件大小: $(wc -c < "$CACHE_JSON") 字节"
    
    # 检查carousel_files数量
    if command -v jq >/dev/null 2>&1; then
        CAROUSEL_COUNT=$(jq '.carousel_files | length' "$CACHE_JSON" 2>/dev/null)
        echo "当前carousel_files数量: $CAROUSEL_COUNT"
    else
        # 使用grep计算
        CAROUSEL_COUNT=$(grep -c '"name":' "$CACHE_JSON" 2>/dev/null || echo "无法计算")
        echo "当前carousel_files数量(估算): $CAROUSEL_COUNT"
    fi
else
    echo "❌ 未找到缓存JSON文件"
fi

echo ""

# 2. 下载最新的JSON文件进行对比
echo "2. 下载最新的JSON文件进行对比..."
TEMP_JSON="/tmp/latest_banner.json"
if curl -fsSL "https://raw.githubusercontent.com/fgbfg5676/openwrt-banner/main/banner.json" -o "$TEMP_JSON"; then
    echo "✅ 成功下载最新JSON文件"
    echo "文件大小: $(wc -c < "$TEMP_JSON") 字节"
    
    if command -v jq >/dev/null 2>&1; then
        LATEST_COUNT=$(jq '.carousel_files | length' "$TEMP_JSON" 2>/dev/null)
        echo "最新carousel_files数量: $LATEST_COUNT"
    else
        LATEST_COUNT=$(grep -c '"name":' "$TEMP_JSON" 2>/dev/null || echo "无法计算")
        echo "最新carousel_files数量(估算): $LATEST_COUNT"
    fi
else
    echo "❌ 下载最新JSON文件失败"
    exit 1
fi

echo ""

# 3. 对比文件差异
echo "3. 对比缓存文件与最新文件..."
if [ -f "$CACHE_JSON" ]; then
    if diff -q "$CACHE_JSON" "$TEMP_JSON" >/dev/null 2>&1; then
        echo "✅ 缓存文件与最新文件相同"
    else
        echo "⚠️ 缓存文件与最新文件不同"
        echo "建议更新缓存文件"
    fi
else
    echo "⚠️ 无缓存文件，需要创建"
fi

echo ""

# 4. 修复方案
echo "4. 应用修复方案..."

# 创建缓存目录
mkdir -p /tmp/banner_cache

# 更新缓存文件
echo "更新缓存文件..."
cp "$TEMP_JSON" "$CACHE_JSON"
chmod 644 "$CACHE_JSON"
echo "✅ 缓存文件已更新"

# 5. 检查LuCI模板文件
echo ""
echo "5. 检查LuCI模板文件..."
TEMPLATE_FILE="/usr/lib/lua/luci/view/banner/display.htm"
if [ -f "$TEMPLATE_FILE" ]; then
    echo "✅ 找到模板文件: $TEMPLATE_FILE"
    
    # 检查模板中的循环逻辑
    if grep -q "for idx, file in ipairs(nav_data.carousel_files)" "$TEMPLATE_FILE"; then
        echo "✅ 模板循环逻辑正确"
    else
        echo "❌ 模板循环逻辑可能有问题"
    fi
else
    echo "❌ 未找到模板文件"
fi

# 6. 重启相关服务
echo ""
echo "6. 重启相关服务..."
echo "重启uhttpd服务..."
/etc/init.d/uhttpd restart >/dev/null 2>&1

# 清理LuCI缓存
echo "清理LuCI缓存..."
rm -rf /tmp/luci-* 2>/dev/null

# 等待服务重启
sleep 2

echo "✅ 服务已重启"

# 7. 验证修复结果
echo ""
echo "7. 验证修复结果..."
if [ -f "$CACHE_JSON" ]; then
    if command -v jq >/dev/null 2>&1; then
        FINAL_COUNT=$(jq '.carousel_files | length' "$CACHE_JSON" 2>/dev/null)
        echo "最终carousel_files数量: $FINAL_COUNT"
        
        if [ "$FINAL_COUNT" = "15" ]; then
            echo "✅ 修复成功！现在应该能显示所有15个文件"
        else
            echo "⚠️ 文件数量不是15个，可能还有其他问题"
        fi
    else
        echo "✅ JSON文件已更新，请刷新页面查看结果"
    fi
else
    echo "❌ 修复失败"
fi

# 清理临时文件
rm -f "$TEMP_JSON"

echo ""
echo "=== 修复完成 ==="
echo "请刷新浏览器页面查看轮播是否显示所有15个文件"
echo ""
echo "如果问题仍然存在，可能的原因："
echo "1. 浏览器缓存问题 - 请强制刷新页面 (Ctrl+F5)"
echo "2. JSON文件格式问题 - 请检查JSON文件是否有语法错误"
echo "3. 网络问题 - 请检查网络连接"
echo "4. 服务配置问题 - 请检查banner服务配置"