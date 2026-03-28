#!/bin/bash
# 通用 MVP 部署脚本
# 用法: ./mvp-deploy.sh <schema_file> [options]
#
# 示例:
#   ./mvp-deploy.sh configs/schemas/test-mvp5.yaml
#   ./mvp-deploy.sh configs/schemas/test-mvp6.yaml --skip-cleanup
#   ./mvp-deploy.sh configs/schemas/my-table.yaml --dict-strategy=merge

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 默认配置
SKIP_CLEANUP=false
DICT_STRATEGY="replace"  # replace|merge|skip
SKIP_COMPILE=false
SKIP_RESTART=false

# 解析参数
SCHEMA_FILE=${1:-""}
shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --dict-strategy=*)
            DICT_STRATEGY="${1#*=}"
            shift
            ;;
        --skip-compile)
            SKIP_COMPILE=true
            shift
            ;;
        --skip-restart)
            SKIP_RESTART=true
            shift
            ;;
        --help|-h)
            echo "用法: ./mvp-deploy.sh <schema_file> [options]"
            echo ""
            echo "选项:"
            echo "  --skip-cleanup       跳过清理步骤"
            echo "  --dict-strategy=mode 字典执行策略: replace(默认)|merge|skip"
            echo "  --skip-compile       跳过编译"
            echo "  --skip-restart       跳过重启服务"
            echo "  --help, -h           显示帮助"
            echo ""
            echo "示例:"
            echo "  ./mvp-deploy.sh configs/schemas/test-mvp5.yaml"
            echo "  ./mvp-deploy.sh configs/schemas/test-mvp5.yaml --skip-cleanup"
            echo "  ./mvp-deploy.sh configs/schemas/test-mvp6.yaml --dict-strategy=merge"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 检查参数
if [ -z "$SCHEMA_FILE" ]; then
    echo -e "${RED}❌ 错误: 请提供 schema 文件路径${NC}"
    echo "用法: ./mvp-deploy.sh <schema_file>"
    echo "示例: ./mvp-deploy.sh configs/schemas/test-mvp5.yaml"
    exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}❌ 错误: 文件不存在: $SCHEMA_FILE${NC}"
    exit 1
fi

# 从 schema 文件名提取表名
TABLE_NAME=$(basename "$SCHEMA_FILE" .yaml | sed 's/test-//')
CONFIG_FILE="configs/generated/${TABLE_NAME}-config.yaml"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP 通用部署脚本                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📋 配置信息:"
echo "   Schema: $SCHEMA_FILE"
echo "   Table:  $TABLE_NAME"
echo "   Dict:   $DICT_STRATEGY 模式"
echo ""

# 步骤1: 清理（可选）
if [ "$SKIP_CLEANUP" = "false" ]; then
    echo -e "${YELLOW}【步骤1/4】清理...${NC}"
    ./scripts/cleanup.sh "$TABLE_NAME" true 2>/dev/null || true
    echo ""
else
    echo -e "${YELLOW}【步骤1/4】跳过清理${NC}"
    echo ""
fi

# 步骤2: 生成配置
echo -e "${YELLOW}【步骤2/4】生成配置...${NC}"
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
echo ""

