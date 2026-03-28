#!/bin/bash
# MVP4 测试脚本

echo "=== MVP4 全组件测试 ==="
echo ""

cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

echo "1. 生成配置..."
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=config

echo ""
echo "2. 生成代码..."
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=generate

echo ""
echo "3. 清理旧数据..."
./scripts/cleanup.sh mvp4_full_components

echo ""
echo "4. 创建数据库表..."
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=create

echo ""
echo "5. 部署..."
./scripts/deploy.sh mvp4_full_components

echo ""
echo "=== 完成 ==="
echo "访问: http://localhost:3000"
