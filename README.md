# RuoYi Python Code Generator
# 若依代码生成器 - Python 实现

从 YAML 定义表结构，一键生成若依 CRUD 代码（后端 + 前端 + SQL），100% 兼容若依原生代码结构。

## 支持的模板类型

| 类型 | 说明 | 状态 |
|------|------|------|
| **单表（crud）** | 基础增删改查 + 分页 | ✅ 已完成 |
| **树表（tree）** | 树形结构增删改查 | ✅ 已完成 |
| **主子表（sub）** | 主表+子表一对多，子表行内编辑 | ✅ 已完成 |

## 项目结构

```
ruoyi-generator/
├── main_allinone.py          # 核心生成器入口
├── README.md
├── requirements.txt
├── configs/
│   ├── ruoyi-generator.yaml  # 全局配置（数据库、路径等）
│   ├── schemas/              # 表结构定义（用户编写）
│   │   ├── TEMPLATE.yaml         # 单表配置模板（符号链接）
│   │   ├── schema-template.yaml  # 单表模板
│   │   ├── schema-tree-template.yaml  # 树表模板
│   │   └── schema-sub-template.yaml   # 主子表模板
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
│   ├── configs/              # 配置模板
│   ├── java/                 # Java 代码模板（Jinja2）
│   │   └── sub-entity.java.j2    # 子表Entity模板
│   ├── vue/                  # 前端模板
│   │   ├── index.vue.j2          # 单表前端
│   │   ├── index-tree.vue.j2     # 树表前端
│   │   └── index-sub.vue.j2      # 主子表前端
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
# 编辑 my_table.yaml（必须包含 tpl_type: tree 和 tree_config）

# 2. 一键部署
./scripts/deploy-all.sh configs/schemas/my_tree.yaml
```

### 主子表（Sub）

```bash
# 1. 复制主子表模板
cp templates/configs/schema-sub-template.yaml configs/schemas/my_order.yaml
# 编辑配置：定义主表 + sub_table 子表

# 2. 一键部署
./scripts/deploy-all.sh configs/schemas/my_order.yaml
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

## 三种模板对比

| 特性 | 单表（crud） | 树表（tree） | 主子表（sub） |
|------|------------|------------|-------------|
| **Entity** | `extends BaseEntity` | `extends TreeEntity` | `extends BaseEntity` + `List<SubEntity>` |
| **列表** | 分页表格 | 树形表格（无分页） | 分页表格 |
| **Controller** | `startPage()` + `TableDataInfo` | `AjaxResult`（不分页） | `startPage()` + `TableDataInfo` |
| **前端特性** | 批量删除、分页 | 展开/折叠、新增子节点 | 主表单 + 子表行内编辑 |
| **必备字段** | 无 | `parent_id` + `ancestors` + `order_num` | 主表PK + 子表FK |
| **Schema 配置** | 默认 | `tpl_type: tree` + `tree_config` | `tpl_type: sub` + `sub_table` |
| **后端事务** | 无 | 无 | `@Transactional` 先删后插 |
| **级联删除** | 无 | 无 | ✅ 删除主表→自动删子表 |

## 主子表 Schema 配置

```yaml
table_name: test_order
table_comment: 订单管理
module: test
tpl_type: sub              # ← 关键：指定为主子表

dicts:
  - dict_type: sys_order_status
    dict_name: 订单状态
    data:
      - label: 待付款
        value: '0'
      - label: 已付款
        value: '1'

# 子表定义
sub_table:
  table_name: test_order_item
  table_comment: 订单明细
  fk_column: order_id        # 子表外键字段
  columns:
    - name: item_id
      type: bigint
      is_pk: true
      is_auto_increment: true
      
    - name: order_id         # 外键字段
      type: bigint
      
    - name: product_name     # Input
      type: varchar
      length: 200
      component: Input
      
    - name: item_type        # Select + 字典
      type: char
      length: 1
      component: Select
      dict_type: sys_item_type
      
    - name: quantity         # InputNumber
      type: int
      component: InputNumber
      
    - name: price            # InputNumber（小数）
      type: decimal
      precision: 10
      scale: 2
      component: InputNumber
      
    - name: delivery_date    # DatePicker
      type: date
      component: DatePicker
      date_format: YYYY-MM-DD

