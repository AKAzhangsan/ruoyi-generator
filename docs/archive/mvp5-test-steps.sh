#!/bin/bash
# MVP5 完整分步测试流程
# 用法: ./mvp5-test-steps.sh

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP5 全组件测试 - 完整分步流程                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
TABLE_NAME="mvp5_full_validation"
SCHEMA_FILE="configs/schemas/test-mvp5.yaml"
DB_USER="ruoyi"
DB_PASS="ruoyi123"
DB_NAME="ry_vue"

echo -e "${YELLOW}步骤 0: 清理环境${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  ./scripts/cleanup.sh $TABLE_NAME true"
./scripts/cleanup.sh "$TABLE_NAME" true
echo ""

echo -e "${YELLOW}步骤 1: 检查系统字典${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  ./check-dicts.sh"
./check-dicts.sh
echo ""
echo "💡 常用系统字典（可直接使用）:"
echo "   - sys_normal_disable (正常/停用)"
echo "   - sys_yes_no (是/否)"
echo "   - sys_user_sex (男/女/未知)"
echo ""

echo -e "${YELLOW}步骤 2: 生成配置文件${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  python3 main_allinone.py --schema $SCHEMA_FILE --step=config"
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
echo ""

echo -e "${YELLOW}步骤 3: 生成代码${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  python3 main_allinone.py --schema configs/generated/${TABLE_NAME}-config.yaml --step=generate"
python3 main_allinone.py --schema "configs/generated/${TABLE_NAME}-config.yaml" --step=generate
echo ""

echo -e "${YELLOW}步骤 4: 创建数据库表${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  python3 main_allinone.py --schema $SCHEMA_FILE --step=create"
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=create
echo ""

echo -e "${YELLOW}步骤 5: 执行字典SQL${NC}"
echo "----------------------------------------"
echo "执行命令:"
for sql_file in output/$TABLE_NAME/sql/dict_*.sql; do
    if [ -f "$sql_file" ]; then
        echo "  mysql -u$DB_USER -p'$DB_PASS' $DB_NAME < $sql_file"
        mysql -hlocalhost -P3306 -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file"
        echo "  ✅ $(basename $sql_file) 执行完成"
    fi
done
echo ""

echo -e "${YELLOW}步骤 6: 执行菜单SQL${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  mysql -u$DB_USER -p'$DB_PASS' $DB_NAME < output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql"
mysql -hlocalhost -P3306 -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql"
echo ""

echo -e "${YELLOW}步骤 7: 修改 create_time 默认值${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;"
mysql -hlocalhost -P3306 -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
    "ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;"
echo ""

echo -e "${YELLOW}步骤 8: 验证部署${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  ./verify-deployment.sh $TABLE_NAME"
./verify-deployment.sh "$TABLE_NAME"
echo ""

echo -e "${YELLOW}步骤 9: 编译后端${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  cd ../ruoyi/ruoyi-backend"
echo "  mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q"
cd ../ruoyi/ruoyi-backend
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q
cd -
echo ""

echo -e "${YELLOW}步骤 10: 重启服务${NC}"
echo "----------------------------------------"
echo "执行命令:"
echo "  pkill -f ruoyi-admin"
echo "  cd ../ruoyi/ruoyi-backend/ruoyi-admin/target"
echo "  java -jar ruoyi-admin.jar"
pkill -f ruoyi-admin 2>/dev/null || true
sleep 2
cd ../ruoyi/ruoyi-backend/ruoyi-admin/target
java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
echo "  后端启动中（PID: $!）..."
cd -

# 等待后端启动
echo ""
echo "等待后端启动..."
sleep 10
if grep -q "启动成功" /tmp/ruoyi.log 2>/dev/null; then
    echo -e "${GREEN}✅ 后端启动成功${NC}"
else
    echo "⚠️  后端启动中，请稍后检查: tail -f /tmp/ruoyi.log"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ 部署完成！                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📋 测试步骤:"
echo "  1. 访问: http://localhost:3000"
echo "  2. 登录: admin / admin123"
echo "  3. 菜单: 系统工具 → MVP5全组件验证测试"
echo "  4. 点击: 新增"
echo "  5. 填写: 所有字段测试各组件"
echo "  6. 保存: 检查列表显示和创建时间"
echo ""
echo "🔍 验证内容:"
echo "  - 产品分类下拉框: 电子产品、家居用品、服装配饰、食品饮料"
echo "  - 产品标签多选: 新品、热销、促销、限量"
echo "  - 产品等级多选: 一级、二级、三级"
echo "  - 创建时间: 自动填充当前时间"
echo "  - 修改回显: 所有字段正确显示"
echo ""
echo "💡 如前端未运行，请执行:"
echo "  cd ../ruoyi/ruoyi-frontend && npm run dev"
echo ""
