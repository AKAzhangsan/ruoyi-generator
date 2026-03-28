# MVP3 技术方案 - 字典、选择组件与上传

**状态: ✅ 已完成实施**

**最后更新: 2026-03-23**

## 功能实现清单

| 功能 | 状态 | 说明 |
|------|------|------|
| **字典配置生成** | ✅ | `--step=config` 生成 `configs/dicts/{dict_type}.yaml` |
| **字典状态检查** | ✅ | 自动检查新字典/已存在/有差异 |
| **字典 SQL 生成** | ✅ | 支持 skip/merge/replace 三种策略 |
| **交互式部署** | ✅ | 部署时预览 SQL 并选择执行策略 |
| **Select 组件** | ✅ | 查询/表单/表格 dict-tag 回显 |
| **Radio 组件** | ✅ | 表单单选、必填校验 |
| **Checkbox 组件** | ✅ | 多选、数据数组↔字符串转换、表格 dict-tag 回显 |
| **ImageUpload 组件** | ✅ | 单图/多图上传、limit/file_size 属性支持 |
| **FileUpload 组件** | ✅ | 文件上传、limit/file_size 属性支持 |
| **Editor 组件** | ✅ | 富文本编辑、height 属性支持 |
| **表格标签样式** | ✅ | list_class 支持 success/danger/warning/info/primary/default |

---

## 前置调研总结

通过查看若依原生代码，整理出以下关键实现细节：

---

## 实施文件清单

### 新建文件
| 文件路径 | 说明 |
|---------|------|
| `configs/dicts/.gitkeep` | 字典配置目录占位 |
| `generator/dict_manager.py` | 字典管理器（检查/生成/对比/SQL） |
| `templates/sql/dict.sql.j2` | 字典 SQL 模板 |
| `configs/schemas/test-mvp3.yaml` | MVP3 测试配置 |

### 修改文件
| 文件路径 | 修改内容 |
|---------|----------|
| `generator/schema_parser.py` | 新增 DictDataItem、Column 扩展属性、支持 dicts.data |
| `main_allinone.py` | 集成 DictManager，添加 dict_dir 配置，生成字典 SQL |
| `scripts/deploy.sh` | 交互式字典 SQL 执行 |
| `generator/ruoyi_generator.py` | _build_context_from_schema 扩展属性 |
| `templates/vue/index.vue.j2` | 扩展 Checkbox/ImageUpload/FileUpload/Editor 组件 |

---

## 1. 字典系统架构

### 1.1 数据库表结构

**sys_dict_type (字典类型表)**
```sql
CREATE TABLE `sys_dict_type` (
  `dict_id` bigint NOT NULL AUTO_INCREMENT COMMENT '字典主键',
  `dict_name` varchar(100) DEFAULT '' COMMENT '字典名称',
  `dict_type` varchar(100) DEFAULT '' COMMENT '字典类型（唯一）',
  `status` char(1) DEFAULT '0' COMMENT '状态（0正常 1停用）',
  `create_by`, `create_time`, `update_by`, `update_time`, `remark`
);
```

**sys_dict_data (字典数据表)**
```sql
CREATE TABLE `sys_dict_data` (
  `dict_code` bigint NOT NULL AUTO_INCREMENT COMMENT '字典编码',
  `dict_sort` int DEFAULT '0' COMMENT '字典排序',
  `dict_label` varchar(100) DEFAULT '' COMMENT '字典标签（显示文本）',
  `dict_value` varchar(100) DEFAULT '' COMMENT '字典键值（存储值）',
  `dict_type` varchar(100) DEFAULT '' COMMENT '字典类型',
  `css_class` varchar(100) DEFAULT NULL COMMENT '样式属性',
  `list_class` varchar(100) DEFAULT NULL COMMENT '表格回显样式（primary/success/warning/danger）',
  `is_default` char(1) DEFAULT 'N' COMMENT '是否默认（Y是 N否）',
  `status` char(1) DEFAULT '0' COMMENT '状态',
  `create_by`, `create_time`, `update_by`, `update_time`, `remark'
);
```

### 1.2 前端字典使用方式

**加载字典：**
```javascript
const { sys_normal_disable } = proxy.useDict("sys_normal_disable")
```

**查询表单中使用：**
```vue
<el-select v-model="queryParams.status" placeholder="状态" clearable>
  <el-option
    v-for="dict in sys_normal_disable"
    :key="dict.value"
    :label="dict.label"
    :value="dict.value"
  />
