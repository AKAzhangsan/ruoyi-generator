#!/bin/bash
# 通用部署脚本 - 根据表名部署
# 读取全局配置: configs/ruoyi-generator.yaml
# 用法: ./deploy.sh <table_name> [create_table]
# 示例: ./deploy.sh mvp2_test
# 示例: ./deploy.sh mvp2_test true  # 同时创建数据库表

set -e

TABLE_NAME=$1
CREATE_TABLE=${2:-false}  # 是否创建数据库表，默认false

if [ -z "$TABLE_NAME" ]; then
    echo "❌ 用法: ./deploy.sh <table_name> [create_table]"
    echo "   示例: ./deploy.sh mvp2_test"
    echo "   示例: ./deploy.sh mvp2_test true  # 同时创建数据库表"
    exit 1
fi

# 加载全局配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR_HOME="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$GENERATOR_HOME/configs/ruoyi-generator.yaml"

echo "🚀 开始部署 $TABLE_NAME..."

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

# 查找 ruoyi-admin 和 ruoyi-system
RUOYI_ADMIN=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-admin" | head -1)
RUOYI_SYSTEM=$(find "$RUOYI_BACKEND" -type d -name "ruoyi-system" | head -1)

if [ -z "$RUOYI_ADMIN" ] || [ -z "$RUOYI_SYSTEM" ]; then
    echo "❌ 未找到 ruoyi-admin 或 ruoyi-system 模块"
    exit 1
fi

# 检查输出目录
OUTPUT_DIR="$GENERATOR_HOME/output/$TABLE_NAME"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ 输出目录不存在: $OUTPUT_DIR"
    echo "   请先运行: python3 main_allinone.py --schema configs/schemas/${TABLE_NAME}.yaml --step=generate"
    exit 1
fi

echo "📂 ruoyi-admin: $RUOYI_ADMIN"
echo "📂 ruoyi-system: $RUOYI_SYSTEM"
echo "📂 输出目录: $OUTPUT_DIR"

# ============================================
# 可选: 创建数据库表
# ============================================
if [ "$CREATE_TABLE" = "true" ]; then
    echo ""
    echo "🗄️  创建数据库表 ${TABLE_NAME}..."
    
    # 查找 schema 文件（支持多种命名方式）
    SCHEMA_FILE=""
    
    # 尝试直接匹配表名
    if [ -f "$GENERATOR_HOME/configs/schemas/${TABLE_NAME}.yaml" ]; then
        SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/${TABLE_NAME}.yaml"
    # 尝试 test-前缀
    elif [ -f "$GENERATOR_HOME/configs/schemas/test-${TABLE_NAME}.yaml" ]; then
        SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/test-${TABLE_NAME}.yaml"
    # 尝试去掉 _test 后缀
    elif [[ "$TABLE_NAME" == *_test ]]; then
        BASE_NAME=${TABLE_NAME%_test}
        if [ -f "$GENERATOR_HOME/configs/schemas/${BASE_NAME}.yaml" ]; then
            SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/${BASE_NAME}.yaml"
        elif [ -f "$GENERATOR_HOME/configs/schemas/test-${BASE_NAME}.yaml" ]; then
            SCHEMA_FILE="$GENERATOR_HOME/configs/schemas/test-${BASE_NAME}.yaml"
        fi
    fi
    
    # 尝试从 configs/generated 目录查找关联的 schema
    if [ -z "$SCHEMA_FILE" ]; then
        # 查找 generated 目录下的 config 文件，提取原始 schema 路径
        CONFIG_FILE="$GENERATOR_HOME/configs/generated/${TABLE_NAME}-config.yaml"
        if [ -f "$CONFIG_FILE" ]; then
            # 尝试 test-mvp4.yaml 格式（从 mvp4_full_components 推断）
            if [[ "$TABLE_NAME" == mvp4_* ]]; then
                TRY_FILE="$GENERATOR_HOME/configs/schemas/test-mvp4.yaml"
                if [ -f "$TRY_FILE" ]; then
                    SCHEMA_FILE="$TRY_FILE"
                fi
            fi
        fi
    fi
    
    if [ -n "$SCHEMA_FILE" ] && [ -f "$SCHEMA_FILE" ]; then
        echo "  📖 使用 schema: $SCHEMA_FILE"
        if python3 "$GENERATOR_HOME/main_allinone.py" --schema "$SCHEMA_FILE" --step=create; then
            echo "  ✅ 数据库表创建完成"
        else
            echo "  ❌ 数据库表创建失败"
            exit 1
        fi
    else
        echo "  ⚠️  未找到 schema 文件，跳过建表"
        echo "      查找路径: configs/schemas/${TABLE_NAME}.yaml"
        echo "               configs/schemas/test-${TABLE_NAME}.yaml"
    fi
