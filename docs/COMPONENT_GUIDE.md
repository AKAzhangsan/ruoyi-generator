# 组件使用详解 & 字典选择指南

## 📋 使用流程

### 第一步：检查系统已有字典（重要！）

在创建新字典前，先检查系统是否已有可用字典：

```bash
# 查看系统现有字典
./scripts/check-dicts.sh

# 或搜索特定字典
./scripts/check-dicts.sh status
```

**常用系统字典**（可直接使用，**无需在YAML中定义**）：

| 字典类型 | 说明 | 可选值 |
|---------|------|--------|
| `sys_normal_disable` | 正常/停用 | 正常、停用 |
| `sys_show_hide` | 显示/隐藏 | 显示、隐藏 |
| `sys_yes_no` | 是/否 | 是、否 |
| `sys_user_sex` | 性别 | 男、女、未知 |
| `sys_notice_type` | 通知类型 | 通知、公告 |
| `sys_notice_status` | 通知状态 | 正常、关闭 |
| `sys_oper_type` | 操作类型 | 新增、修改、删除、查询... |
| `sys_common_status` | 通用状态 | 成功、失败 |

**判断标准**：
- ✅ **含义匹配** → **直接使用系统字典**（只需在column中引用，无需在dicts中定义）
- ❌ **含义不匹配** → **创建新业务字典**（在dicts中定义，建议加前缀如`sys_crm_`）

### 系统字典使用示例

**状态字段使用系统字典**：
```yaml
columns:
  - name: status
    comment: 状态
    type: char
    length: 1
    component: Radio
    dict_type: sys_normal_disable   # ✅ 直接使用系统字典

# 注意：不需要在 dicts 部分定义！
```

**新业务字典需要定义**：
```yaml
columns:
  - name: category
    comment: 分类
    type: varchar
    length: 20
    component: Select
    dict_type: sys_crm_category     # 新业务字典

# 需要在 dicts 部分定义
dicts:
  - dict_type: sys_crm_category
    dict_name: 客户分类
    data:
      - label: 企业客户
        value: enterprise
      - label: 个人客户
        value: personal
```

---

## 🧩 组件详解

### 1. Input 文本输入

**适用场景**：短文本输入，如名称、标题、编码等

**配置示例**：
```yaml
- name: customer_name
  comment: 客户名称
  type: varchar
  length: 100
  is_required: true          # 必填
  query_type: LIKE           # 查询方式：模糊查询
  java_type: String
  component: Input
```

**变体 - 文本域**：
```yaml
- name: address
  comment: 地址
  type: text                 # text/longtext 自动识别为Textarea
  component: Textarea
```

---

### 2. Radio 单选按钮

**适用场景**：选项较少（2-5个），需要一目了然，如状态、是否

**配置示例**：
```yaml
- name: status
  comment: 状态
  type: char
  length: 1
  is_required: true
  java_type: String
  component: Radio
  dict_type: sys_your_status  # 关联字典
```

**对应字典**：
```yaml
dicts:
  - dict_type: sys_your_status    # 建议使用前缀 sys_模块名_
    dict_name: 业务状态
    data:
      - label: 启用
        value: '0'
        list_class: success      # 绿色标签
      - label: 禁用
        value: '1'
        list_class: danger       # 红色标签
```

**可用系统字典**：
- `sys_normal_disable` - 正常/停用
- `sys_yes_no` - 是/否

---

### 3. Select 下拉选择

**适用场景**：选项较多（5个以上），或需要节省空间

**配置示例**：
```yaml
- name: category
  comment: 分类
  type: varchar
  length: 20
  is_required: true
  java_type: String
  component: Select
  dict_type: sys_your_category
```

**与Radio的区别**：
| 组件 | 选项数量 | 适用场景 |
|-----|---------|---------|
| Radio | 2-5个 | 需要一眼看到所有选项 |
| Select | 5个以上 | 选项多，节省空间 |

---

### 4. Checkbox 多选框

**适用场景**：多选场景，如标签、权限、特性

**配置示例**：
```yaml
- name: tags
  comment: 标签
  type: varchar
  length: 200     # 存储多个值，长度要足够
  java_type: String
  component: Checkbox
  dict_type: sys_your_tags
```

**⚠️ 重要**：
- 数据库字段必须是 `varchar` 类型
- 存储格式：`"value1,value2,value3"`
- 代码生成器会自动处理数组↔字符串转换

**对应字典**：
```yaml
dicts:
  - dict_type: sys_your_tags
    dict_name: 业务标签
    data:
      - label: 重要
        value: important
        list_class: danger
      - label: 紧急
        value: urgent
        list_class: warning
      - label: 普通
        value: normal
        list_class: info
```

---

### 5. InputNumber 数字输入

**适用场景**：整数或小数输入

**整数配置**：
```yaml
- name: priority
  comment: 优先级
  type: int
  is_required: true
  query_type: BETWEEN     # 范围查询
  java_type: Integer
  component: InputNumber
```

**小数配置**：
```yaml
- name: price
  comment: 价格
  type: decimal
  precision: 10           # 总位数
  scale: 2                # 小数位
  query_type: BETWEEN
  java_type: BigDecimal
  component: InputNumber
```

---

### 6. DatePicker 日期选择

**仅日期**（不含时间）：
```yaml
- name: start_date
  comment: 开始日期
  type: date
  is_required: true
  query_type: BETWEEN     # 日期范围查询
  java_type: Date
  component: DatePicker
  date_format: YYYY-MM-DD
```