</el-select>
```

**表格回显使用：**
```vue
<el-table-column label="状态" align="center" prop="status">
  <template #default="scope">
    <dict-tag :options="sys_normal_disable" :value="scope.row.status" />
  </template>
</el-table-column>
```

**表单中使用 Radio：**
```vue
<el-form-item label="状态" prop="status">
  <el-radio-group v-model="form.status">
    <el-radio
      v-for="dict in sys_normal_disable"
      :key="dict.value"
      :label="dict.value"
    >{{ dict.label }}</el-radio>
  </el-radio-group>
</el-form-item>
```

---

## 2. 组件使用规范

### 2.1 Select 下拉框

| 场景 | 用法 |
|------|------|
| 查询表单 | `<el-select v-model="queryParams.xxx">` |
| 数据表单 | `<el-select v-model="form.xxx">` |
| 字典选项 | `v-for="dict in dict_type"` |
| 必填校验 | `:rules="{ required: true, message: '...', trigger: 'change' }"` |

### 2.2 Radio 单选框

| 属性 | 说明 |
|------|------|
| 布局 | `<el-radio-group>` 包裹 `<el-radio>` |
| 绑定值 | `:label="dict.value"`（注意不是 value） |
| 显示文本 | `{{ dict.label }}` |
| 必填触发 | `trigger: 'change'` |

### 2.3 Checkbox 多选框

| 属性 | 说明 |
|------|------|
| 绑定 | `v-model` 为数组类型 |
| 全选 | `:indeterminate` 半选状态 |
| 选项 | 同 Radio，使用 `v-for` |

**数据转换处理：**
```javascript
// 提交前：数组转逗号分隔字符串
if (form.tags && Array.isArray(form.tags)) {
  form.tags = form.tags.join(',')
}

// 回显时：字符串转数组
form.tags = row.tags ? row.tags.split(',') : []
```

### 2.4 ImageUpload 图片上传

**使用方式：**
```vue
<ImageUpload v-model="form.imageUrl" :limit="1" :fileSize="5" />
```

**Props：**
| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| limit | Number | 5 | 图片数量限制 |
| fileSize | Number | 5 | 大小限制(MB) |
| fileType | Array | ['png','jpg','jpeg'] | 文件类型 |
| disabled | Boolean | false | 禁用（仅查看） |
| drag | Boolean | true | 拖动排序 |

**数据格式：**
- 单图：字符串 `"http://.../xxx.jpg"`
- 多图：逗号分隔 `"url1,url2,url3"` 或数组

### 2.5 FileUpload 文件上传

**使用方式：**
```vue
<FileUpload v-model="form.fileUrl" :limit="3" :fileSize="10" />
```

**Props：**
| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| limit | Number | 5 | 文件数量限制 |
| fileSize | Number | 5 | 大小限制(MB) |
| fileType | Array | doc/docx/xls/xlsx/txt/pdf | 文件类型 |
| disabled | Boolean | false | 禁用 |

### 2.6 Editor 富文本编辑器

**使用方式：**
```vue
<Editor v-model="form.content" :height="300" />
```

**Props：**
| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| height | Number | null | 编辑器高度 |
| minHeight | Number | null | 最小高度 |
| readOnly | Boolean | false | 只读 |
| type | String | "url" | url/base64 |

---

## 3. 配置文件规范

### 3.1 字典定义

```yaml
table_name: mvp3_test
table_comment: MVP3字典组件测试表
module: test
business: mvp3_test
function_name: MVP3字典组件测试
sort: 4

