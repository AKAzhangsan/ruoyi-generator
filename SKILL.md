---
name: ruoyi-generator
description: 'All-in-one code generator for RuoYi management system. Use when: (1) creating new CRUD modules from scratch, (2) generating complete backend (Java) and frontend (Vue3) code, (3) one-click deploy to RuoYi project. Supports: define table in YAML -> auto create table -> generate code -> deploy to project.'
metadata:
  {
    "openclaw": { "emoji": "🏗️", "requires": { "bins": ["python3", "mysql"] } },
  }
---

# RuoYi Generator - All-in-One

一体化若依代码生成器。从 YAML 表定义到完整部署，一键完成。

## 项目路径

路径配置在 `configs/ruoyi-generator.yaml`，安装时由 `install.sh` 自动生成。

```yaml
# configs/ruoyi-generator.yaml 中的关键配置
ruoyi_backend: /path/to/ruoyi-backend    # 若依后端路径
ruoyi_frontend: /path/to/ruoyi-frontend  # 若依前端路径
database:
  host: localhost
  port: 3306
  name: ry_vue
  user: ruoyi
  password: ruoyi123
```

## 安装

```bash
git clone https://github.com/AKAzhangsan/ruoyi-generator.git
cd ruoyi-generator
./install.sh
# 然后编辑 configs/ruoyi-generator.yaml 填写实际路径和数据库信息
```

## 支持的模板类型

| 类型 | 说明 | Schema 模板 | 生成文件数 |
|------|------|------------|-----------|
| **单表（crud）** | 基础增删改查 + 分页 | `schema-template.yaml` | 9个 |
| **树表（tree）** | 树形结构增删改查 | `schema-tree-template.yaml` | 9个 |
| **主子表（sub）** | 主表+子表一对多 | `schema-sub-template.yaml` | 10个 |

## 使用方式

### 方式一：一键部署（推荐）

```bash
# 单表
./scripts/deploy-all.sh configs/schemas/your_table.yaml

# 树表
./scripts/deploy-all.sh configs/schemas/your_tree.yaml

# 主子表
./scripts/deploy-all.sh configs/schemas/your_order.yaml
```

**可选参数：**
```bash
--skip-cleanup         # 跳过清理
--skip-restart         # 跳过重启
--dict-strategy=merge  # 字典合并模式
```

### 方式二：四步部署（灵活控制）

```bash
# 第1步: 清理（可选）
./scripts/cleanup.sh <table_name> true

# 第2步: 生成配置
python3 main_allinone.py --schema configs/schemas/<schema>.yaml --step=config

# 第3步: 生成代码
python3 main_allinone.py --schema configs/generated/<table>-config.yaml --step=generate

# 第4步: 部署（建表+SQL+复制代码+编译+重启）
./scripts/deploy-only.sh <table_name>
```

### 新建业务表完整流程

```bash
# 1. 查看系统已有字典（避免重复创建）
./scripts/check-dicts.sh

# 2. 复制模板编写配置
cp templates/configs/schema-template.yaml configs/schemas/crm_customer.yaml     # 单表
cp templates/configs/schema-tree-template.yaml configs/schemas/sys_category.yaml # 树表
cp templates/configs/schema-sub-template.yaml configs/schemas/biz_order.yaml     # 主子表

# 3. 编辑 YAML，定义表结构和字段

# 4. 一键部署
./scripts/deploy-all.sh configs/schemas/crm_customer.yaml

# 5. 访问验证: http://localhost:3000  账号: admin / admin123
```

## 三种模板对比

| 特性 | 单表（crud） | 树表（tree） | 主子表（sub） |
|------|------------|------------|-------------|
| **Entity** | `extends BaseEntity` | `extends TreeEntity` | `BaseEntity` + `List<SubEntity>` |
| **列表** | 分页表格 | 树形表格（无分页） | 分页表格 |
| **Controller** | `startPage()` + `TableDataInfo` | `AjaxResult` | `startPage()` + `TableDataInfo` |
| **前端特性** | 批量删除、分页 | 展开/折叠、新增子节点 | 主表单 + 子表行内编辑 |
| **必备字段** | 无 | `parent_id` + `ancestors` + `order_num` | 主表PK + 子表FK |
| **Schema 配置** | 默认 | `tpl_type: tree` + `tree_config` | `tpl_type: sub` + `sub_table` |
| **事务管理** | 无 | 无 | `@Transactional` |
| **级联删除** | 无 | 无 | ✅ |

## 主子表 Schema 要点

