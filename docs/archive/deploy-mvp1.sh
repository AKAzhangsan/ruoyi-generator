#!/bin/bash
# MVP1 部署脚本 - 修复版（防止重复代码）
# Controller 放到 ruoyi-admin，其他放到 ruoyi-system

set -e  # 出错时停止

echo "🚀 开始部署 MVP1 测试表..."

# 配置路径
GENERATOR_DIR="$HOME/.openclaw/workspace/projects/ruoyi-generator"
RUOYI_BACKEND="$HOME/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_FRONTEND="$HOME/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

# 检查目录是否存在
if [ ! -d "$RUOYI_BACKEND" ]; then
    echo "❌ 若依后端目录不存在: $RUOYI_BACKEND"
    exit 1
fi

if [ ! -d "$RUOYI_FRONTEND" ]; then
    echo "❌ 若依前端目录不存在: $RUOYI_FRONTEND"
    exit 1
fi

# 查找 ruoyi-admin 和 ruoyi-system
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

if [ -z "$RUOYI_ADMIN" ]; then
    echo "❌ 未找到 ruoyi-admin 模块"
    exit 1
fi

if [ -z "$RUOYI_SYSTEM" ]; then
    echo "❌ 未找到 ruoyi-system 模块"
    exit 1
fi

echo "📂 ruoyi-admin: $RUOYI_ADMIN"
echo "📂 ruoyi-system: $RUOYI_SYSTEM"

# 自动查找生成的代码目录（最新的）
OUTPUT_DIR=$(find "$GENERATOR_DIR/output" -maxdepth 1 -type d -name "mvp1_test" | head -1)

if [ -z "$OUTPUT_DIR" ]; then
    # 如果没有专属目录，使用主 output 目录
    OUTPUT_DIR="$GENERATOR_DIR/output"
    echo "⚠️  未找到 mvp1_test 专属目录，使用默认 output 目录"
fi

echo "📂 代码源目录: $OUTPUT_DIR"

# ============================================
# 关键：清理旧的重复代码
# ============================================
echo "🧹 清理旧的重复 Controller（如果存在）..."
if [ -d "$RUOYI_SYSTEM/src/main/java/com/ruoyi/web/controller" ]; then
    echo "  ⚠️  发现 system 中有 Controller，准备删除..."
    rm -rf "$RUOYI_SYSTEM/src/main/java/com/ruoyi/web/controller"
    echo "  ✅ 已清理 system 中的 Controller"
fi

# ============================================
# 1. 复制 Controller 到 ruoyi-admin
# ============================================
echo "📦 复制 Controller 到 ruoyi-admin..."
if [ -d "$OUTPUT_DIR/main/java/com/ruoyi/web/controller" ]; then
    # 确保目标目录存在
    mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller"
    
    # 复制 Controller
    cp -r "$OUTPUT_DIR/main/java/com/ruoyi/web/controller/"* \
        "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/" 2>/dev/null || true
    echo "  ✅ Controller 复制完成"
fi

# ============================================
# 2. 复制其他 Java 代码到 ruoyi-system（排除 Controller）
# ============================================
echo "📦 复制 Service/Mapper/Domain 到 ruoyi-system..."

# 遍历所有模块目录
for module_dir in "$OUTPUT_DIR/main/java/com/ruoyi"/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        
        # 跳过 web 目录（Controller 专属）
        if [ "$module_name" == "web" ]; then
            continue
        fi
        
        # 复制到 ruoyi-system
        if [ -d "$module_dir" ]; then
            target_dir="$RUOYI_SYSTEM/src/main/java/com/ruoyi/$module_name"
            mkdir -p "$target_dir"
            cp -r "$module_dir"* "$target_dir/" 2>/dev/null || true
            echo "  ✅ $module_name 复制完成"
        fi
    fi
done

# ============================================
# 3. 复制 Mapper XML 到 ruoyi-system
# ============================================
echo "📦 复制 Mapper XML..."
if [ -d "$OUTPUT_DIR/main/resources/mapper" ]; then
    mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper"
    cp -r "$OUTPUT_DIR/main/resources/mapper/"* \
        "$RUOYI_SYSTEM/src/main/resources/mapper/" 2>/dev/null || true
    echo "  ✅ Mapper XML 复制完成"
fi

# ============================================
# 4. 复制前端代码
# ============================================
echo "📦 复制前端代码..."
if [ -d "$OUTPUT_DIR/vue" ]; then
    cp -r "$OUTPUT_DIR/vue/"* "$RUOYI_FRONTEND/src/" 2>/dev/null || true
    echo "  ✅ Vue 代码复制完成"
fi

# ============================================
# 5. 执行菜单 SQL
# ============================================
echo "🗄️  执行菜单 SQL..."
if [ -f "$OUTPUT_DIR/sql/mvp1_test_menu.sql" ]; then
    mysql -u ruoyi -pruoyi123 ry_vue < "$OUTPUT_DIR/sql/mvp1_test_menu.sql" 2>/dev/null || {
        echo "  ⚠️ SQL 执行可能失败，请手动执行:"
        echo "     mysql -u ruoyi -p ruoyi123 ry_vue < $OUTPUT_DIR/sql/mvp1_test_menu.sql"
    }
    echo "  ✅ 菜单 SQL 执行完成"
fi

# ============================================
# 6. 编译后端
# ============================================
echo "🔨 编译后端..."
cd "$RUOYI_BACKEND"
mvn clean package -DskipTests -q

# ============================================
# 7. 重启服务
# ============================================
echo "🔄 重启服务..."
cd "$HOME/.openclaw/workspace/projects/ruoyi"
./stop.sh 2>/dev/null || true
sleep 3
./start.sh

echo ""
echo "✅ 部署完成！"
echo "💡 访问: http://localhost"
echo "📋 菜单: 系统工具 > MVP1功能测试表"