# 字典定义（该表需要的字典）
dicts:
  - dict_type: sys_status
    dict_name: 系统状态
    sort: 1
    data:  # 可选：预定义字典数据
      - label: 启用
        value: '0'
        sort: 1
        is_default: Y
        list_class: success   # 表格标签样式：primary/success/warning/danger
      - label: 禁用
        value: '1'
        sort: 2
        list_class: danger
  - dict_type: sys_category
    dict_name: 分类
    sort: 2
    data:
      - label: 分类A
        value: 'A'
      - label: 分类B
        value: 'B'

columns:
  - name: id
    comment: 主键ID
    type: bigint
    is_pk: true
    is_auto_increment: true
    
  - name: status
    comment: 状态
    type: char
    length: 1
    component: Radio           # 单选框
    dict_type: sys_status      # 关联字典
    is_required: true
    
  - name: category
    comment: 分类
    type: varchar
    length: 50
    component: Select          # 下拉框
    dict_type: sys_category
    
  - name: tags
    comment: 标签（多选）
    type: varchar
    length: 100
    component: Checkbox        # 多选框
    dict_type: sys_tags
    
  - name: cover_image
    comment: 封面图
    type: varchar
    length: 200
    component: ImageUpload
    
  - name: attachment
    comment: 附件
    type: varchar
    length: 200
    component: FileUpload
    
  - name: content
    comment: 内容
    type: longtext
    component: Editor
```

### 3.2 字段属性扩展

新增/扩展的属性：

| 属性 | 类型 | 适用组件 | 说明 |
|------|------|----------|------|
| dict_type | string | Select/Radio/Checkbox | 关联字典类型 |
| limit | number | ImageUpload/FileUpload | 数量限制（默认：单图1，多图5） |
| file_size | number | ImageUpload/FileUpload | 大小限制(MB)（默认5MB） |
| file_type | array | ImageUpload/FileUpload | 文件类型（默认：图片png/jpg/jpeg，文件doc/xls/pdf等） |
| list_class | string | 字典数据项 | 表格回显样式：primary/success/warning/danger |

### 3.3 组件智能推断策略

**Radio vs Select 自动选择：**
```python
# 策略1：根据字典选项数量（推荐）
if dict_options_count <= 3:
    component = 'Radio'  # 选项少，用单选更直观
else:
    component = 'Select'  # 选项多，用下拉节省空间

# 策略2：用户显式指定优先
if column.component in ['Radio', 'Select']:
    use_user_specified  # 用户明确指定则优先
```

**字段长度对组件的影响：**
| 条件 | 影响 |
|------|------|
| length <= 50 | Input 正常显示 |
| 50 < length <= 200 | Input 加宽或改用 Textarea |
| length > 200 | 强制使用 Textarea |
| is_required = true | 添加必填校验规则 |

---

## 4. 生成代码结构

### 4.1 Vue 模板变更

**script setup 部分新增：**
```javascript
// 字典加载
{% for dict in dicts %}
const { {{ dict.dict_type }} } = proxy.useDict("{{ dict.dict_type }}")
{% endfor %}

// 上传组件处理
{% for column in upload_columns %}
// {{ column.comment }} 上传相关逻辑
{% endfor %}
```

**表单校验规则：**
```javascript
rules: {
{% for column in edit_columns %}
{% if column.is_required %}
  {{ column.java_field }}: [{ 
    required: true, 
    message: "{{ column.column_comment }}不能为空", 
    trigger: "{% if column.component in ['Select', 'Radio', 'Checkbox', 'DatePicker'] %}change{% else %}blur{% endif %}" 
  }],
{% endif %}
{% endfor %}
}
```

### 4.2 SQL 生成

新增字典 SQL 模板 `templates/sql/dict.sql.j2`：

```sql
-- 字典类型（使用 INSERT IGNORE 避免重复报错）
INSERT IGNORE INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark) 
VALUES ('{{ dict.dict_name }}', '{{ dict.dict_type }}', '0', 'admin', NOW(), '');

