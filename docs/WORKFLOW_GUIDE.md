# 工作流程指南

## 两种部署方式

| 方式 | 命令 | 适用场景 |
|-----|------|---------|
| **一键部署** | `./scripts/deploy-all.sh` | 首次部署、完整测试 |
| **四步部署** | 分步命令 | 调试、灵活控制 |

---

## 方式一：一键部署

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

# 完整部署
./scripts/deploy-all.sh configs/schemas/your_table.yaml

# 跳过清理（保留数据）
./scripts/deploy-all.sh configs/schemas/your_table.yaml --skip-cleanup

# 跳过重启（手动控制）
./scripts/deploy-all.sh configs/schemas/your_table.yaml --skip-restart

# 字典合并模式（不删除旧字典）
./scripts/deploy-all.sh configs/schemas/your_table.yaml --dict-strategy=merge
```

### 包含步骤
1. 清理旧代码和数据库表
2. 生成配置（含字典检查）
3. 生成代码
4. 建表 + 执行SQL + 复制代码 + 编译 + 重启

---

## 方式二：四步部署

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

# 第1步: 清理
./scripts/cleanup.sh your_table_name true

# 第2步: 生成配置
python3 main_allinone.py --schema configs/schemas/your_table.yaml --step=config

# 第3步: 生成代码
python3 main_allinone.py --schema configs/generated/your_table_name-config.yaml --step=generate

# 第4步: 部署（建表+SQL+复制+编译+重启）
./scripts/deploy-only.sh your_table_name
```

### 各步骤说明

| 步骤 | 命令 | 输入 | 输出 |
|-----|------|------|------|
| 清理 | `./scripts/cleanup.sh <表名> true` | 表名 | 删除代码+数据库表 |
| 生成配置 | `main_allinone.py --step=config` | Schema YAML | `configs/generated/xxx-config.yaml` |
| 生成代码 | `main_allinone.py --step=generate` | Config YAML | `output/xxx/` 目录 |
| 部署 | `./scripts/deploy-only.sh <表名>` | 表名 | 建表+SQL+复制+编译+重启 |

---

## 场景指南

### 场景1：新建业务表

```bash
# 1. 查看系统已有字典
./scripts/check-dicts.sh

# 2. 复制模板编写配置
cp configs/schemas/TEMPLATE.yaml configs/schemas/crm_customer.yaml
vim configs/schemas/crm_customer.yaml

# 3. 一键部署
./scripts/deploy-all.sh configs/schemas/crm_customer.yaml
```

### 场景2：修改字段后重新部署

```bash
# 编辑 Schema
vim configs/schemas/crm_customer.yaml

# 重新部署（包含清理）
./scripts/deploy-all.sh configs/schemas/crm_customer.yaml
```

### 场景3：只修改了模板，重新生成代码

```bash
# 跳过第1-2步，只重新生成+部署
python3 main_allinone.py --schema configs/generated/crm_customer-config.yaml --step=generate
./scripts/deploy-only.sh crm_customer
```

### 场景4：调试生成的代码

```bash
# 只生成配置，检查输出
python3 main_allinone.py --schema configs/schemas/test.yaml --step=config
cat configs/generated/test-config.yaml

# 只生成代码，检查输出
python3 main_allinone.py --schema configs/generated/test-config.yaml --step=generate
ls output/test/
cat output/test/vue/views/test/test/index.vue
```

---

## 脚本速查

| 脚本 | 用法 | 说明 |
|-----|------|------|
| `scripts/deploy-all.sh` | `<schema文件> [选项]` | 一键全流程 |
| `scripts/deploy-only.sh` | `<表名>` | 只做部署（第4步） |
| `scripts/cleanup.sh` | `<表名> true` | 清理代码+删表 |
| `scripts/check-dicts.sh` | `[关键词]` | 查看系统字典 |
| `scripts/verify.sh` | `<表名>` | 验证部署结果 |

---

## deploy-only.sh 做了什么

| 子步骤 | 操作 | 说明 |
|-------|------|------|
| 1 | 创建数据库表 | 自动查找 Schema 文件 |
| 2 | 执行字典SQL | 覆盖模式（先删后插，不会重复） |
| 3 | 执行菜单SQL | 注册菜单到系统 |
| 4 | 修复create_time | `DEFAULT CURRENT_TIMESTAMP` |
| 5 | 复制代码 | Vue + API + Controller + Service + Mapper |
| 6 | 编译并重启 | Maven 编译 + 重启 Java 服务 |
