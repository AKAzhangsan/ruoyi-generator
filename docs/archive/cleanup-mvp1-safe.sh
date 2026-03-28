#!/bin/bash
# 安全清理 MVP1 测试表数据（不删除 product_info）

set -e

echo "🧹 安全清理 MVP1 测试表数据..."

RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

# 1. 清理后端代码（只删除 mvp1_test 相关，不删除整个 test 模块）
echo "📁 清理 mvp1_test 后端代码..."
if [ -d "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test/domain/Mvp1Test.java" ]; then
    rm -f "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test/domain/Mvp1Test.java"
    rm -f "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test/mapper/Mvp1TestMapper.java"
    rm -f "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test/service/IMvp1TestService.java"
    rm -rf "$RUOYI_BACKEND/ruoyi-system/src/main/java/com/ruoyi/test/service/impl/Mvp1TestServiceImpl.java"
    echo "  ✅ 已删除 mvp1_test Java 代码"
fi

if [ -f "$RUOYI_BACKEND/ruoyi-system/src/main/resources/mapper/test/Mvp1TestMapper.xml" ]; then
    rm -f "$RUOYI_BACKEND/ruoyi-system/src/main/resources/mapper/test/Mvp1TestMapper.xml"
    echo "  ✅ 已删除 mvp1_test Mapper XML"
fi

# 2. 清理 Controller
echo "📁 清理 mvp1_test Controller..."
if [ -f "$RUOYI_BACKEND/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test/Mvp1TestController.java" ]; then
    rm -f "$RUOYI_BACKEND/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test/Mvp1TestController.java"
    echo "  ✅ 已删除 mvp1_test Controller"
fi

# 3. 清理前端代码（只删除 mvp1_test 相关）
echo "📁 清理 mvp1_test 前端代码..."
if [ -d "$RUOYI_FRONTEND/src/views/test/mvp1_test" ]; then
    rm -rf "$RUOYI_FRONTEND/src/views/test/mvp1_test"
    echo "  ✅ 已删除 mvp1_test 视图"
fi

if [ -f "$RUOYI_FRONTEND/src/api/test/mvp1_test.js" ]; then
    rm -f "$RUOYI_FRONTEND/src/api/test/mvp1_test.js"
    echo "  ✅ 已删除 mvp1_test API"
fi

# 4. 清理数据库菜单（只删除 mvp1_test）
echo "🗄️  清理数据库菜单..."
mysql -u ruoyi -pruoyi123 ry_vue -e "
DELETE FROM sys_menu WHERE menu_name LIKE '%MVP1%' OR path='mvp1_test';
" 2>/dev/null && echo "  ✅ 数据库菜单已清理" || echo "  ⚠️  数据库清理可能失败"

echo ""
echo "✅ 清理完成！product_info 未受影响"