-- 字典数据（先删除旧数据再插入，确保幂等性）
DELETE FROM sys_dict_data WHERE dict_type = '{{ dict.dict_type }}';

{% for item in dict.data %}
INSERT INTO sys_dict_data (dict_label, dict_value, dict_type, dict_sort, is_default, status, create_by, create_time, list_class) 
VALUES ('{{ item.label }}', '{{ item.value }}', '{{ dict.dict_type }}', {{ item.sort | default(loop.index) }}, '{{ item.is_default | default('N') }}', '0', 'admin', NOW(), '{{ item.list_class | default('') }}');
{% endfor %}
```

**幂等性策略：**
1. `sys_dict_type` 使用 `INSERT IGNORE`（dict_type 有唯一约束）或 `ON DUPLICATE KEY UPDATE`
2. `sys_dict_data` 根据策略选择 `INSERT IGNORE` / `DELETE+INSERT` / `INSERT+ON DUPLICATE KEY UPDATE`

---

## 5. 实现步骤（已完成）

### ✅ Step 1: 新建字典配置目录
```bash
mkdir -p configs/dicts
```

### ✅ Step 2: 新建 DictManager 类
**文件:** `generator/dict_manager.py`

**核心方法:**
- `check_dict_exists(dict_type)` - 检查字典是否存在
- `compare_dict_data(dict_type, config_data)` - 对比配置与数据库
- `generate_dict_config(dict_data, source_table)` - 生成字典配置
- `save_dict_config(dict_config, output_dir)` - 保存到文件
- `generate_dict_sql(dict_config, strategy)` - 生成 SQL

### ✅ Step 3: 新增字典 SQL 模板
**文件:** `templates/sql/dict.sql.j2`

支持策略:
- `skip` - INSERT IGNORE（存在则跳过）
- `merge` - INSERT + ON DUPLICATE KEY UPDATE（合并）
- `replace` - DELETE + INSERT（完全替换）

### ✅ Step 4: SchemaParser 增强
**文件:** `generator/schema_parser.py`

修改内容:
1. 新增 `DictDataItem` dataclass
2. 更新 `DictItem` 支持 `data: List[DictDataItem]`
3. 更新 `_parse_table_data` 解析 `dicts.data`
4. 更新 `generate_config` 输出 dicts 配置
5. 新增 `generate_dict_configs` 方法

### ✅ Step 5: main_allinone.py 集成
**文件:** `main_allinone.py`

修改内容:
1. 导入 `DictManager`
2. 全局配置添加 `dict_dir`
3. `generate_config_from_schema` - 检查字典状态并生成配置
4. `generate_code_from_config` - 生成字典 SQL 文件
5. 新增 `generate_dict_sql_files` 函数

### ✅ Step 6: 部署脚本增强
**文件:** `scripts/deploy.sh`

修改内容:
- 添加交互式字典 SQL 执行
- 支持预览 SQL 内容
- 支持选择执行策略

---

## 6. 使用流程（更新）

### 步骤 1: 编写带字典的表结构定义

```yaml
# configs/schemas/test-mvp3.yaml
table_name: mvp3_test
table_comment: MVP3字典测试表
module: test
business: mvp3_test

dicts:
  - dict_type: sys_status
    dict_name: 系统状态
    data:
      - label: 启用
        value: '0'
        list_class: success
      - label: 禁用
        value: '1'
        list_class: danger

columns:
  - name: id
    type: bigint
    is_pk: true
    is_auto_increment: true
    
  - name: status
    comment: 状态
    type: char
    length: 1
    component: Radio
    dict_type: sys_status
    is_required: true
```

### 步骤 2: 生成配置（自动检查字典状态）

```bash
$ python3 main_allinone.py --schema configs/schemas/test-mvp3.yaml --step=config

📖 解析表结构定义: configs/schemas/test-mvp3.yaml
📚 发现 1 个字典配置:
   - sys_status: 新字典（数据库不存在）→ 将生成配置文件
