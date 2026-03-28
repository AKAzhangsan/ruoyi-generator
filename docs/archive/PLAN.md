# RuoYi Generator - 一体化模式实现方案
# 创建时间: 2025-03-19
# 状态: 进行中

## 📋 用户确认的需求

### 技术要求
1. **Java类型支持**: Long, String, Integer, Double, BigDecimal, Date, Boolean
2. **Boolean数据库类型**: tinyint(1)
3. **日期区分**: Date(yyyy-MM-dd) 和 DateTime(yyyy-MM-dd HH:mm:ss)
4. **字段配置项**: is_insert, is_edit, is_list, is_query, is_required
5. **查询方式**: EQ(=), NE(!=), GT(>), GE(>=), LT(<), LE(<=), LIKE, BETWEEN
6. **显示类型**: 文本框, 文本域, 下拉框, 单选框, 复选框, 日期控件, 图片上传, 文件上传, 富文本
7. **字典支持**: 查询现有字典(sys_dict_type/sys_dict_data)，没有则插入

### 开发节奏
按照三个阶段逐步实施，每阶段完成后测试验证。

---

## 🎯 MVP 1 - 基础功能

### 目标
实现基础组件和基础查询，支持核心配置项。

### 支持范围

#### Java类型
- ✅ Long (bigint)
- ✅ String (varchar/char/text)
- ✅ Integer (int)
- ✅ BigDecimal (decimal)
- ✅ Date (datetime/date)
- ⏳ Double (float/double) - MVP2
- ⏳ Boolean (tinyint(1)) - MVP2

#### 组件类型
- ✅ Input - 文本框
- ✅ Textarea - 文本域
- ✅ DatePicker - 日期控件（支持Date和DateTime）
- ⏳ InputNumber - 数字输入框 - MVP2
- ⏳ Select/Radio/Checkbox - 下拉/单选/多选 - MVP3
- ⏳ ImageUpload/FileUpload/Editor - 上传/富文本 - MVP3

#### 查询方式
- ✅ EQ (=) - 等于
- ✅ LIKE - 模糊查询
- ⏳ NE/GT/GE/LT/LE - 比较查询 - MVP2
- ⏳ BETWEEN - 范围查询 - MVP2

#### 字段配置
- ✅ is_insert - 是否插入
- ✅ is_edit - 是否编辑
- ✅ is_list - 是否列表显示
- ✅ is_query - 是否查询条件
- ✅ is_required - 是否必填

### 实现内容

1. **schema_parser.py 增强**
   - 添加 `generate_config()` 方法
   - 实现默认值推断规则

2. **配置文件格式**
   ```yaml
   table_name: product_info
   table_comment: 产品信息表
   module: product
   business: info
   function_name: 产品管理

   columns:
     - name: product_id
       comment: 产品ID
       type: bigint
       is_pk: true
       is_auto_increment: true
       is_insert: false
       is_edit: false
       is_list: true
       is_query: false
       is_required: false
       java_type: Long
       component: Input

     - name: product_name
       comment: 产品名称
       type: varchar
       length: 100
       is_insert: true
       is_edit: true
       is_list: true
       is_query: true
       is_required: true
       query_type: LIKE
       java_type: String
       component: Input

     - name: create_time
       comment: 创建时间
       type: datetime
       is_insert: false
       is_edit: false
       is_list: true
       is_query: true
       is_required: false
       query_type: BETWEEN
       java_type: Date
       component: DatePicker
       date_type: datetime  # date/datetime
   ```

3. **默认值推断规则**
   ```python
   DEFAULT_RULES = {
       'is_insert': True,
       'is_edit': lambda col: not col.is_pk,
       'is_list': lambda col: col.data_type not in ['text', 'longtext', 'blob'],
       'is_query': lambda col: col.data_type in ['varchar', 'char'],
       'is_required': lambda col: col.is_nullable == 'NO' and col.column_default is None,
       'query_type': lambda col: 'LIKE' if col.data_type in ['varchar', 'char'] else 'EQ',
       'component': {
           'varchar': 'Input',
           'char': 'Input',
           'text': 'Textarea',
           'longtext': 'Textarea',
           'int': 'Input',
           'bigint': 'Input',
           'decimal': 'Input',
           'datetime': 'DatePicker',
           'date': 'DatePicker',
       }
   }
   ```

4. **模板改造**
   - `index.vue.j2`: 根据 component 生成不同控件
   - `controller.java.j2`: 根据 query_type 生成查询条件
   - `mapper.xml.j2`: 动态 SQL

---

## 🎯 MVP 2 - 数字和范围查询

### 目标
添加数字类型支持和比较查询、范围查询。

### 支持范围

#### 新增Java类型
- ✅ Double (float/double)
- ✅ Boolean (tinyint(1))

#### 新增组件
- ✅ InputNumber - 数字输入框

#### 新增查询方式
- ✅ NE (!=)
- ✅ GT (>)
- ✅ GE (>=)
- ✅ LT (<)
- ✅ LE (<=)
- ✅ BETWEEN - 用于数字和日期范围

