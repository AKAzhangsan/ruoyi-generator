#!/bin/bash
# 验证部署脚本 - 检查字典、表结构、自动填充

set -e

TABLE_NAME=${1:-""}

if [ -z "$TABLE_NAME" ]; then
    echo "❌ 用法: ./verify-deployment.sh <table_name>"
    echo "   示例: ./verify-deployment.sh mvp5_full_validation"
    exit 1
fi

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 读取数据库配置
CONFIG_FILE="configs/ruoyi-generator.yaml"
if [ -f "$CONFIG_FILE" ]; then
    DB_HOST=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['host'])")
    DB_PORT=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['port'])")
    DB_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['name'])")
    DB_USER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['user'])")
    DB_PASS=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['password'])")
else
    DB_HOST="localhost"
    DB_PORT="3306"
    DB_NAME="ry_vue"
    DB_USER="ruoyi"
    DB_PASS="ruoyi123"
fi

echo "🔍 验证部署: $TABLE_NAME"
echo "======================"
echo ""

# 1. 验证字典
echo "📋 1. 验证字典..."
DICT_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "SELECT COUNT(DISTINCT dict_type) FROM sys_dict_data WHERE dict_type LIKE '${TABLE_NAME}%';" 2>/dev/null | tail -1)

if [ "$DICT_COUNT" -eq 0 ]; then
    echo -e "${RED}  ❌ 未找到相关字典${NC}"
    echo "     可能需要手动执行:"
    echo "     mysql -u$DB_USER -p$DB_PASS $DB_NAME < output/$TABLE_NAME/sql/dict_*.sql"
else
    echo -e "${GREEN}  ✅ 找到 $DICT_COUNT 个相关字典${NC}"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SELECT dict_type, COUNT(*) as count FROM sys_dict_data WHERE dict_type LIKE '${TABLE_NAME}%' GROUP BY dict_type;" 2>/dev/null | tail -n +2 | while read line; do
        echo "     - $line"
    done
fi
echo ""

# 2. 验证表结构
echo "📋 2. 验证表结构..."
TABLE_EXISTS=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "SHOW TABLES LIKE '$TABLE_NAME';" 2>/dev/null | wc -l)

if [ "$TABLE_EXISTS" -eq 0 ]; then
    echo -e "${RED}  ❌ 表 $TABLE_NAME 不存在${NC}"
else
    echo -e "${GREEN}  ✅ 表 $TABLE_NAME 存在${NC}"
    
    # 检查关键字段
    echo "     字段检查:"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "DESCRIBE $TABLE_NAME;" 2>/dev/null | grep -E "Field|create_time|update_time" | while read line; do
        if echo "$line" | grep -q "create_time"; then
            echo -e "       ${GREEN}✓${NC} create_time"
        elif echo "$line" | grep -q "update_time"; then
            echo -e "       ${GREEN}✓${NC} update_time"
        fi
    done
fi
echo ""

# 3. 测试自动填充
echo "📋 3. 测试 create_time 自动填充..."
# 先删除测试数据
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "DELETE FROM $TABLE_NAME WHERE product_name='__VERIFICATION_TEST__';" 2>/dev/null || true

# 插入测试数据（不指定 create_time）
FIRST_FIELD=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='$TABLE_NAME' AND COLUMN_NAME NOT IN ('id', 'create_time', 'update_time', 'create_by', 'update_by') LIMIT 1;" 2>/dev/null | tail -1)

if [ -n "$FIRST_FIELD" ]; then
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "INSERT INTO $TABLE_NAME ($FIRST_FIELD) VALUES ('__VERIFICATION_TEST__');" 2>/dev/null
    
    # 查询结果
    RESULT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SELECT create_time FROM $TABLE_NAME WHERE $FIRST_FIELD='__VERIFICATION_TEST__' LIMIT 1;" 2>/dev/null | tail -1)
    
    if [ -n "$RESULT" ] && [ "$RESULT" != "NULL" ]; then
        echo -e "${GREEN}  ✅ create_time 自动填充正常: $RESULT${NC}"
    else
        echo -e "${YELLOW}  ⚠️  create_time 可能未自动填充（需后端服务运行）${NC}"
        echo "     注意：create_time 需要后端服务运行时才会自动填充"
    fi
    
    # 清理测试数据
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "DELETE FROM $TABLE_NAME WHERE $FIRST_FIELD='__VERIFICATION_TEST__';" 2>/dev/null || true
else
    echo -e "${YELLOW}  ⚠️  无法获取字段信息，跳过测试${NC}"
fi
echo ""

# 4. 验证菜单
echo "📋 4. 验证菜单..."
MENU_EXISTS=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -e "SELECT COUNT(*) FROM sys_menu WHERE perms LIKE '${TABLE_NAME}%';" 2>/dev/null | tail -1)

if [ "$MENU_EXISTS" -gt 0 ]; then
    echo -e "${GREEN}  ✅ 菜单已创建 ($MENU_EXISTS 个权限节点)${NC}"
else
    echo -e "${RED}  ❌ 菜单未创建${NC}"
fi
echo ""

echo "======================"
echo "✅ 验证完成"
echo ""
echo "💡 提示:"
echo "   - 若字典为空，请执行: mysql -u$DB_USER -p$DB_PASS $DB_NAME < output/$TABLE_NAME/sql/dict_*.sql"
echo "   - 若菜单未显示，请重新登录系统"
