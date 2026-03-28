# MVP4 测试问题记录与解决方案

## 问题清单

### 1. 字典重复问题

**现象**："是否紧急"字段显示"是是否否"（重复选项）

**原因**：使用了系统已存在的字典名 `sys_yes_no`，与若依自带的字典冲突
- 若依自带：`sys_yes_no` (值: Y/N)
- MVP4定义：`sys_yes_no` (值: 1/0)
- 结果：数据库中有两组数据，导致显示重复

**解决方案**：
```yaml
# 错误 ❌
dict_type: sys_yes_no  # 与系统自带字典冲突

# 正确 ✅
dict_type: sys_mvp4_yes_no  # 使用唯一名称
```

**最佳实践**：
- 自定义字典使用项目前缀，如 `sys_mvp4_xxx`
- 避免使用若依系统自带字典名（sys_yes_no, sys_normal_disable等）

---

### 2. JSON解析错误

**现象**：新增时报错 `Cannot deserialize value of type java.lang.Integer from String "Y"`

**原因**：Java类型与字典值类型不匹配
- Entity字段：`private Integer isUrgent;`
- 字典值：字符串 `"1"` / `"0"`
- Jackson反序列化时无法将字符串转为Integer

**解决方案**：
```yaml
# 错误 ❌
java_type: Integer

# 正确 ✅
java_type: String
```

**最佳实践**：
- 使用字典的字段统一使用 `java_type: String`
- 字典值统一用字符串格式：`value: '1'` 而非 `value: 1`

---

### 3. Mapper XML 缺少字段

**现象**：备注、结束时间等字段保存后查询为空

**原因**：代码生成器未正确将 `remark` 等BaseEntity字段生成到 insert/update SQL中

**解决方案**：
手动修复 `Mvp4FullComponentsMapper.xml`：
```xml
<!-- insert中添加 -->
<if test="remark != null">remark,</if>
<if test="remark != null">#{remark},</if>

<!-- update中添加 -->
<if test="remark != null">remark = #{remark},</if>
```

**代码生成器修复**：
修改 `generator/ruoyi_generator.py`：
1. 添加 `java_type` 到 Column dataclass
2. 在 `_parse_table_data` 中解析 `java_type`
3. 在 `generate_config` 中正确识别配置的 `java_type`
4. 在 `_build_context_from_schema` 中添加 BaseEntity 字段到 insert_columns

---

### 4. 服务启动问题

**现象**：每次访问都报错，服务不稳定

**原因**：使用简单的 `java -jar &` 启动，进程容易退出

**正确方式**：
```bash
# 使用若依提供的脚本
cd /home/pei16/.openclaw/workspace/projects/ruoyi
./start.sh

# 或手动使用 nohup + PID管理
cd /home/pei16/.openclaw/workspace/projects/ruoyi/ruoyi-backend
nohup java -jar ruoyi-admin/target/ruoyi-admin.jar > ../backend.log 2>&1 &
echo $! > ../backend.pid
```

**最佳实践**：
- 总是使用 `./start.sh` 启动项目
- 部署脚本应该调用 `stop.sh` + `start.sh` 而不是直接运行jar

---

## 分步测试流程

当测试新功能或排查问题时，使用以下步骤：

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

# 1. 清理旧数据（删除代码、数据库表、菜单、字典）
./scripts/cleanup.sh mvp4_full_components true

# 2. 生成配置文件（检查字典状态）
python3 main_allinone.py --schema configs/schemas/test-mvp4.yaml --step=config

# 3. 生成代码
python3 main_allinone.py --schema configs/generated/mvp4_full_components-config.yaml --step=generate

# 4. 部署（包含建表+编译+重启）
./scripts/deploy.sh mvp4_full_components true
```

**关键检查点**：
1. 检查生成的配置文件中的 `java_type` 是否正确
2. 检查生成的 Mapper XML 是否包含所有字段
3. 确保服务使用正确方式启动

---

## 配置示例

### 正确的字典字段配置

```yaml
- name: is_urgent
  comment: 是否紧急
  type: tinyint
  length: 1
  default: '0'
  is_insert: true
  is_edit: true
  is_list: true
  is_query: true
  is_required: false
  query_type: EQ
  java_type: String        # ✅ 使用String类型
  component: Radio
  dict_type: sys_mvp4_yes_no  # ✅ 使用唯一字典名

dicts:
  - dict_type: sys_mvp4_yes_no  # ✅ 唯一名称
    dict_name: MVP4是否
    sort: 5
    data:
      - label: 是
        value: '1'          # ✅ 字符串值
        sort: 1
      - label: 否
        value: '0'          # ✅ 字符串值
        sort: 2
```

---

## 代码生成器改进建议

### 已完成修复

1. ✅ `generator/schema_parser.py` - Column dataclass 添加 `java_type` 字段
2. ✅ `generator/schema_parser.py` - `_parse_table_data` 解析 `java_type`
3. ✅ `generator/schema_parser.py` - `generate_config` 正确识别 `java_type`
4. ✅ `generator/ruoyi_generator.py` - `_build_context_from_schema` 添加 BaseEntity 字段
5. ✅ `scripts/deploy.sh` - 改进服务启动方式

### 仍存在的问题

1. ⚠️ Mapper XML 模板中 BaseEntity 字段（remark）可能未正确生成
2. ⚠️ deploy.sh 的建表逻辑在某些情况下找不到 schema 文件

**临时解决方案**：
- 部署后手动检查 Mapper XML，确认 remark 字段存在
- 如缺少，手动添加或重新运行建表步骤

---

## 测试检查清单

部署完成后，验证以下功能：

- [ ] 字典下拉正常显示（无重复选项）
- [ ] 新增数据成功（无JSON解析错误）
- [ ] 修改时数据回显正常
- [ ] 备注字段保存和回显正常
- [ ] 时间字段保存和回显正常
- [ ] 列表查询正常

---

*记录时间: 2026-03-25*
*相关文件: test-mvp4.yaml, Mvp4FullComponentsMapper.xml*
