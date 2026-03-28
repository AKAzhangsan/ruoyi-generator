#!/bin/bash
# MVP5 部署脚本 - 使用MVP4流程（修复版）
# 用法: ./mvp5-deploy.sh

set -e

TABLE_NAME="mvp5_full_validation"
SCHEMA_FILE="configs/schemas/test-mvp5.yaml"
CONFIG_FILE="configs/generated/mvp5_full_validation-config.yaml"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP5 部署 - 使用MVP4流程                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 步骤1: 清理
echo "【步骤1/4】清理..."
./scripts/cleanup.sh "$TABLE_NAME" true 2>/dev/null || true
echo ""

# 步骤2: 生成配置
echo "【步骤2/4】生成配置..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
echo ""

# 步骤3: 生成代码
echo "【步骤3/4】生成代码..."
python3 main_allinone.py --schema "$CONFIG_FILE" --step=generate
echo ""

# 步骤4: 部署
echo "【步骤4/4】部署..."

# 4.1 建表
echo "  → 创建数据库表..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=create > /dev/null 2>&1 || true

# 4.2 执行字典SQL（覆盖模式 - 先删除再插入）
echo "  → 执行字典SQL（覆盖模式）..."
for sql_file in output/$TABLE_NAME/sql/dict_*.sql; do
    if [ -f "$sql_file" ]; then
        # 提取字典类型名
        dict_name=$(basename "$sql_file" .sql | sed 's/dict_//')
        echo "    处理字典: $dict_name"
        
        # 先删除旧字典数据（覆盖模式）
        mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
            "DELETE FROM sys_dict_data WHERE dict_type='$dict_name'; DELETE FROM sys_dict_type WHERE dict_type='$dict_name';" \
            2>/dev/null || true
        
        # 插入新字典
        mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue < "$sql_file" 2>/dev/null && \
            echo "    ✓ $dict_name 已覆盖" || echo "    ⚠ $dict_name 执行失败"
    fi
done

# 4.3 执行菜单SQL
echo "  → 执行菜单SQL..."
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue \
  < "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" 2>/dev/null || true

# 4.4 修复create_time默认值
echo "  → 修复create_time默认值..."
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
  "ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null || true

# 4.5 复制前端代码（Vue + API）
echo "  → 复制前端代码..."
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

# 复制 Vue 文件
mkdir -p "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME"
cp output/$TABLE_NAME/vue/views/test/$TABLE_NAME/*.vue \
    "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME/" 2>/dev/null && echo "    ✓ Vue文件"

# 复制 API 文件（关键！）
mkdir -p "$RUOYI_FRONTEND/src/api/test"
cp output/$TABLE_NAME/vue/api/test/*.js \
    "$RUOYI_FRONTEND/src/api/test/" 2>/dev/null && echo "    ✓ API文件"

# 4.6 复制后端代码
echo "  → 复制后端代码..."
RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

# Controller
mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test"
cp output/$TABLE_NAME/main/java/com/ruoyi/web/controller/test/*.java \
    "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test/" 2>/dev/null && echo "    ✓ Controller"

# Service/Mapper/Domain
cp -r output/$TABLE_NAME/main/java/com/ruoyi/test "$RUOYI_SYSTEM/src/main/java/com/ruoyi/" 2>/dev/null && echo "    ✓ Service/Mapper/Domain"

# Mapper XML
mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper/test"
cp output/$TABLE_NAME/main/resources/mapper/test/*.xml \
    "$RUOYI_SYSTEM/src/main/resources/mapper/test/" 2>/dev/null && echo "    ✓ Mapper XML"

# 4.7 编译
echo "  → 编译后端..."
cd "$RUOYI_BACKEND"
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q > /tmp/mvn.log 2>&1 && \
    echo "    ✓ 编译完成" || (echo "    ❌ 编译失败" && exit 1)
cd -

# 4.8 重启
echo "  → 重启服务..."
pkill -f ruoyi-admin 2>/dev/null || true
sleep 2
cd "$RUOYI_BACKEND/ruoyi-admin/target"
nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
echo "    ✓ 后端启动中"
cd -

echo ""
echo "✅ 部署完成！"
echo ""
echo "📝 测试地址: http://localhost:3000"
echo "   账号: admin / admin123"
echo ""
echo "💡 如前端未运行: cd $RUOYI_FRONTEND && npm run dev"
