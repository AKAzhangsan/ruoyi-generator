#!/bin/bash
# MVP 分步部署脚本
# 用法: ./mvp-steps.sh <schema_file> <step>
#
# 步骤:
#   1 - 清理
#   2 - 生成配置
#   3 - 生成代码
#   4 - 建表
#   5 - 执行字典SQL
#   6 - 执行菜单SQL
#   7 - 复制前端代码
#   8 - 复制后端代码
#   9 - 编译
#   10 - 重启
#
# 示例:
#   ./mvp-steps.sh configs/schemas/test-mvp5.yaml 1    # 只清理
#   ./mvp-steps.sh configs/schemas/test-mvp5.yaml 1-3  # 清理到生成代码
#   ./mvp-steps.sh configs/schemas/test-mvp5.yaml 4-10 # 建表到重启

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCHEMA_FILE=${1:-""}
STEP_RANGE=${2:-"1-10"}

# 检查参数
if [ -z "$SCHEMA_FILE" ]; then
    echo "用法: ./mvp-steps.sh <schema_file> <step_or_range>"
    echo ""
    echo "步骤:"
    echo "  1  - 清理"
    echo "  2  - 生成配置"
    echo "  3  - 生成代码"
    echo "  4  - 建表"
    echo "  5  - 执行字典SQL"
    echo "  6  - 执行菜单SQL"
    echo "  7  - 复制前端代码"
    echo "  8  - 复制后端代码"
    echo "  9  - 编译"
    echo "  10 - 重启"
    echo ""
    echo "示例:"
    echo "  ./mvp-steps.sh configs/schemas/test-mvp5.yaml 1      # 只执行步骤1"
    echo "  ./mvp-steps.sh configs/schemas/test-mvp5.yaml 2-3    # 执行步骤2到3"
    echo "  ./mvp-steps.sh configs/schemas/test-mvp5.yaml 4      # 只执行步骤4"
    echo "  ./mvp-steps.sh configs/schemas/test-mvp5.yaml 7-10   # 执行步骤7到10"
    exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ 错误: 文件不存在: $SCHEMA_FILE"
    exit 1
fi

