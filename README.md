# RuoYi Python Code Generator
# 若依代码生成器 - Python 实现

从 YAML 定义表结构，一键生成若依 CRUD 代码（后端 + 前端 + SQL），100% 兼容若依原生代码结构。

## 支持的模板类型

| 类型 | 说明 | 状态 |
|------|------|------|
| **单表（crud）** | 基础增删改查 + 分页 | ✅ 已完成 |
| **树表（tree）** | 树形结构增删改查 | ✅ 已完成 |
| **主子表（sub）** | 主表+子表一对多 | 🚧 开发中 |

## 项目结构

```
ruoyi-generator/
├── main_allinone.py          # 核心生成器入口
├── README.md
├── requirements.txt
├── configs/
│   ├── ruoyi-generator.yaml  # 全局配置（数据库、路径等）
│   ├── schemas/              # 表结构定义（用户编写）
│   │   └── TEMPLATE.yaml     # ⭐ 单表配置模板
│   ├── generated/            # 生成的完整配置
│   └── dicts/                # 字典配置缓存
├── generator/                # 核心生成器模块
│   ├── schema_parser.py      # Schema 解析器
│   ├── ruoyi_generator.py    # 代码生成器
│   ├── xml_generator.py      # Mapper XML 生成器
│   ├── dict_manager.py       # 字典管理
│   ├── template_engine.py    # 模板引擎
│   ├── db_reader.py          # 数据库读写
│   └── deployer.py           # 部署器
├── templates/
│   ├── configs/
│   │   ├── schema-template.yaml       # 单表 Schema 模板
│   │   ├── schema-tree-template.yaml  # 树表 Schema 模板
│   │   ├── config-template.yaml       # Config 模板
│   │   └── global-template.yaml       # 全局配置模板
│   ├── java/                 # Java 代码模板（Jinja2）
│   ├── vue/
│   │   ├── index.vue.j2      # 单表前端模板
│   │   └── index-tree.vue.j2 # 树表前端模板
│   ├── xml/                  # Mapper XML 模板
│   └── sql/                  # SQL 模板
├── scripts/
│   ├── deploy-all.sh         # ⭐ 一键部署（全流程）
│   ├── deploy-only.sh        # ⭐ 只做部署（第4步）
│   ├── cleanup.sh            # 清理代码和数据库表
│   ├── check-dicts.sh        # 查看系统已有字典
│   ├── verify.sh             # 验证部署结果
│   └── install.sh            # 安装依赖
├── output/                   # 代码输出目录
└── docs/
    ├── COMPONENT_GUIDE.md    # 组件使用详解
    ├── USAGE_GUIDE.md        # 常见问题 + 调试技巧
    ├── WORKFLOW_GUIDE.md     # 工作流程对比
    └── archive/              # 历史文档归档
```

## 快速开始

### 单表（CRUD）

```bash
cd /path/to/ruoyi-generator

# 1. 复制模板
cp templates/configs/schema-template.yaml configs/schemas/my_table.yaml
# 编辑 my_table.yaml

# 2. 一键部署
./scripts/deploy-all.sh configs/schemas/my_table.yaml
```

### 树表（Tree）

```bash
# 1. 复制树表模板
cp templates/configs/schema-tree-template.yaml configs/schemas/my_tree.yaml
# 编辑 my_tree.yaml（必须包含 tpl_type: tree 和 tree_config）

# 2. 一键部署
./scripts/deploy-all.sh configs/schemas/my_tree.yaml
```

### 四步部署（灵活控制）

```bash
# 第1步: 清理（可选）
./scripts/cleanup.sh my_table_name true

# 第2步: 生成配置
python3 main_allinone.py --schema configs/schemas/my_table.yaml --step=config

# 第3步: 生成代码
python3 main_allinone.py --schema configs/generated/my_table_name-config.yaml --step=generate

# 第4步: 部署（建表+SQL+复制+编译+重启）
./scripts/deploy-only.sh my_table_name
```

## 单表 vs 树表差异