fi

# ============================================
# 1. 复制 Controller 到 ruoyi-admin
# ============================================
echo ""
echo "📦 复制 Controller 到 ruoyi-admin..."
if [ -d "$OUTPUT_DIR/main/java/com/ruoyi/web/controller" ]; then
    mkdir -p "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller"
    cp -r "$OUTPUT_DIR/main/java/com/ruoyi/web/controller/"* "$RUOYI_ADMIN/src/main/java/com/ruoyi/web/controller/"
    echo "  ✅ Controller 复制完成"
fi

# ============================================
# 2. 复制其他 Java 代码到 ruoyi-system
# ============================================
echo ""
echo "📦 复制 Service/Mapper/Domain 到 ruoyi-system..."
for module_dir in "$OUTPUT_DIR/main/java/com/ruoyi"/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        [ "$module_name" == "web" ] && continue
        
        target_dir="$RUOYI_SYSTEM/src/main/java/com/ruoyi/$module_name"
        mkdir -p "$target_dir"
        # 修复：正确复制目录内容
        cp -r "${module_dir}"* "$target_dir/" 2>/dev/null || cp -r "$module_dir"* "$target_dir/" 2>/dev/null || true
        echo "  ✅ $module_name 复制完成"
    fi
done

# 如果没找到模块，直接复制整个 test 目录
if [ -d "$OUTPUT_DIR/main/java/com/ruoyi/test" ] && [ ! -d "$RUOYI_SYSTEM/src/main/java/com/ruoyi/test/service" ]; then
    mkdir -p "$RUOYI_SYSTEM/src/main/java/com/ruoyi"
    cp -r "$OUTPUT_DIR/main/java/com/ruoyi/test" "$RUOYI_SYSTEM/src/main/java/com/ruoyi/"
    echo "  ✅ test 模块强制复制完成"
fi

# ============================================
# 3. 复制 Mapper XML
# ============================================
echo ""
echo "📦 复制 Mapper XML..."
if [ -d "$OUTPUT_DIR/main/resources/mapper" ]; then
    mkdir -p "$RUOYI_SYSTEM/src/main/resources/mapper"
    cp -r "$OUTPUT_DIR/main/resources/mapper/"* "$RUOYI_SYSTEM/src/main/resources/mapper/"
    echo "  ✅ Mapper XML 复制完成"
fi

# ============================================
# 4. 复制前端代码
# ============================================
echo ""
echo "📦 复制前端代码..."
if [ -d "$OUTPUT_DIR/vue" ]; then
    cp -r "$OUTPUT_DIR/vue/"* "$RUOYI_FRONTEND/src/"
    echo "  ✅ Vue 代码复制完成"
fi

# ============================================
# 5. 执行菜单 SQL
# ============================================
echo ""
echo "🗄️  执行菜单 SQL..."
SQL_FILE="$OUTPUT_DIR/sql/${TABLE_NAME}_menu.sql"
if [ -f "$SQL_FILE" ]; then
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_FILE" 2>/dev/null && echo "  ✅ 菜单 SQL 执行完成" || echo "  ⚠️  SQL 执行可能失败"
fi

# ============================================
# 6. 执行字典 SQL（交互式）
# ============================================
echo ""
echo "🗄️  检查字典 SQL..."
DICT_SQL_DIR="$OUTPUT_DIR/sql"
DICT_SQL_COUNT=$(find "$DICT_SQL_DIR" -name "dict_*.sql" 2>/dev/null | wc -l)

