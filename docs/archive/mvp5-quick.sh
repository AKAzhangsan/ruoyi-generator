#!/bin/bash
# MVP5 简化部署脚本 - 4步完成（修复版，无交互）
# 用法: ./mvp5-quick.sh

set -e

TABLE_NAME="mvp5_full_validation"
SCHEMA_FILE="configs/schemas/test-mvp5.yaml"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP5 快速部署 - 4步完成                              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 读取配置
RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

echo "【步骤1/4】清理..."
./scripts/cleanup.sh "$TABLE_NAME" true 2>/dev/null || true
echo ""

echo "【步骤2/4】生成配置..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
echo ""

echo "【步骤3/4】生成代码..."
python3 main_allinone.py --schema "configs/generated/${TABLE_NAME}-config.yaml" --step=generate
echo ""

echo "【步骤4/4】部署..."

# 4.1 创建数据库表
echo "  → 创建数据库表..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=create > /dev/null 2>&1 || echo "    表可能已存在"

# 4.2 执行字典SQL（自动，无交互）
echo "  → 执行字典SQL..."
for sql_file in output/$TABLE_NAME/sql/dict_*.sql; do
    if [ -f "$sql_file" ]; then
        mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue < "$sql_file" 2>/dev/null && \
            echo "    ✓ $(basename $sql_file)" || echo "    ⚠ $(basename $sql_file) 可能已存在"
    fi
done

# 4.3 执行菜单SQL
echo "  → 执行菜单SQL..."
if [ -f "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" ]; then
    mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue \
        < "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" 2>/dev/null && \
        echo "    ✓ 菜单SQL执行完成" || echo "    ⚠ 菜单可能已存在"
fi

# 4.4 修复create_time默认值
echo "  → 修复create_time默认值..."
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
    "ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null && \
    echo "    ✓ create_time默认值已设置"

# 4.5 直接复制代码（不调用deploy.sh，避免交互）
echo "  → 复制代码到项目..."

# 查找 ruoyi-admin 和 ruoyi-system
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

# Controller → ruoyi-admin
mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test"
cp output/$TABLE_NAME/main/java/com/ruoyi/web/controller/test/*.java \
    "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test/" 2>/dev/null && \
    echo "    ✓ Controller复制完成"

# Service/Mapper/Domain → ruoyi-system
cp -r output/$TABLE_NAME/main/java/com/ruoyi/test "$RUOYI_SYSTEM/src/main/java/com/ruoyi/" 2>/dev/null && \
    echo "    ✓ Service/Mapper/Domain复制完成"

# Mapper XML
mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper/test"
cp output/$TABLE_NAME/main/resources/mapper/test/*.xml \
    "$RUOYI_SYSTEM/src/main/resources/mapper/test/" 2>/dev/null && \
    echo "    ✓ Mapper XML复制完成"

# Vue代码
mkdir -p "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME"
cp output/$TABLE_NAME/vue/views/test/$TABLE_NAME/*.vue \
    "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME/" 2>/dev/null && \
    echo "    ✓ Vue代码复制完成"

# 4.6 编译
echo "  → 编译后端..."
cd "$RUOYI_BACKEND"
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q > /tmp/mvn.log 2>&1 && \
    echo "    ✓ 编译完成" || (echo "    ❌ 编译失败，查看: /tmp/mvn.log" && exit 1)
cd -

# 4.7 重启
echo "  → 重启服务..."
pkill -f ruoyi-admin 2>/dev/null || true
sleep 2
cd "$RUOYI_BACKEND/ruoyi-admin/target"
nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
echo "    ✓ 后端启动中（PID: $!）"
cd -

echo ""
echo "✅ 部署完成！"
echo ""
echo "📝 测试地址: http://localhost:3000"
echo "   账号: admin / admin123"
echo "   菜单: 系统工具 → MVP5全组件验证测试"
echo ""
echo "💡 如前端未运行，请执行:"
echo "   cd $RUOYI_FRONTEND && npm run dev"