```yaml
tpl_type: sub              # 指定为主子表

sub_table:
  table_name: xxx_item     # 子表名
  table_comment: xxx明细   # 子表注释
  fk_column: order_id      # 外键字段（关联主表PK）
  columns:                 # 子表字段列表
    - name: item_id
      is_pk: true
      is_auto_increment: true
    - name: order_id       # 外键字段必须包含
      type: bigint
    - name: product_name   # Input
      component: Input
    - name: item_type      # Select + 字典
      component: Select
      dict_type: sys_xxx_type
    - name: quantity       # InputNumber
      component: InputNumber
    - name: price          # InputNumber（小数）
      type: decimal
      component: InputNumber
    - name: delivery_date  # DatePicker
      component: DatePicker
      date_format: YYYY-MM-DD
```

### 子表支持的组件

| 组件 | 说明 |
|------|------|
| Input | 文本输入（自适应列宽） |
| InputNumber | 数字输入（自适应列宽） |
| Select | 字典下拉（自适应列宽） |
| Radio | 转为 Select（行内更合适） |
| DatePicker | 日期选择（自适应列宽） |

不支持：Textarea、Editor、ImageUpload、FileUpload、Checkbox（行内空间限制）

## 树表 Schema 要点

```yaml
tpl_type: tree
tree_config:
  tree_code: id                # 节点ID
  tree_parent_code: parent_id  # 父节点字段
  tree_name: category_name     # 树节点显示名称
```

## 单表支持的全部组件（11种）

| 组件 | YAML 配置 | 适用场景 |
|------|-----------|---------|
| Input | `component: Input` | 短文本 |
| Textarea | `component: Textarea` | 长文本 |
| Radio | `component: Radio` + `dict_type` | 2-5个选项 |
| Select | `component: Select` + `dict_type` | 5个以上选项 |
| Checkbox | `component: Checkbox` + `dict_type` | 多选（varchar存储） |
| InputNumber | `component: InputNumber` | 整数/小数 |
| DatePicker | `date_format: YYYY-MM-DD` | 纯日期 |
| DatePicker | `date_format: YYYY-MM-DD HH:mm:ss` | 日期时间 |
| ImageUpload | `component: ImageUpload` + `limit` | 图片上传 |
| FileUpload | `component: FileUpload` + `limit` | 文件上传 |
| Editor | `component: Editor` + `height` | 富文本 |

## 字典使用规则

### 系统字典（直接引用，无需定义）
- `sys_normal_disable` — 正常/停用
- `sys_yes_no` — 是/否
- `sys_user_sex` — 男/女/未知

### 新业务字典（需在 dicts 部分定义）
- 必须加业务前缀：`sys_crm_category`
- 查看已有字典：`./scripts/check-dicts.sh`

## 脚本说明

| 脚本 | 用法 | 说明 |
|------|------|------|
| `deploy-all.sh` | `<schema文件> [选项]` | 一键全流程部署 |
| `deploy-only.sh` | `<表名>` | 只做部署步骤（第4步） |
| `cleanup.sh` | `<表名> true` | 清理代码+删表 |
| `check-dicts.sh` | `[关键词]` | 查看系统已有字典 |
| `verify.sh` | `<表名>` | 验证部署结果 |
| `install.sh` | 无参数 | 安装为 OpenClaw Skill |

## 关键约束

- 数据库名 `ry_vue`（下划线，不是横线 `ry-vue`）
- Checkbox 字段必须用 `varchar` 类型
- 日期格式用大写：`YYYY-MM-DD`（Day.js 格式）
- 字典 SQL 使用覆盖模式（先 DELETE 再 INSERT）
- BaseEntity 字段（create_by/create_time/update_by/update_time）不在 Entity 中生成
- TreeEntity 字段（parent_id/ancestors/order_num）不在 Entity 中生成
- 前端 Vue 模板中字段名使用 Java 驼峰格式（与 JSON 一致）

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| Unknown column | `./scripts/cleanup.sh 表名 true` 后重新部署 |
| 字典重复显示 | `deploy-only.sh` 默认覆盖模式，不会重复 |
| 创建时间为空 | `deploy-only.sh` 自动修复 |
| 前端 API 找不到 | 检查 `src/api/test/` 下有无 JS 文件 |
| 树表平铺展示 | 确认前端 handleTree 参数使用驼峰字段名 |
| 子表修改不回显 | 确认 XML 详情查询使用嵌套 resultMap |

## 详细文档

- `docs/COMPONENT_GUIDE.md` — 全部组件配置详解
- `docs/USAGE_GUIDE.md` — 常见问题 + 调试技巧
- `docs/WORKFLOW_GUIDE.md` — 一键/四步流程对比