💾 字典配置: configs/dicts/sys_status.yaml
✅ 字典配置已保存到: configs/dicts

✅ 配置文件已生成: configs/generated/mvp3_test-config.yaml
💡 请编辑配置文件，然后运行:
   python3 main_allinone.py --schema configs/generated/mvp3_test-config.yaml --step=generate
```

### 步骤 3: 生成代码（自动生成字典 SQL）

```bash
$ python3 main_allinone.py --schema configs/generated/mvp3_test-config.yaml --step=generate

📖 检查字典状态：
   - sys_status: 新字典 → 生成 SQL 文件（未执行）
   
📖 生成代码...
✅ 代码生成完成

📖 字典 SQL 文件位置：
   output/mvp3_test/sql/dict_sys_status.sql
   output/mvp3_test/sql/mvp3_test_menu.sql

💡 部署前请检查字典 SQL 文件，确认后执行部署
```

### 步骤 4: 部署（交互式执行字典 SQL）

```bash
$ ./scripts/deploy.sh mvp3_test true

🗄️  检查字典 SQL...
  发现 1 个字典 SQL 文件:

  📖 字典: sys_status
     文件: output/mvp3_test/sql/dict_sys_status.sql
     预览:
       -- 策略: merge
       INSERT INTO sys_dict_type...
       ...

  是否执行此字典 SQL? [y/N]: y
  执行策略 [merge(合并)/replace(替换)/skip(跳过)]: merge
     ✅ 字典 sys_status 执行完成 (merge)
```

---

## 7. 测试用例

### 6.1 基础功能测试
```yaml
# test-mvp3-basic.yaml
table_name: mvp3_basic
columns:
  - name: status
    component: Radio
    dict_type: sys_status
  - name: category
    component: Select
    dict_type: sys_category
```

### 6.2 上传组件测试
```yaml
# test-mvp3-upload.yaml
table_name: mvp3_upload
columns:
  - name: avatar
    component: ImageUpload
    limit: 1
    file_size: 2
  - name: photos
    component: ImageUpload
    limit: 9
  - name: documents
    component: FileUpload
    limit: 5
    file_size: 10
```

### 6.3 富文本测试
```yaml
# test-mvp3-editor.yaml
table_name: mvp3_editor
columns:
  - name: content
    component: Editor
    height: 400
```

---

## 7. 风险评估

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 字典已存在 | 插入失败 | 使用 `INSERT IGNORE` 或先查询 |
| 上传组件数据格式 | 存取不一致 | 统一使用逗号分隔字符串 |
| 多字典加载性能 | 页面卡顿 | `useDict` 内部有缓存 |
| Checkbox 数组存储 | 数据库兼容性 | varchar 存储 JSON 或逗号分隔 |
| 图片 URL 访问权限 | 图片无法显示 | 确保 URL 可公开访问或走认证接口 |
| 富文本 XSS 风险 | 安全漏洞 | 若依 Editor 组件已做基础过滤，后端如需二次校验需额外处理 |

---

## 8. 验收标准（更新）

### 8.1 字典功能验收
- [x] 字典配置生成：`--step=config` 时生成 `configs/dicts/{dict_type}.yaml`
- [x] 字典状态检查：正确识别新字典/已存在字典/有差异字典
- [x] 字典 SQL 生成：生成独立的 `dict_{type}.sql` 文件
- [x] 字典 SQL 幂等性：支持 skip/merge/replace 三种策略
- [x] 交互式部署：部署时预览 SQL 并选择执行策略
- [x] Select 组件：查询/表单/表格 dict-tag 回显正常
- [x] Radio 组件：表单选择正常，必填校验正常
- [x] Checkbox 组件：多选功能正常，数据数组↔字符串转换正常

### 8.2 上传组件验收
- [x] ImageUpload：单图/多图上传、limit/file_size 属性支持
- [x] FileUpload：文件上传、limit/file_size 属性支持

### 8.3 富文本验收
- [x] Editor：富文本编辑、height 属性支持

---

*MVP3 开发完成 - 2026-03-23*