if [ "$DICT_SQL_COUNT" -gt 0 ]; then
    echo "  发现 $DICT_SQL_COUNT 个字典 SQL 文件:"
    
    for dict_sql in "$DICT_SQL_DIR"/dict_*.sql; do
        if [ -f "$dict_sql" ]; then
            dict_name=$(basename "$dict_sql" .sql | sed 's/dict_//')
            echo ""
            echo "  📖 字典: $dict_name"
            echo "     文件: $dict_sql"
            
            # 显示 SQL 内容预览（前 10 行）
            echo "     预览:"
            head -n 5 "$dict_sql" | sed 's/^/       /'
            echo "       ..."
            
            # 交互式确认
            read -p "     是否执行此字典 SQL? [y/N]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                read -p "     执行策略 [merge(合并)/replace(替换)/skip(跳过)]: " strategy
                strategy=${strategy:-merge}
                
                if [ "$strategy" != "skip" ]; then
                    if [ "$strategy" = "replace" ]; then
                        # 先删除旧数据
                        dict_type=$(echo "$dict_name" | sed 's/dict_//')
                        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
DELETE FROM sys_dict_data WHERE dict_type = '${dict_type}';
DELETE FROM sys_dict_type WHERE dict_type = '${dict_type}';
" 2>/dev/null
                        echo "     🗑️  已删除旧字典数据"
                    fi
                    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$dict_sql" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "     ✅ 字典 $dict_name 执行完成 ($strategy)"
                    else
                        echo "     ⚠️  字典 $dict_name 执行可能失败"
                    fi
                else
                    echo "     ⏭️  跳过字典 $dict_name"
                fi
            else
                echo "     ⏭️  跳过字典 $dict_name"
            fi
        fi
    done
else
    echo "  ℹ️  未发现字典 SQL 文件"
fi

# ============================================
# 7. 编译后端
# ============================================
echo ""
echo "🔨 编译后端..."
cd "$RUOYI_BACKEND"
mvn clean package -DskipTests -q

# ============================================
# 8. 重启服务
# ============================================
echo ""
echo "🔄 重启服务..."

# 切换到项目目录
PROJECT_HOME="$HOME/.openclaw/workspace/projects/ruoyi"
cd "$PROJECT_HOME"

# 停止服务（使用 PID 文件或直接 kill）
if [ -f "$PROJECT_HOME/backend.pid" ]; then
    PID=$(cat "$PROJECT_HOME/backend.pid")
    if kill -0 $PID 2>/dev/null; then
        echo "  停止后端 (PID: $PID)..."
        kill $PID 2>/dev/null || true
    fi
    rm -f "$PROJECT_HOME/backend.pid"
fi

if [ -f "$PROJECT_HOME/frontend.pid" ]; then
    PID=$(cat "$PROJECT_HOME/frontend.pid")
    if kill -0 $PID 2>/dev/null; then
        echo "  停止前端 (PID: $PID)..."
        kill $PID 2>/dev/null || true
    fi
    rm -f "$PROJECT_HOME/frontend.pid"
fi

# 确保进程已停止
pkill -f "ruoyi-admin.jar" 2>/dev/null || true
pkill -f "vite --host" 2>/dev/null || true
sleep 3

echo "  ✅ 旧服务已停止"

# 启动后端
echo "  启动后端 (端口 8080)..."
cd "$RUOYI_BACKEND"
nohup java -jar ruoyi-admin/target/ruoyi-admin.jar > "$PROJECT_HOME/backend.log" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$PROJECT_HOME/backend.pid"
echo "  后端 PID: $BACKEND_PID"

# 等待后端启动
echo "  等待后端启动..."
for i in {1..30}; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo "  ✅ 后端已启动"
        break
    fi
    sleep 1
done

# 启动前端
echo "  启动前端 (端口 3000)..."
cd "$RUOYI_FRONTEND"
nohup ./node_modules/.bin/vite --host 0.0.0.0 --port 3000 > "$PROJECT_HOME/frontend.log" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$PROJECT_HOME/frontend.pid"
echo "  前端 PID: $FRONTEND_PID"

echo ""
echo "================================"
echo "✅ $TABLE_NAME 部署完成！"
echo ""
echo "📍 访问地址:"
echo "   前端: http://localhost:3000"
echo "   后端: http://localhost:8080"
echo ""
echo "🛑 停止服务:"
echo "   cd $PROJECT_HOME && ./stop.sh"