### 实现内容
1. 添加 InputNumber 组件支持
2. 实现范围查询表单（开始值-结束值）
3. 实现比较查询操作符
4. 添加 Double 和 Boolean 类型映射

---

## 🎯 MVP 3 - 选择和字典

### 目标
添加选择组件和完整字典支持。

### 支持范围

#### 新增组件
- ✅ Select - 下拉框
- ✅ Radio - 单选框
- ✅ Checkbox - 复选框
- ✅ ImageUpload - 图片上传
- ✅ FileUpload - 文件上传
- ✅ Editor - 富文本控件

#### 字典支持
- ✅ 查询现有字典 (sys_dict_type/sys_dict_data)
- ✅ 插入新字典到数据库
- ✅ 配置文件支持 dicts 定义

### 实现内容
1. 添加 Select/Radio/Checkbox 组件模板
2. 添加 ImageUpload/FileUpload/Editor 组件
3. 实现字典查询和插入逻辑
4. 生成字典 SQL 文件

---

## 📁 文件修改清单

### MVP 1 修改文件
- [ ] `generator/schema_parser.py` - 添加配置生成功能
- [ ] `generator/ruoyi_generator.py` - 支持从配置读取
- [ ] `templates/vue/index.vue.j2` - 组件类型支持
- [ ] `templates/java/controller.java.j2` - 查询方式支持
- [ ] `templates/xml/mapper.xml.j2` - 动态SQL支持
- [ ] `main_allinone.py` - 添加 --step=config 参数

### MVP 2 修改文件
- [ ] `generator/db_reader.py` - 添加 Double/Boolean 类型映射
- [ ] `templates/vue/index.vue.j2` - 添加 InputNumber/BETWEEN 支持
- [ ] `templates/java/controller.java.j2` - 添加比较查询

### MVP 3 修改文件
- [ ] `generator/schema_parser.py` - 添加字典配置
- [ ] `generator/ruoyi_generator.py` - 添加字典SQL生成
- [ ] `templates/vue/index.vue.j2` - 添加选择组件/上传组件
- [ ] `templates/sql/dict.sql.j2` - 新增字典SQL模板

---

## 🧪 测试计划

### MVP 1 测试用例
1. 创建 product_test 表 YAML
2. 生成配置文件，检查默认值
3. 修改部分字段配置
4. 生成代码，验证：
   - Input 组件是否正确
   - Textarea 是否正确
   - DatePicker 是否正确
   - LIKE 查询是否生效
   - EQ 查询是否生效
   - is_required 校验是否生效

### MVP 2 测试用例
1. 添加价格字段(decimal) - InputNumber + BETWEEN
2. 添加数量字段(int) - InputNumber
3. 添加状态字段(tinyint) - Boolean处理
4. 验证范围查询表单

### MVP 3 测试用例
1. 添加字典配置
2. 验证 Select 组件
3. 验证字典SQL生成
4. 验证图片上传组件

---

## 📝 当前状态

- [x] 需求确认
- [x] MVP 1 实现
- [x] MVP 1 测试（基础功能通过，日期格式已修复）
- [x] MVP 2 实现（数字类型、BETWEEN查询、InputNumber组件）
- [ ] MVP 2 测试
- [ ] MVP 3 实现
- [ ] MVP 3 测试

## 📝 优化建议记录

### 1. 字段类型与组件智能匹配
当前 `status` 字段（char(1)）默认生成 Input，应优化为：
- `type: char` + `comment: 状态` → 自动推断为 `Radio` 单选框
- 支持在配置文件中指定 `component: Radio` 覆盖默认

### 2. 组件测试清单
| 组件 | 状态 | 测试项 |
|------|------|--------|
| Input | ✅ MVP1 | 普通文本输入 |
| Textarea | ✅ MVP1 | 多行文本 |
| DatePicker | ✅ MVP1 | 日期/日期时间选择 |
| InputNumber | ⏳ MVP2 | 数字输入（整数/小数） |
| Select | ⏳ MVP3 | 下拉选择框 |
| Radio | ⏳ MVP3 | 单选框组（如状态字段） |
| Checkbox | ⏳ MVP3 | 多选框 |
| ImageUpload | ⏳ MVP3 | 图片上传 |
| FileUpload | ⏳ MVP3 | 文件上传 |
| Editor | ⏳ MVP3 | 富文本编辑器 |

### 3. 配置文件优化建议
```yaml
# 当前写法（需改进）
- name: status
  comment: 状态
  type: char
  length: 1
  component: Input  # 应该自动推断为 Radio

# 优化后写法
- name: status
  comment: 状态
  type: char
  length: 1
  component: Radio           # 显式指定组件
  dict_type: sys_status      # 关联字典
  # 或内联定义选项
  options:
    - label: 启用
      value: '0'
    - label: 禁用
      value: '1'
```

## 🔄 更新记录

- 2025-03-19: 创建方案文档，确认分三步实施