# 主表字段（可选）
columns:
  - name: order_no
  - name: customer_name
  - name: status
    component: Radio
    dict_type: sys_order_status
```

### 子表支持的组件

| 组件 | 状态 | 说明 |
|------|------|------|
| Input | ✅ | 文本输入，自适应宽度 |
| InputNumber | ✅ | 数字输入，自适应宽度 |
| Select | ✅ | 字典下拉，自适应宽度 |
| Radio | ✅ | 转为 Select 处理 |
| DatePicker | ✅ | 日期选择，自适应宽度 |
| Textarea | ❌ | 行内空间不足 |
| Editor | ❌ | 行内不可用 |
| ImageUpload | ❌ | 太复杂 |
| FileUpload | ❌ | 太复杂 |
| Checkbox | ❌ | 行内不实用 |

## 树表 Schema 配置

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
  - name: parent_id
  - name: ancestors
  # 业务字段放在 order_num 前面（控制列表展示顺序：名称→排序→状态→时间）
  - name: category_name
  - name: order_num
  - name: status
  - name: create_time
```

## 支持的组件（单表/树表/主表）

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
| `deploy-only.sh` | `<表名>` | 只做部署步骤（建表+SQL+复制+编译+重启） |
| `cleanup.sh` | `<表名> true` | 清理代码和数据库表 |
| `check-dicts.sh` | `[关键词]` | 查看系统已有字典 |
| `verify.sh` | `<表名>` | 验证部署结果 |

### deploy-all.sh 参数

```bash
./scripts/deploy-all.sh configs/schemas/my_table.yaml [选项]

选项:
  --skip-cleanup       # 跳过清理
  --skip-restart       # 跳过重启后端
  --dict-strategy=merge  # 字典合并模式（默认覆盖）
```

## 关键约束

| 约束 | 说明 |
|------|------|
| 数据库名 | `ry_vue`（下划线，不是横线 `ry-vue`） |
| 日期格式 | `YYYY-MM-DD`（Day.js大写格式） |
| Checkbox类型 | 必须用 `varchar` 类型 |
| BaseEntity字段 | create_by/create_time/update_by/update_time 不在 Entity 生成 |
| TreeEntity字段 | parent_id/ancestors/order_num 不在 Entity 生成 |
| 前端字段名 | 使用 Java 驼峰格式（parentId 而非 parent_id） |
| 字典SQL模式 | 覆盖模式（先 DELETE 后 INSERT） |

## 常见问题

| 问题 | 解决方案 |
|-----|---------|
| Unknown column | 删表重建: `./scripts/cleanup.sh 表名 true` |
| 字典重复 | deploy-only.sh 默认覆盖模式 |
| 创建时间为空 | deploy-only.sh 自动修复 |
| 前端报 API 找不到 | 检查 `src/api/test/` 下有无 JS 文件 |
| 树表平铺展示 | 确认前端 handleTree 参数使用驼峰字段名 |
| 子表修改不回显 | 确认 XML 详情查询使用带 collection 的 resultMap |
| 子表组件被遮挡 | 对话框已加宽到 960px，组件自适应列宽 |

## 文档

- [组件使用详解](docs/COMPONENT_GUIDE.md) - 全部11种组件配置
- [使用指南](docs/USAGE_GUIDE.md) - 常见问题 + 调试技巧
- [工作流程](docs/WORKFLOW_GUIDE.md) - 一键/四步流程对比

## 版本历史

- **v1.0.0** (2026-03-28) - 三大模板类型完成：单表、树表、主子表
- **v0.2.0** (2026-03-27) - 树表支持
- **v0.1.0** (2026-03-19) - 单表CRUD + 11种组件
