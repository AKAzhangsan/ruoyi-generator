#!/bin/bash
# MVP 第4步部署脚本 - 参考 deploy.sh 实现
# 用法: ./mvp-step4-deploy.sh <table_name>
# 示例: ./mvp-step4-deploy.sh mvp5_full_validation

set -e

TABLE_NAME=${1:-""}

if [ -z "$TABLE_NAME" ]; then
    echo "用法: ./mvp-step4-deploy.sh <table_name>"
    echo "示例: ./mvp-step4-deploy.sh mvp5_full_validation"
    exit 1
fi

# 加载配置
GENERATOR_HOME="/home/pei16/.openclaw/workspace/projects/ruoyi-generator"
CONFIG_FILE="$GENERATOR_HOME/configs/ruoyi-generator.yaml"

if [ -f "$CONFIG_FILE" ]; then
    RUOYI_BACKEND=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['ruoyi_backend'])")
    RUOYI_FRONTEND=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['ruoyi_frontend'])")
    DB_HOST=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['host'])")
    DB_PORT=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['port'])")
    DB_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['name'])")
    DB_USER=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['user'])")
    DB_PASS=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['database']['password'])")
else
    RUOYI_BACKEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend"
    RUOYI_FRONTEND="/home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend"
    DB_HOST="localhost"
    DB_PORT="3306"
    DB_NAME="ry_vue"
    DB_USER="ruoyi"
    DB_PASS="ruoyi123"
fi

# 查找 ruoyi-admin 和 ruoyi-system
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

# 检查输出目录
OUTPUT_DIR="$GENERATOR_HOME/output/$TABLE_NAME"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ 输出目录不存在: $OUTPUT_DIR"
    echo "   请先运行: python3 main_allinone.py --step=generate"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MVP 第4步 - 部署                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Table: $TABLE_NAME"
echo ""

# 查找 schema 文件（参考 deploy.sh）
SCHEMA_FILE=""
if [ -f "$GENERATOR_HOME/configs/schemas/${TABLE_NAME}.yaml" ]; then
    SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/${TABLE_NAME}.yaml"
elif [ -f "$GENERATOR_HOME/configs/schemas/test-${TABLE_NAME}.yaml" ]; then
    SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/test-${TABLE_NAME}.yaml"
else
    # 遍历所有 schema 文件，查找包含该表名的文件
    for f in "$GENERATOR_HOME/configs/schemas/"*.yaml; do
        if [ -f "$f" ] && grep -q "table_name: ${TABLE_NAME}" "$f" 2>/dev/null; then
            SCHEMA_FILE="$f"
            break
        fi
    done
fi

# 1. 创建数据库表（优先使用 SQL 文件，否则用 schema）
echo "【1/6】创建数据库表..."
if [ -f "$OUTPUT_DIR/sql/create_${TABLE_NAME}.sql" ]; then
    mysql -hlocalhost -P3306 -u${DB_USER} -p"${DB_PASS}" ${DB_NAME} < "$OUTPUT_DIR/sql/create_${TABLE_NAME}.sql" 2>/dev/null || echo "  表可能已存在"
elif [ -n "$SCHEMA_FILE" ]; then
    python3 "$GENERATOR_HOME/main_allinone.py" --schema "$SCHEMA_FILE" --step=create > /dev/null 2>&1 || echo "  表可能已存在（或用SQL文件）"
else
    echo "  ⚠️ 未找到建表SQL或schema文件，跳过建表"
fi
echo ""

# 2. 执行字典SQL（覆盖模式）
echo "【2/6】执行字典SQL（覆盖模式）..."
for sql_file in "$OUTPUT_DIR"/sql/dict_*.sql; do
    if [ -f "$sql_file" ]; then
        dict_name=$(basename "$sql_file" .sql | sed 's/dict_//')
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
            "DELETE FROM sys_dict_data WHERE dict_type='$dict_name'; DELETE FROM sys_dict_type WHERE dict_type='$dict_name';" \
            2>/dev/null || true
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file"
        echo "  ✓ $dict_name"
    fi
done
echo ""

# 3. 执行菜单SQL
echo "【3/6】执行菜单SQL..."
if [ -f "$OUTPUT_DIR/sql/${TABLE_NAME}_menu.sql" ]; then
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        < "$OUTPUT_DIR/sql/${TABLE_NAME}_menu.sql" 2>/dev/null
    echo "  ✓ 菜单已执行"
fi
echo ""

# 4. 修复create_time默认值
echo "【4/6】修复create_time默认值..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
    "ALTER TABLE $TABLE_NAME MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;" 2>/dev/null || true
echo "  ✓ create_time已设置"
echo ""

# 5. 复制代码（参考 deploy.sh）
echo "【5/6】复制代码到项目..."

# Controller
if [ -d "$OUTPUT_DIR/main/java/com/ruoyi/web/controller" ]; then
    mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller"
    cp -r "$OUTPUT_DIR/main/java/com/ruoyi/web/controller/"* "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/" 2>/dev/null
    echo "  ✓ Controller"
fi

# Service/Mapper/Domain
if [ -d "$OUTPUT_DIR/main/java/com/ruoyi/test" ]; then
    mkdir -p "$RUOYI_SYSTEM/src/main/java/com/ruoyi"
    cp -r "$OUTPUT_DIR/main/java/com/ruoyi/test" "$RUOYI_SYSTEM/src/main/java/com/ruoyi/" 2>/dev/null
    echo "  ✓ Service/Mapper/Domain"
fi

# Mapper XML
if [ -d "$OUTPUT_DIR/main/resources/mapper" ]; then
    mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper"
    cp -r "$OUTPUT_DIR/main/resources/mapper/"* "$RUOYI_SYSTEM/src/main/resources/mapper/" 2>/dev/null
    echo "  ✓ Mapper XML"
fi

# Vue
if [ -d "$OUTPUT_DIR/vue/views" ]; then
    mkdir -p "$RUOYI_FRONTEND/src/views"
    cp -r "$OUTPUT_DIR/vue/views/"* "$RUOYI_FRONTEND/src/views/" 2>/dev/null
    echo "  ✓ Vue文件"
fi

# API
if [ -d "$OUTPUT_DIR/vue/api" ]; then
    mkdir -p "$RUOYI_FRONTEND/src/api"
    cp -r "$OUTPUT_DIR/vue/api/"* "$RUOYI_FRONTEND/src/api/" 2>/dev/null
    echo "  ✓ API文件"
fi
echo ""

# 6. 编译并重启
echo "【6/6】编译并重启..."
cd "$RUOYI_BACKEND"
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q > /tmp/mvn.log 2>&1 && echo "  ✓ 编译完成"

pkill -f ruoyi-admin 2>/dev/null || true
sleep 2
cd ruoyi-admin/target
nohup java -jar ruoyi-admin.jar > /tmp/ruoyi.log 2>&1 &
echo "  ✓ 后端已启动"
cd -

echo ""
echo "✅ 第4步完成！"
echo ""
echo "访问: http://localhost:3000"
echo "账号: admin / admin123"