**日期时间**（含时分秒）：
```yaml
- name: deadline
  comment: 截止时间
  type: datetime
  query_type: BETWEEN
  java_type: Date
  component: DatePicker
  date_format: YYYY-MM-DD HH:mm:ss   # ⚠️ HH必须大写
```

**⚠️ 注意事项**：
- 日期格式必须严格匹配
- `YYYY-MM-DD` = 纯日期
- `YYYY-MM-DD HH:mm:ss` = 日期时间

---

### 7. ImageUpload 图片上传

**单图上传**：
```yaml
- name: cover_image
  comment: 封面图
  type: varchar
  length: 500
  java_type: String
  component: ImageUpload
  limit: 1          # 1 = 单图
  file_size: 5      # MB
```

**多图上传**：
```yaml
- name: gallery
  comment: 图集
  type: varchar
  length: 2000      # 多图URL更长
  java_type: String
  component: ImageUpload
  limit: 9          # 最多9张
  file_size: 5
```

---

### 8. FileUpload 文件上传

**配置示例**：
```yaml
- name: attachment
  comment: 附件
  type: varchar
  length: 500
  java_type: String
  component: FileUpload
  limit: 3          # 最多3个文件
  file_size: 10     # 单个文件10MB
```

---

### 9. Editor 富文本编辑器

**适用场景**：长文本、带格式的内容，如文章、详情

**配置示例**：
```yaml
- name: content
  comment: 内容详情
  type: longtext
  java_type: String
  component: Editor
  height: 300       # 编辑器高度(px)
```

---

## 📖 完整示例

### 客户管理表

```yaml
table_name: crm_customer
table_comment: 客户信息表
module: crm
business: customer
function_name: 客户管理
sort: 1

# 字典定义（先检查系统是否有可用字典）
dicts:
  # 业务专用字典（系统没有的才创建）
  - dict_type: sys_crm_customer_type
    dict_name: 客户类型
    data:
      - label: 企业客户
        value: enterprise
      - label: 个人客户
        value: personal
      - label: 政府客户
        value: government

columns:
  # 主键
  - name: id
    comment: 客户ID
    type: bigint
    is_pk: true
    is_auto_increment: true
    is_insert: false
    is_edit: false
    is_list: false
    is_query: false
    java_type: Long
    component: Input

  # Input - 客户名称
  - name: customer_name
    comment: 客户名称
    type: varchar
    length: 100
    is_required: true
    query_type: LIKE
    java_type: String
    component: Input

  # Select - 客户类型（使用新业务字典）
  - name: customer_type
    comment: 客户类型
    type: varchar
    length: 20
    is_required: true
    java_type: String
    component: Select
    dict_type: sys_crm_customer_type

  # Radio - 客户状态（使用系统字典）
  - name: status
    comment: 客户状态
    type: char
    length: 1
    is_required: true
    java_type: String
    component: Radio
    dict_type: sys_normal_disable    # ✅ 使用系统字典

  # InputNumber - 年度合同额
  - name: annual_amount
    comment: 年度合同额
    type: decimal
    precision: 15
    scale: 2
    query_type: BETWEEN
    java_type: BigDecimal
    component: InputNumber

  # DatePicker - 签约日期
  - name: sign_date
    comment: 签约日期
    type: date
    is_required: true
    query_type: BETWEEN
    java_type: Date
    component: DatePicker
    date_format: YYYY-MM-DD

  # ImageUpload - 客户logo
  - name: logo
    comment: 客户Logo
    type: varchar
    length: 500
    java_type: String
    component: ImageUpload
    limit: 1
    file_size: 2

  # Editor - 客户简介
  - name: introduction
    comment: 客户简介
    type: longtext
    java_type: String
    component: Editor
    height: 300

  # Textarea - 备注
  - name: remark
    comment: 备注
    type: text
    java_type: String
    component: Textarea

  # 创建时间（系统字段）
  - name: create_time
    comment: 创建时间
    type: datetime
    is_insert: false
    is_edit: false
    is_list: true
    is_query: true
    query_type: BETWEEN
    java_type: Date
    component: DatePicker
    date_format: YYYY-MM-DD HH:mm:ss
```

---

## ✅ 配置检查清单

创建新表前，逐项检查：

### 字典检查
- [ ] 先查询系统现有字典 `SELECT * FROM sys_dict_type;`
- [ ] 含义匹配的优先使用系统字典
- [ ] 新业务字典使用前缀（如 `sys_crm_`, `sys_模块名_`）
- [ ] 字典值使用字符串（`'0'`, `'1'` 而非 `0`, `1`）

### 字段检查
- [ ] 主键 `id` 已定义
- [ ] `create_time` 已定义（用于列表显示和查询）
- [ ] 数据库类型与组件匹配
- [ ] Checkbox字段用 `varchar`，长度足够
- [ ] 日期格式正确（`YYYY-MM-DD` 或 `YYYY-MM-DD HH:mm:ss`）

### 命名规范
- [ ] 表名使用下划线：`crm_customer`
- [ ] 字典类型使用前缀：`sys_crm_customer_type`
- [ ] 注释清晰完整

---

## 🚀 部署命令

```bash
# 方式一：一键部署
./scripts/deploy-all.sh configs/schemas/crm_customer.yaml

# 方式二：四步部署
./scripts/cleanup.sh crm_customer true
python3 main_allinone.py --schema configs/schemas/crm_customer.yaml --step=config
python3 main_allinone.py --schema configs/generated/crm_customer-config.yaml --step=generate
./scripts/deploy-only.sh crm_customer
```
