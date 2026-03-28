#!/bin/bash
# RuoYi Generator - 安装为 OpenClaw Skill
# 用法: git clone ... && cd ruoyi-generator && ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.openclaw/skills/ruoyi-generator"
CONFIG_FILE="$SCRIPT_DIR/configs/ruoyi-generator.yaml"
CONFIG_EXAMPLE="$SCRIPT_DIR/config.yaml.example"

echo "🏗️  RuoYi Generator 安装"
echo "========================"
echo ""

# 1. 检查 Python3
echo "🐍 检查依赖..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 需要 Python3"
    exit 1
fi
echo "   ✅ Python3: $(python3 --version 2>&1)"

# 检查 MySQL
if ! command -v mysql &> /dev/null; then
    echo "   ⚠️  mysql 客户端未找到（部署时需要）"
else
    echo "   ✅ MySQL: $(mysql --version 2>&1 | head -1)"
fi

# 2. 安装 Python 依赖
echo ""
echo "📦 安装 Python 依赖..."
pip3 install PyMySQL Jinja2 PyYAML colorama --break-system-packages --quiet 2>/dev/null || \
pip3 install PyMySQL Jinja2 PyYAML colorama --quiet 2>/dev/null || true
echo "   ✅ 依赖已安装"

# 3. 创建 OpenClaw Skill 符号链接
echo ""
echo "🔗 注册为 OpenClaw Skill..."
mkdir -p "$HOME/.openclaw/skills"

if [ -L "$SKILL_DIR" ]; then
    # 已存在符号链接，更新
    rm "$SKILL_DIR"
    ln -s "$SCRIPT_DIR" "$SKILL_DIR"
    echo "   ✅ 符号链接已更新: $SKILL_DIR -> $SCRIPT_DIR"
elif [ -d "$SKILL_DIR" ]; then
    # 已存在目录（旧版本），备份后替换
    BACKUP="$SKILL_DIR.bak.$(date +%Y%m%d%H%M%S)"
    mv "$SKILL_DIR" "$BACKUP"
    ln -s "$SCRIPT_DIR" "$SKILL_DIR"
    echo "   ✅ 旧目录已备份: $BACKUP"
    echo "   ✅ 符号链接已创建: $SKILL_DIR -> $SCRIPT_DIR"
else
    ln -s "$SCRIPT_DIR" "$SKILL_DIR"
    echo "   ✅ 符号链接已创建: $SKILL_DIR -> $SCRIPT_DIR"
fi

# 4. 生成配置文件
echo ""
echo "📝 配置文件..."
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$CONFIG_EXAMPLE" ]; then
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
        echo "   ✅ 配置文件已生成: configs/ruoyi-generator.yaml"
        echo "   ⚠️  请编辑配置文件，填写实际的数据库信息和项目路径"
    else
        echo "   ⚠️  未找到配置模板，请手动创建 configs/ruoyi-generator.yaml"
    fi
else
    echo "   ✅ 配置文件已存在"
fi

# 5. 设置脚本权限
echo ""
echo "🔐 设置权限..."
chmod +x scripts/*.sh 2>/dev/null || true
echo "   ✅ 脚本权限已设置"

# 6. 创建必要目录
mkdir -p configs/schemas configs/generated configs/dicts output
echo "   ✅ 目录结构已创建"

echo ""
echo "========================"
echo "✅ 安装完成！"
echo ""
echo "下一步:"
echo "  1. 编辑配置: vim configs/ruoyi-generator.yaml"
echo "     - 设置 ruoyi_backend / ruoyi_frontend 路径"
echo "     - 设置数据库连接信息"
echo ""
echo "  2. 开始使用:"
echo "     cp templates/configs/schema-template.yaml configs/schemas/my_table.yaml"
echo "     # 编辑 my_table.yaml"
echo "     ./scripts/deploy-all.sh configs/schemas/my_table.yaml"
echo ""
echo "  3. 访问验证: http://localhost:3000  账号: admin / admin123"
echo ""