# 步骤3: 生成代码
echo -e "${YELLOW}【步骤3/4】生成代码...${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    # 尝试其他可能的文件名
    CONFIG_FILE=$(ls configs/generated/*${TABLE_NAME}*-config.yaml 2>/dev/null | head -1)
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 错误: 未找到配置文件${NC}"
    exit 1
fi

python3 main_allinone.py --schema "$CONFIG_FILE" --step=generate
echo ""

# 步骤4: 部署
echo -e "${YELLOW}【步骤4/4】部署...${NC}"

# 4.1 创建数据库表
echo "  → 创建数据库表..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=create > /dev/null 2>&1 || echo "    表可能已存在"

# 4.2 执行字典SQL
echo "  → 执行字典SQL ($DICT_STRATEGY 模式)..."
if [ "$DICT_STRATEGY" != "skip" ]; then
    for sql_file in output/$TABLE_NAME/sql/dict_*.sql; do
        if [ -f "$sql_file" ]; then
            dict_name=$(basename "$sql_file" .sql | sed 's/dict_//')
            
            if [ "$DICT_STRATEGY" = "replace" ]; then
                # 覆盖模式：先删除再插入
                mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
                    "DELETE FROM sys_dict_data WHERE dict_type='$dict_name'; DELETE FROM sys_dict_type WHERE dict_type='$dict_name';" \
                    2>/dev/null || true
            fi
            
            mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue < "$sql_file" 2>/dev/null && \
                echo "    ✓ $dict_name" || echo "    ⚠ $dict_name"
        fi
    done
else
    echo "    ⏭️  跳过字典执行"
fi

# 4.3 执行菜单SQL
echo "  → 执行菜单SQL..."
if [ -f "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" ]; then
    mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue \
        < "output/$TABLE_NAME/sql/${TABLE_NAME}_menu.sql" 2>/dev/null && \
        echo "    ✓ 菜单已执行" || echo "    ⚠ 菜单可能已存在"
fi

# 4.4 修复create_time默认值
echo "  → 修复create_time默认值..."
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e \
    "ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null && \
    echo "    ✓ create_time已设置" || echo "    ⚠ create_time可能已设置"

# 4.5 复制前端代码
echo "  → 复制前端代码..."
RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"

mkdir -p "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME"
cp output/$TABLE_NAME/vue/views/test/$TABLE_NAME/*.vue \
    "$RUOYI_FRONTEND/src/views/test/$TABLE_NAME/" 2>/dev/null && echo "    ✓ Vue文件"

mkdir -p "$RUOYI_FRONTEND/src/api/test"
cp output/$TABLE_NAME/vue/api/test/*.js \
    "$RUOYI_FRONTEND/src/api/test/" 2>/dev/null && echo "    ✓ API文件"

# 4.6 复制后端代码
echo "  → 复制后端代码..."
RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test"
cp output/$TABLE_NAME/main/java/com/ruoyi/web/controller/test/*.java \
    "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/test/" 2>/dev/null && echo "    ✓ Controller"

cp -r output/$TABLE_NAME/main/java/com/ruoyi/test "$RUOYI_SYSTEM/src/main/java/com/ruoyi/" 2>/dev/null && echo "    ✓ Service/Mapper/Domain"

mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper/test"
cp output/$TABLE_NAME/main/resources/mapper/test/*.xml \
    "$RUOYI_SYSTEM/src/main/resources/mapper/test/" 2>/dev/null && echo "    ✓ Mapper XML"

# 4.7 编译（可选）
if [ "$SKIP_COMPILE" = "false" ]; then
    echo "  → 编译后端..."
    cd "$RUOYI_BACKEND"
    mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q > /tmp/mvn.log 2>&1 && \
        echo "    ✓ 编译完成" || (echo "    ❌ 编译失败" && exit 1)
    cd -
else
    echo "  → 跳过编译"
fi

# 4.8 重启（可选）
if [ "$SKIP_RESTART" = "false" ]; then
    echo "  → 重启服务..."
    pkill -f ruoyi-admin 2>/dev/null || true
    sleep 2
    cd "$RUOYI_BACKEND/ruoyi-admin/target"
    nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
    echo "    ✓ 后端启动中（PID: $!）"
    cd -
else
    echo "  → 跳过重启"
fi

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo "📋 信息:"
echo "   表名: $TABLE_NAME"
echo "   菜单: 系统工具 → $TABLE_NAME"
echo ""
echo "🔗 访问地址:"
echo "   http://localhost:3000"
echo "   账号: admin / admin123"
echo ""

if [ "$SKIP_RESTART" = "true" ]; then
    echo "💡 请手动重启后端:"
    echo "   cd $RUOYI_BACKEND/ruoyi-admin/target"
    echo "   java -jar ruoyi-admin.jar"
fi

if [ "$SKIP_COMPILE" = "true" ]; then
    echo "💡 请手动编译:"
    echo "   cd $RUOYI_BACKEND"
    echo "   mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q"
fi

echo ""
echo "💡 如前端未运行: cd $RUOYI_FRONTEND && npm run dev"
