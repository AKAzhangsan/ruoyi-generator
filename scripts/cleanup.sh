#!/bin/bash
# 通用清理脚本 - 根据表名清理
# 读取全局配置: configs/ruoyi-generator.yaml
# 用法: ./cleanup.sh <table_name>
# 示例: ./cleanup.sh mvp2_test

set -e

TABLE_NAME=$1
DELETE_TABLE=${2:-false}  # 是否删除数据库表，默认false

if [ -z "$TABLE_NAME" ]; then
    echo "❌ 用法: ./cleanup.sh <table_name> [delete_table]"
    echo "   示例: ./cleanup.sh mvp2_test"
    echo "   示例: ./cleanup.sh mvp2_test true  # 同时删除数据库表"
    exit 1
fi

# 加载全局配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR_HOME="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$GENERATOR_HOME/configs/ruoyi-generator.yaml"

echo "🧹 清理 $TABLE_NAME 相关数据..."

# 如果配置文件存在，读取配置
if [ -f "$CONFIG_FILE" ]; then
    echo "📖 读取全局配置: $CONFIG_FILE"
    
    # 使用 Python 解析 YAML
    read_config() {
        python3 -c "
import yaml
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = yaml.safe_load(f)
    print(config.get('$1', ''))
except Exception as e:
    sys.exit(1)
"
    }
    
    RUOYI_BACKEND=$(read_config 'ruoyi_backend')
    RUOYI_FRONTEND=$(read_config 'ruoyi_frontend')
    
    # 读取数据库配置
    DB_HOST=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['host'])")
    DB_PORT=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['port'])")
    DB_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['name'])")
    DB_USER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['user'])")
    DB_PASS=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['password'])")
else
    echo "⚠️  全局配置文件不存在，使用默认配置"
    
    # 默认配置
    RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
    RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"
    DB_HOST="localhost"
    DB_PORT="3306"
    DB_NAME="ry_vue"
    DB_USER="ruoyi"
    DB_PASS="ruoyi123"
fi

# 检查路径是否存在
if [ ! -d "$RUOYI_BACKEND" ]; then
    echo "❌ 若依后端目录不存在: $RUOYI_BACKEND"
    exit 1
fi

if [ ! -d "$RUOYI_FRONTEND" ]; then
    echo "❌ 若依前端目录不存在: $RUOYI_FRONTEND"
    exit 1
fi

# 转换为类名（用于查找文件）
CLASS_NAME=$(echo $TABLE_NAME | sed 's/_\([a-z]\)/\u\1/g' | sed 's/^\([a-z]\)/\u\1/')

echo "📂 若依后端: $RUOYI_BACKEND"
echo "📂 若依前端: $RUOYI_FRONTEND"
echo "🗄️  数据库: $DB_NAME@$DB_HOST"

# 1. 清理后端代码
echo ""
echo "📁 清理后端代码..."
find "$RUOYI_BACKEND" -name "${CLASS_NAME}.java" -type f -delete 2>/dev/null && echo "  ✅ 删除 ${CLASS_NAME}.java" || true
find "$RUOYI_BACKEND" -name "${CLASS_NAME}Mapper.xml" -type f -delete 2>/dev/null && echo "  ✅ 删除 ${CLASS_NAME}Mapper.xml" || true
find "$RUOYI_BACKEND" -name "${CLASS_NAME}Controller.java" -type f -delete 2>/dev/null && echo "  ✅ 删除 ${CLASS_NAME}Controller.java" || true
find "$RUOYI_BACKEND" -name "I${CLASS_NAME}Service.java" -type f -delete 2>/dev/null && echo "  ✅ 删除 I${CLASS_NAME}Service.java" || true
find "$RUOYI_BACKEND" -name "${CLASS_NAME}ServiceImpl.java" -type f -delete 2>/dev/null && echo "  ✅ 删除 ${CLASS_NAME}ServiceImpl.java" || true

# 2. 清理前端代码
echo ""
echo "📁 清理前端代码..."
rm -rf "$RUOYI_FRONTEND/src/views/"*"/${TABLE_NAME}" 2>/dev/null && echo "  ✅ 删除视图目录" || true
rm -f "$RUOYI_FRONTEND/src/api/"*"/${TABLE_NAME}.js" 2>/dev/null && echo "  ✅ 删除 API 文件" || true

# 3. 清理数据库菜单
echo ""
echo "🗄️  清理数据库菜单..."
# 构造权限前缀（从表名推导，如 mvp3_test → test:mvp3）
PERMISSION_PREFIX="${TABLE_NAME%_*}:${TABLE_NAME%%_*}"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
DELETE FROM sys_menu WHERE perms LIKE '${PERMISSION_PREFIX}:%' OR path='${TABLE_NAME}';
" 2>/dev/null && echo "  ✅ 数据库菜单已清理" || echo "  ⚠️  数据库菜单清理可能失败"

# 4. 清理关联的字典数据
echo ""
echo "🗄️  清理关联字典数据..."
# 构造可能的字典类型名称（表名去掉前缀，如 mvp3_test → mvp3）
TABLE_SUFFIX="${TABLE_NAME#*_}"
if [ -n "$TABLE_SUFFIX" ]; then
    # 删除与该表相关的字典数据（匹配 sys_xxx_{suffix} 或 sys_{suffix}_xxx 模式）
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
DELETE FROM sys_dict_data WHERE dict_type LIKE '%${TABLE_SUFFIX}%';
DELETE FROM sys_dict_type WHERE dict_type LIKE '%${TABLE_SUFFIX}%';
" 2>/dev/null && echo "  ✅ 字典数据已清理" || echo "  ⚠️  字典数据清理可能失败"
fi

# 5. 删除数据库表（可选）
if [ "$DELETE_TABLE" = "true" ]; then
    echo ""
    echo "🗄️  删除数据库表 ${TABLE_NAME}..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
DROP TABLE IF EXISTS \`${TABLE_NAME}\`;
" 2>/dev/null && echo "  ✅ 数据库表 ${TABLE_NAME} 已删除" || echo "  ⚠️  删除数据库表失败"
fi

# 5. 清理生成的输出目录
echo ""
echo "📁 清理输出目录..."
OUTPUT_DIR="$GENERATOR_HOME/output/${TABLE_NAME}"
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo "  ✅ 删除 output/${TABLE_NAME}"
fi

echo ""
echo "✅ $TABLE_NAME 清理完成！"

if [ "$DELETE_TABLE" != "true" ]; then
    echo ""
    echo "💡 提示: 如需同时删除数据库表，请运行:"
    echo "   ./cleanup.sh ${TABLE_NAME} true"
fi