# 解析步骤范围
if [[ "$STEP_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    START_STEP=${BASH_REMATCH[1]}
    END_STEP=${BASH_REMATCH[2]}
elif [[ "$STEP_RANGE" =~ ^[0-9]+$ ]]; then
    START_STEP=$STEP_RANGE
    END_STEP=$STEP_RANGE
else
    echo "❌ 错误: 无效的步骤范围: $STEP_RANGE"
    echo "有效格式: 5 或 2-5"
    exit 1
fi

# 提取表名和配置
TABLE_NAME=$(basename "$SCHEMA_FILE" .yaml | sed 's/test-//')
CONFIG_FILE="configs/generated/${TABLE_NAME}-config.yaml"
RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP 分步部署脚本                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📋 配置:"
echo "   Schema: $SCHEMA_FILE"
echo "   Table:  $TABLE_NAME"
echo "   步骤:   $START_STEP 到 $END_STEP"
echo ""

# 执行步骤的函数
run_step() {
    local step=$1
    
    case $step in
        1)
            echo -e "${BLUE}【步骤1】清理...${NC}"
            ./scripts/cleanup.sh "$TABLE_NAME" true 2>/dev/null || true
            echo -e "${GREEN}✓ 清理完成${NC}"
            ;;
        2)
            echo -e "${BLUE}【步骤2】生成配置...${NC}"
            python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
            echo -e "${GREEN}✓ 配置已生成: $CONFIG_FILE${NC}"
            ;;
        3)
            echo -e "${BLUE}【步骤3】生成代码...${NC}"
            if [ ! -f "$CONFIG_FILE" ]; then
                CONFIG_FILE=$(ls configs/generated/*${TABLE_NAME}*-config.yaml 2>/dev/null | head -1)
            fi
            if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
                echo "❌ 错误: 未找到配置文件"
                exit 1
            fi
            python3 main_allinone.py --schema "$CONFIG_FILE" --step=generate
            echo -e "${GREEN}✓ 代码已生成: output/$TABLE_NAME/${NC}"
            ;;
        4)
            echo -e "${BLUE}【步骤4】创建数据库表...${NC}"
            python3 main_allinone.py --schema "$SCHEMA_FILE" --step=create
            echo -e "${GREEN}✓ 数据库表已创建${NC}"
            ;;
        5)
            echo -e "${BLUE}【步骤5】执行字典SQL...${NC}"
            for sql_file in output/$TABLE_NAME/sql/dict_*.sql; do
                if [ -f "$sql_file" ]; then
                    dict_name=$(basename "$sql_file" .sql | sed 's/dict_//')
                    # 覆盖模式：先删除
                    mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
                        "DELETE FROM sys_dict_data WHERE dict_type='$dict_name'; DELETE FROM sys_dict_type WHERE dict_type='$dict_name';" \
                        2>/dev/null || true
                    # 插入新数据
                    mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue < "$sql_file"
                    echo "  ✓ $dict_name"
                fi
            done
            echo -e "${GREEN}✓ 字典SQL已执行${NC}"
            ;;
        6)
            echo -e "${BLUE}【步骤6】执行菜单SQL...${NC}"
            if [ -f "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" ]; then
                mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue \
                    < "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql"
                echo -e "${GREEN}✓ 菜单SQL已执行${NC}"
            else
                echo "⚠ 菜单SQL文件不存在"
            fi
            ;;
        7)
            echo -e "${BLUE}【步骤7】复制前端代码...${NC}"
            mkdir -p "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME"
            cp output/$TABLE_NAME/vue/views/test/$TABLE_NAME/*.vue \
                "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME/"
            echo "  ✓ Vue文件"
            
            mkdir -p "$RUOYI_FRONTEND/src/api/test"
            cp output/$TABLE_NAME/vue/api/test/*.js \
                "$RUOYI_FRONTEND/src/api/test/"
            echo "  ✓ API文件"
            
            echo -e "${GREEN}✓ 前端代码已复制${NC}"
            ;;
        8)
            echo -e "${BLUE}【步骤8】复制后端代码...${NC}"
            mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test"
            cp output/$TABLE_NAME/main/java/com/ruoyi/web/controller/test/*.java \
                "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test/"
            echo "  ✓ Controller"
            
            cp -r output/$TABLE_NAME/main/java/com/ruoyi/test "$RUOYI_SYSTEM/src/main/java/com/ruoyi/"
            echo "  ✓ Service/Mapper/Domain"
            
            mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper/test"
            cp output/$TABLE_NAME/main/resources/mapper/test/*.xml \
                "$RUOYI_SYSTEM/src/main/resources/mapper/test/"
            echo "  ✓ Mapper XML"
            
            echo -e "${GREEN}✓ 后端代码已复制${NC}"
            ;;
        9)
            echo -e "${BLUE}【步骤9】编译后端...${NC}"
            cd "$RUOYI_BACKEND"
            mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q
            cd -
            echo -e "${GREEN}✓ 编译完成${NC}"
            ;;
        10)
            echo -e "${BLUE}【步骤10】重启服务...${NC}"
            pkill -f ruoyi-admin 2>/dev/null || true
            sleep 2
            cd "$RUOYI_BACKEND/ruoyi-admin/target"
            nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
            echo "  ✓ 后端启动中（PID: $!）"
            cd -
            echo -e "${GREEN}✓ 服务已重启${NC}"
            ;;
        *)
            echo "❌ 错误: 无效步骤 $step"
            exit 1
            ;;
    esac
    echo ""
}

# 执行步骤
for ((i=START_STEP; i<=END_STEP; i++)); do
    run_step $i
done

echo -e "${GREEN}✅ 所有步骤执行完成！${NC}"
echo ""
echo "📋 表名: $TABLE_NAME"
echo "🔗 访问: http://localhost:3000"
echo ""
echo "💡 如前端未运行: cd $RUOYI_FRONTEND && npm run dev"
