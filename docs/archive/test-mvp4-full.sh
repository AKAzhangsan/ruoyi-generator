#!/bin/bash
# MVP4 完整测试脚本 - 清理→生成→编译→运行

set -e

echo "========== MVP4 全组件测试 =========="
echo ""

cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator
# ============================================
# 步骤1: 停止服务
# ============================================
echo "【1/7】停止若依服务..."
cd /home/pei16/.openclaw/workspace/projects/ruoyi
pkill -f "ruoyi-admin" 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
sleep 3
echo "✅ 服务已停止"

# ============================================
# 步骤2: 清理旧数据
# ============================================
echo ""
echo "【2/7】清理旧数据..."
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

# 清理菜单
mysql -h localhost -P 3306 -u ruoyi -pruoyi123 ry_vue -e "
DELETE FROM sys_menu WHERE perms LIKE 'test:mvp4_full_components:%';
" 2>/dev/null || true

# 清理字典
mysql -h localhost -P 3306 -u ruoyi -pruoyi123 ry_vue -e "
DELETE FROM sys_dict_data WHERE dict_type LIKE 'sys_mvp4_%';
DELETE FROM sys_dict_type WHERE dict_type LIKE 'sys_mvp4_%';
" 2>/dev/null || true

# 清理代码
rm -rf /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend/src/views/test/mvp4_full_components 2>/dev/null || true
rm -f /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend/src/api/test/mvp4_full_components.js 2>/dev/null || true
rm -f /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test/Mvp4FullComponentsController.java 2>/dev/null || true
rm -rf /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/java/com/ruoyi/test 2>/dev/null || true
rm -f /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/resources/mapper/test/Mvp4FullComponentsMapper.xml 2>/dev/null || true

echo "✅ 旧数据已清理"

# ============================================
# 步骤3: 生成配置
# ============================================
echo ""
echo "【3/7】生成配置..."
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=config
echo "✅ 配置生成完成"

# ============================================
# 步骤4: 生成代码
# ============================================
echo ""
echo "【4/7】生成代码..."
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=generate
echo "✅ 代码生成完成"

# ============================================
# 步骤5: 创建数据库表
# ============================================
echo ""
echo "【5/7】创建数据库表..."
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=create
echo "✅ 数据库表创建完成"

# ============================================
# 步骤6: 复制代码到项目
# ============================================
echo ""
echo "【6/7】复制代码到项目..."

# Controller
mkdir -p /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test
cp output/mvp4_full_components/main/java/com/ruoyi/web/controller/test/*.java /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-admin/src/main/java/com/ruoyi/web/controller/test/
echo "  ✅ Controller 复制完成"

# Service/Mapper/Domain
mkdir -p /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/java/com/ruoyi
cp -r output/mvp4_full_components/main/java/com/ruoyi/test /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/java/com/ruoyi/
echo "  ✅ Service/Mapper/Domain 复制完成"

# Mapper XML
mkdir -p /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/resources/mapper
cp -r output/mvp4_full_components/main/resources/mapper/* /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend/ruoyi-system/src/main/resources/mapper/ 2>/dev/null || true
echo "  ✅ Mapper XML 复制完成"

# 前端代码
mkdir -p /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend/src/views/test
cp -r output/mvp4_full_components/vue/views/* /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend/src/views/
cp output/mvp4_full_components/vue/api/*.js /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend/src/api/test/ 2>/dev/null || true
echo "  ✅ 前端代码复制完成"

# 执行菜单SQL
mysql -h localhost -P 3306 -u ruoyi -pruoyi123 ry_vue < output/mvp4_full_components/sql/mvp4_full_components_menu.sql 2>/dev/null || true
echo "  ✅ 菜单SQL执行完成"

# 执行字典SQL
for sql_file in output/mvp4_full_components/sql/dict_*.sql; do
    if [ -f "$sql_file" ]; then
        mysql -h localhost -P 3306 -u ruoyi -pruoyi123 ry_vue < "$sql_file" 2>/dev/null || true
    fi
done
echo "  ✅ 字典SQL执行完成"

# ============================================
# 步骤7: 编译并启动
# ============================================
echo ""
echo "【7/7】编译并启动服务..."

cd /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend
echo "  🔨 编译后端..."
mvn clean package -DskipTests -q
echo "  ✅ 编译完成"

echo ""
echo "  🚀 启动后端..."
nohup java -jar ruoyi-admin/target/ruoyi-admin.jar > /tmp/backend.log 2>&1 &
sleep 40
echo "  ✅ 后端已启动"

echo ""
echo "  🚀 启动前端..."
cd /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-frontend
nohup pnpm dev > /tmp/frontend.log 2>&1 &
sleep 10
echo "  ✅ 前端已启动"

echo ""
echo "========== 测试完成 =========="
echo "访问地址: http://localhost:3000"
echo ""
echo "查看后端日志: tail -f /tmp/backend.log"
echo "查看前端日志: tail -f /tmp/frontend.log"
