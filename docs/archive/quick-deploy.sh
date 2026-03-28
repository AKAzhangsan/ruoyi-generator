#!/bin/bash
# RuoYi 代码生成器 - 快速部署脚本
# 用法: ./quick-deploy.sh <schema_file> [table_name]

set -e

SCHEMA_FILE=${1:-""}
TABLE_NAME=${2:-""}

if [ -z "$SCHEMA_FILE" ]; then
    echo "用法: ./quick-deploy.sh <schema_file> [table_name]"
    echo "示例: ./quick-deploy.sh configs/schemas/test-mvp4.yaml"
    exit 1
fi

# 从schema文件名提取表名（如果未提供）
if [ -z "$TABLE_NAME" ]; then
    TABLE_NAME=$(basename "$SCHEMA_FILE" .yaml | sed 's/test-//')
fi

echo "🚀 快速部署: $TABLE_NAME"
echo "================================"

# 步骤1: 生成配置
echo "📋 步骤1/4: 生成配置..."
python3 main_allinone.py --schema "$SCHEMA_FILE" --step=config > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 配置生成失败"
    exit 1
fi
echo "✅ 配置生成完成"

# 步骤2: 生成代码
echo "📋 步骤2/4: 生成代码..."
CONFIG_FILE="configs/generated/${TABLE_NAME}-config.yaml"
python3 main_allinone.py --schema "$CONFIG_FILE" --step=generate > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 代码生成失败"
    exit 1
fi
echo "✅ 代码生成完成"

# 步骤3: 部署
echo "📋 步骤3/4: 部署代码..."
./scripts/deploy.sh "$TABLE_NAME" true > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 部署失败"
    exit 1
fi
echo "✅ 部署完成"

# 步骤4: 编译后端
echo "📋 步骤4/4: 编译后端..."
cd ../ruoyi/ruoyi-backend
mvn package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi
echo "✅ 编译完成"

echo ""
echo "🎉 部署成功！"
echo "================================"
echo "请手动重启后端服务:"
echo "  cd ruoyi-backend/ruoyi-admin/target"
echo "  java -jar ruoyi-admin.jar"
echo ""
echo "前端访问: http://localhost:3000"
