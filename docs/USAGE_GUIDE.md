# 使用指南 - 常见问题 & 调试技巧

## 常见问题

### Q1: Unknown column 'xxx' in 'field list'

**原因**: 数据库表结构和代码字段不一致（修改了 YAML 但没重建表）

**解决**:
```bash
# 清理并重新部署
./scripts/cleanup.sh your_table true
./scripts/deploy-all.sh configs/schemas/your_table.yaml
```

### Q2: Checkbox 数据无法保存或回显

**原因**: 数据库字段类型不是 varchar

**解决**: 确保 YAML 中 Checkbox 字段配置：
```yaml
- name: tags
  type: varchar        # 必须是 varchar
  length: 200          # 长度足够存储多个值
  component: Checkbox
  dict_type: sys_your_tags
```

存储格式为逗号分隔字符串：`"hot,recommend,new"`

### Q3: 日期时间显示为 00:00:00

**原因**: `date_format` 配置不匹配

**解决**: 
```yaml
# 纯日期
date_format: YYYY-MM-DD

# 日期+时间（注意 HH 大写）
date_format: YYYY-MM-DD HH:mm:ss
```

### Q4: 创建时间为空

**原因**: 若依没有自动填充机制

**解决**: `deploy-only.sh` 已自动执行：
```sql
ALTER TABLE your_table MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;
```

### Q5: 前端报 Failed to resolve import

**原因**: API JS 文件没复制到前端项目

**解决**: 检查文件是否存在：
```bash
ls ruoyi-frontend/src/api/test/your_table.js
```
使用 `deploy-only.sh` 会自动复制 API 文件。

### Q6: 字典显示为数字而非文本

**原因**: 字典数据未执行或被缓存

**解决**:
```bash
# 检查字典是否在数据库中
./scripts/check-dicts.sh your_dict_type

# 重新执行字典SQL（覆盖模式）
./scripts/deploy-only.sh your_table

# 前端清缓存：Ctrl+Shift+R 或重新登录
```

### Q7: 修改时数据不回显

**排查步骤**:
1. F12 → Network → 查看 GET 请求返回的 JSON 字段名
2. 检查 Vue 文件中 `form.xxx` 绑定是否正确
3. 日期类型检查 `value-format` 配置

### Q8: 字典重复显示

**原因**: 多次执行字典SQL导致数据重复

**解决**: `deploy-only.sh` 默认使用覆盖模式（先 DELETE 再 INSERT），不会产生重复。

---

## 调试技巧

### 查看生成的代码
```bash
# 查看输出目录
ls output/your_table/

# 查看 Vue 文件
cat output/your_table/vue/views/test/your_table/index.vue

# 查看 Mapper XML
cat output/your_table/main/resources/mapper/test/YourTableMapper.xml

# 查看 Entity
cat output/your_table/main/java/com/ruoyi/test/domain/YourTable.java
```

### 查看数据库
```bash
# 表结构
mysql -hlocalhost -uruoyi -p'ruoyi123' ry_vue -e "DESCRIBE your_table;"

# 字典数据
mysql -hlocalhost -uruoyi -p'ruoyi123' ry_vue -e \
  "SELECT dict_type, dict_label, dict_value FROM sys_dict_data WHERE dict_type LIKE '%your%';"
```

### 查看后端日志
```bash
tail -f /tmp/ruoyi.log
```

### 前端调试
- F12 → Network → 查看 API 请求和响应
- F12 → Console → 查看 JS 错误
- Ctrl+Shift+R → 强制刷新（清除缓存）

---

## 最佳实践

### 表设计
- 主键统一用 `id` (bigint, auto_increment)
- 必备系统字段: `create_by`, `create_time`, `update_by`, `update_time`
- 业务表不默认加 `remark`（需要时在 YAML 中显式定义）

### 字段命名
- 数据库: `user_name`, `order_id`（下划线）
- 自动转驼峰: `userName`, `orderId`

### 字典命名
- 加业务前缀: `sys_crm_status` 而非 `sys_status`
- 值用字符串: `'0'`, `'1'` 而非 `0`, `1`
- 先查系统字典: `./scripts/check-dicts.sh`
