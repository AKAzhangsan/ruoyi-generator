#!/bin/bash
# 字典检查工具 - 查看系统已有字典，避免重复创建

echo "🔍 RuoYi 系统字典查询"
echo "======================"
echo ""

# 读取数据库配置
DB_CONFIG="configs/ruoyi-generator.yaml"

if [ ! -f "$DB_CONFIG" ]; then
    echo "❌ 未找到配置文件: $DB_CONFIG"
    exit 1
fi

# 解析YAML获取数据库配置（简单方式）
DB_HOST=$(grep -A5 "database:" "$DB_CONFIG" | grep "host:" | awk '{print $2}')
DB_PORT=$(grep -A5 "database:" "$DB_CONFIG" | grep "port:" | awk '{print $2}')
DB_NAME=$(grep -A5 "database:" "$DB_CONFIG" | grep "name:" | awk '{print $2}')
DB_USER=$(grep -A5 "database:" "$DB_CONFIG" | grep "user:" | awk '{print $2}')
DB_PASS=$(grep -A5 "database:" "$DB_CONFIG" | grep "password:" | awk '{print $2}')

# 使用默认值
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-ry-vue}
DB_USER=${DB_USER:-root}
DB_PASS=${DB_PASS:-123456}

# 显示当前配置
echo "📋 数据库配置:"
echo "   主机: $DB_HOST:$DB_PORT"
echo "   数据库: $DB_NAME"
echo "   用户: $DB_USER"
echo ""

# 检查是否有搜索关键词
KEYWORD=${1:-""}

if [ -n "$KEYWORD" ]; then
    echo "🔎 搜索包含 '$KEYWORD' 的字典..."
    echo ""
    SQL="SELECT dict_type, dict_name FROM $DB_NAME.sys_dict_type WHERE dict_type LIKE '%$KEYWORD%' OR dict_name LIKE '%$KEYWORD%';"
else
    echo "📚 所有系统字典列表:"
    echo ""
    SQL="SELECT dict_type, dict_name FROM $DB_NAME.sys_dict_type ORDER BY dict_type;"
fi

# 执行查询
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS -e "$SQL" 2>/dev/null

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ 数据库连接失败，请检查:"
    echo "   1. MySQL服务是否运行"
    echo "   2. 数据库配置是否正确"
    echo "   3. 用户名密码是否正确"
    echo ""
    echo "当前配置:"
    echo "   主机: $DB_HOST"
    echo "   端口: $DB_PORT"
    echo "   数据库: $DB_NAME"
    echo "   用户: $DB_USER"
    exit 1
fi

echo ""
echo "======================"
echo "💡 常用系统字典推荐:"
echo ""
echo "状态类:"
echo "   sys_normal_disable    正常/停用"
echo "   sys_yes_no            是/否"
echo "   sys_common_status     成功/失败"
echo ""
echo "显示类:"
echo "   sys_show_hide         显示/隐藏"
echo ""
echo "用户类:"
echo "   sys_user_sex          男/女/未知"
echo ""
echo "通知类:"
echo "   sys_notice_type       通知/公告"
echo "   sys_notice_status     正常/关闭"
echo ""
echo "🔧 使用说明:"
echo "   ./check-dicts.sh          查看所有字典"
echo "   ./check-dicts.sh status   搜索包含status的字典"