| 特性 | 单表（crud） | 树表（tree） |
|------|------------|------------|
| **Entity** | `extends BaseEntity` | `extends TreeEntity` |
| **列表** | 分页表格 | 树形表格（无分页） |
| **Controller** | `startPage()` + `TableDataInfo` | `AjaxResult`（不分页） |
| **前端特有** | 批量删除、分页 | 展开/折叠、新增子节点、树形父节点选择 |
| **必备字段** | 无 | `parent_id` + `ancestors` + `order_num` |
| **XML 排序** | 无 | `order by parent_id, order_num` |
| **Schema 配置** | 默认（无需指定 tpl_type） | `tpl_type: tree` + `tree_config` |

## 树表 Schema 配置说明

```yaml
table_name: my_category
table_comment: 分类管理
module: test
tpl_type: tree              # ← 关键：指定为树表

tree_config:                # ← 树表专用配置
  tree_code: id             # 节点ID字段
  tree_parent_code: parent_id  # 父节点字段
  tree_name: category_name  # 树节点显示名称字段

columns:
  # 树表必备字段（TreeEntity 基类自动处理）
  - name: parent_id         # 父节点ID
  - name: ancestors         # 祖级列表
  # 业务字段放在 order_num 前面（控制列表展示顺序：名称→排序→状态→时间）
  - name: category_name     # 树名称字段
  - name: order_num         # 显示排序
  - name: status
  - name: create_time
```

## 支持的组件

| 组件 | 配置 | 适用场景 |
|-----|------|---------|
| Input | `component: Input` | 短文本 |
| Textarea | `component: Textarea` | 长文本 |
| Radio | `component: Radio` + `dict_type` | 2-5个选项 |
| Select | `component: Select` + `dict_type` | 5个以上选项 |
| Checkbox | `component: Checkbox` + `dict_type` | 多选 |
| InputNumber | `component: InputNumber` | 数字 |
| DatePicker | `date_format: YYYY-MM-DD` | 日期 |
| DatePicker | `date_format: YYYY-MM-DD HH:mm:ss` | 日期时间 |
| ImageUpload | `component: ImageUpload` | 图片上传 |
| FileUpload | `component: FileUpload` | 文件上传 |
| Editor | `component: Editor` | 富文本 |

详细配置: [组件使用详解](docs/COMPONENT_GUIDE.md)

## 字典使用

### 系统字典（直接引用）

| 字典类型 | 说明 |
|---------|------|
| `sys_normal_disable` | 正常/停用 |
| `sys_yes_no` | 是/否 |
| `sys_user_sex` | 男/女/未知 |
| `sys_show_hide` | 显示/隐藏 |

```yaml
# 在 column 中直接引用，无需在 dicts 定义
- name: status
  component: Radio
  dict_type: sys_normal_disable
```

### 新业务字典

```yaml
dicts:
  - dict_type: sys_crm_category   # 建议加业务前缀
    dict_name: 客户分类
    data:
      - label: 企业客户
        value: enterprise
```

查看已有字典: `./scripts/check-dicts.sh`

## 脚本说明

| 脚本 | 用法 | 说明 |
|-----|------|------|
| `deploy-all.sh` | `<schema文件> [选项]` | 一键完成全部流程 |
| `deploy-only.sh` | `<表名>` | 只做部署步骤 |
| `cleanup.sh` | `<表名> true` | 清理代码和数据库表 |
| `check-dicts.sh` | `[关键词]` | 查看系统已有字典 |
| `verify.sh` | `<表名>` | 验证部署结果 |

## 常见问题

| 问题 | 解决方案 |
|-----|---------|
| Unknown column | 删表重建: `./scripts/cleanup.sh 表名 true` |
| 字典重复 | deploy-only.sh 默认覆盖模式 |
| 创建时间为空 | deploy-only.sh 自动修复 |
| 前端报 API 找不到 | 检查 `src/api/test/` 下有无 JS 文件 |

## 文档

- [组件使用详解](docs/COMPONENT_GUIDE.md)
- [使用指南](docs/USAGE_GUIDE.md)
- [工作流程](docs/WORKFLOW_GUIDE.md)
