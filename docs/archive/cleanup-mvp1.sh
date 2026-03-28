#!/bin/bash
# 清理 MVP1 测试表的所有旧数据（后端 + 前端 + 数据库）

set -e

echo "🧹 开始清理 MVP1 旧数据..."

RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

# 1. 清理后端代码（ruoyi-system 中的 test 模块）
echo "📁 清理 ruoyi-system 中的旧代码..."
if [ -d "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test" ]; then
    rm -rf "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test"
    echo "  ✅ 已删除 test 模块 Java 代码"
fi

if [ -d "$RUOYI_BACKEND/ruoyi-system/src/main/resources/mapper/test" ]; then
    rm -rf "$RUOYI_BACKEND/ruoyi-system/src/main/resources/mapper/test"
    echo "  ✅ 已删除 test 模块 Mapper XML"
fi

# 2. 清理 Controller（ruoyi-admin）
echo "📁 清理 ruoyi-admin 中的 Controller..."
if [ -d "$RUOYI_BACKEND/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test" ]; then
    rm -rf "$RUOYI_BACKEND/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test"
    echo "  ✅ 已删除 test Controller"
fi

# 3. 清理前端代码
echo "📁 清理前端代码..."
if [ -d "$RUOYI_FRONTEND/src/views/test" ]; then
    rm -rf "$RUOYI_FRONTEND/src/views/test"
    echo "  ✅ 已删除 test 视图"
fi

if [ -d "$RUOYI_FRONTEND/src/api/test" ]; then
    rm -rf "$RUOYI_FRONTEND/src/api/test"
    echo "  ✅ 已删除 test API"
fi

# 4. 清理数据库菜单
echo "🗄️  清理数据库菜单..."
mysql -u ruoyi -pruoyi123 ry_vue -e "
DELETE FROM sys_menu 
WHERE menu_name LIKE '%MVP1%' 
   OR path IN ('mvp1_test', 'mvp1', 'info');
" 2>/dev/null && echo "  ✅ 数据库菜单已清理" || echo "  ⚠️  数据库清理可能失败，请手动检查"

echo ""
echo "✅ 清理完成！"
echo ""
echo "💡 现在可以执行以下命令进行全新部署："
echo "   cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator"
echo "   ./deploy-mvp1.sh"
