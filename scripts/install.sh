#!/bin/bash
# 若依Python代码生成器 - 安装脚本

echo "🚀 安装若依Python代码生成器"
echo "============================"
echo ""

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装"
    exit 1
fi

echo "✅ Python3 已安装: $(python3 --version)"

# 检查pip
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 未安装"
    exit 1
fi

echo "✅ pip3 已安装"

# 安装依赖
echo ""
echo "📦 安装依赖..."
pip3 install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ 依赖安装完成"
else
    echo "❌ 依赖安装失败"
    exit 1
fi

# 创建配置文件模板
if [ ! -f "config.yaml" ]; then
    echo ""
    echo "📝 配置文件已存在: config.yaml"
else
    echo ""
    echo "⚠️  请编辑 config.yaml 配置数据库连接信息"
fi

echo ""
echo "============================"
echo "✅ 安装完成！"
echo ""
echo "使用方法:"
echo "  python3 main.py -t customer_info -m customer"
echo ""
echo "帮助:"
echo "  python3 main.py --help"
echo ""
