#!/bin/bash
# 完整工作流程脚本 - 包含字典检查、清理、生成、部署、编译、重启
# 用法: ./full-workflow.sh <schema_file> [table_name]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCHEMA_FILE=${1:-""}
TABLE_NAME=${2:-""}
SKIP_CLEANUP=${3:-"false"}

if [ -z "$SCHEMA_FILE" ]; then
    echo -e "${RED}用法: ./full-workflow.sh <schema_file> [table_name] [skip_cleanup]${NC}"
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ./full-workflow.sh configs/schemas/test-mvp4.yaml"
    echo -e "  ./full-workflow.sh configs/schemas/test-mvp4.yaml mvp4_full_components"
    echo -e "  ./full-workflow.sh configs/schemas/test-mvp4.yaml mvp4_full_components true  # 跳过清理"
    exit 1
fi

# 从schema文件名提取表名（如果未提供）
if [ -z "$TABLE_NAME" ]; then
    TABLE_NAME=$(basename "$SCHEMA_FILE" .yaml | sed 's/test-//')
fi

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║     RuoYi 代码生成器 - 完整工作流程                      ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${GREEN}🚀 开始处理: $TABLE_NAME${NC}"
echo ""

# 步骤0: 检查系统字典
echo -e "${BLUE}📋 步骤0/6: 检查系统字典...${NC}"
echo -e "${YELLOW}   提示: 以下字典可直接使用，无需在YAML中定义:${NC}"
echo -e "   - sys_normal_disable (正常/停用)"
echo -e "   - sys_yes_no (是/否)"
echo -e "   - sys_user_sex (男/女/未知)"
echo -e "   - sys_show_hide (显示/隐藏)"
echo ""

# 步骤1: 清理（可选）
if [ "$SKIP_CLEANUP" != "true" ]; then
    echo -e "${BLUE}📋 步骤1/6: 清理旧代码和数据表...${NC}"
    read -p "是否删除数据库表? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/cleanup.sh "$TABLE_NAME" true
        echo -e "${GREEN}✅ 清理完成（包含数据库表）${NC}"
    else
        ./scripts/cleanup.sh "$TABLE_NAME" false
        echo -e "${GREEN}✅ 清理完成（仅代码，保留数据表）${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  跳过步骤1（清理）${NC}"
fi
echo ""

# 步骤2: 生成配置（包含自动字典检查）
echo -e "${BLUE}📋 步骤2/6: 生成配置文件...${NC}"
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 配置生成失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 配置生成完成${NC}"
echo ""

# 步骤3: 生成代码
echo -e "${BLUE}📋 步骤3/6: 生成代码...${NC}"
CONFIG_FILE="configs/generated/${TABLE_NAME}-config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    # 尝试其他可能的文件名
    CONFIG_FILE=$(ls configs/generated/*${TABLE_NAME}*-config.yaml 2>/dev/null | head -1)
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 未找到配置文件: configs/generated/${TABLE_NAME}-config.yaml${NC}"
    exit 1
fi

python3 main_allinone.py --schema "$CONFIG_FILE" --step=generate
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 代码生成失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 代码生成完成${NC}"
echo ""

# 步骤4: 部署
echo -e "${BLUE}📋 步骤4/6: 部署代码...${NC}"
./scripts/deploy.sh "$TABLE_NAME" true
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 部署失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 部署完成${NC}"
echo ""

# 步骤5: 编译后端
echo -e "${BLUE}📋 步骤5/6: 编译后端...${NC}"
cd ../ruoyi/ruoyi-backend
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 编译失败${NC}"
    exit 1
fi
cd -
echo -e "${GREEN}✅ 编译完成${NC}"
echo ""

# 步骤6: 重启服务
echo -e "${BLUE}📋 步骤6/6: 重启服务...${NC}"
echo -e "${YELLOW}   正在停止旧服务...${NC}"
pkill -f "ruoyi-admin" 2>/dev/null || true
sleep 2

echo -e "${YELLOW}   正在启动后端...${NC}"
cd ../ruoyi/ruoyi-backend/ruoyi-admin/target
nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
cd -

# 等待后端启动
echo -e "${YELLOW}   等待后端启动（约10秒）...${NC}"
sleep 10

# 检查是否启动成功
if grep -q "启动成功" /tmp/ruoyi.log 2>/dev/null; then
    echo -e "${GREEN}✅ 后端启动成功${NC}"
else
    echo -e "${YELLOW}⚠️  后端启动中，请稍后检查日志: tail -f /tmp/ruoyi.log${NC}"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}🎉 全部完成！${NC}                                          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}访问地址:${NC}"
echo -e "  前端: http://localhost:3000"
echo -e "  后端: http://localhost:8080"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo -e "  - 如前端未运行，请手动启动: cd ruoyi-frontend && npm run dev"
echo -e "  - 查看后端日志: tail -f /tmp/ruoyi.log"
echo ""
