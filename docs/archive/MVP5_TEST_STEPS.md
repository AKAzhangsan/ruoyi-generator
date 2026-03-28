# MVP5 完整分步测试流程

## 方式一：一键脚本（推荐）

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator
./mvp5-test-steps.sh
```

---

## 方式二：手动分步执行

### 步骤 0: 清理环境

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator
./scripts/cleanup.sh mvp5_full_validation true
```

### 步骤 1: 检查系统字典

```bash
./check-dicts.sh
```

💡 **常用系统字典**（可直接使用）：
- `sys_normal_disable` - 正常/停用
- `sys_yes_no` - 是/否
- `sys_user_sex` - 男/女/未知

### 步骤 2: 生成配置文件

```bash
python3 main_allinone.py \
  --schema configs/schemas/test-mvp5.yaml \
  --step=config
```

### 步骤 3: 生成代码

```bash
python3 main_allinone.py \
  --schema configs/generated/mvp5_full_validation-config.yaml \
  --step=generate
```

### 步骤 4: 创建数据库表

```bash
python3 main_allinone.py \
  --schema configs/schemas/test-mvp5.yaml \
  --step=create
```

### 步骤 5: 执行字典SQL

```bash
# 执行所有字典SQL文件
for sql_file in output/mvp5_full_validation/sql/dict_*.sql; do
    mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue < "$sql_file"
done
```

### 步骤 6: 执行菜单SQL

```bash
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue \
  < output/mvp5_full_validation/sql/mvp5_full_validation_menu.sql
```

### 步骤 7: 修改 create_time 默认值

```bash
mysql -hlocalhost -P3306 -uruoyi -p'ruoyi123' ry_vue -e "
ALTER TABLE mvp5_full_validation 
MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;
"
```

### 步骤 8: 验证部署

```bash
./verify-deployment.sh mvp5_full_validation
```

### 步骤 9: 编译后端

```bash
cd ../ruoyi/ruoyi-backend
mvn clean package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q
```

### 步骤 10: 重启服务

```bash
# 停止旧服务
pkill -f ruoyi-admin

# 启动新服务
cd ruoyi-admin/target
java -jar ruoyi-admin.jar
```

---

## 方式三：快速部署（迭代开发）

如果只是修改代码后快速测试：

```bash
cd /home/pei16/.openclaw/workspace/projects/ruoyi-generator

# 1. 快速部署（不重启）
./quick-deploy.sh configs/schemas/test-mvp5.yaml

# 2. 手动重启后端
cd ../ruoyi/ruoyi-backend/ruoyi-admin/target
pkill -f ruoyi-admin
java -jar ruoyi-admin.jar
```

---

## 测试验证清单

部署完成后，访问 http://localhost:3000 进行测试：

### 1. 新增测试
- [ ] 产品名称（Input）- 输入正常
- [ ] 状态（Radio）- 使用系统字典 `sys_normal_disable`
- [ ] 产品分类（Select）- 显示：电子产品、家居用品、服装配饰、食品饮料
- [ ] 产品标签（Checkbox）- 显示：新品、热销、促销、限量
- [ ] 产品等级（Checkbox）- 显示：一级、二级、三级
- [ ] 库存数量（InputNumber）- 整数输入
- [ ] 价格（InputNumber）- 小数输入
- [ ] 主图（ImageUpload）- 单图上传
- [ ] 图集（ImageUpload）- 多图上传
- [ ] 附件（FileUpload）- 文件上传
- [ ] 详情内容（Editor）- 富文本编辑
- [ ] 生产日期（DatePicker）- 纯日期选择
- [ ] 过期时间（DatePicker）- 日期时间选择

### 2. 列表显示测试
- [ ] 所有字段正确显示
- [ ] 创建时间自动填充（非空）
- [ ] 字典标签显示正确（无重复）
- [ ] 日期格式正确

### 3. 修改回显测试
- [ ] 点击修改按钮
- [ ] 所有字段正确回显
- [ ] Checkbox正确勾选
- [ ] 日期时间正确显示

---

## 问题排查

### 字典显示为空或重复

```bash
# 检查字典数据
mysql -uruoyi -p'ruoyi123' ry_vue -e "
SELECT dict_type, dict_label, dict_value 
FROM sys_dict_data 
WHERE dict_type LIKE 'sys_mvp5%'
ORDER BY dict_type, dict_sort;
"

# 如有重复，清理
mysql -uruoyi -p'ruoyi123' ry_vue -e "
DELETE d1 FROM sys_dict_data d1
INNER JOIN sys_dict_data d2 
WHERE d1.dict_code > d2.dict_code 
  AND d1.dict_type = d2.dict_type 
  AND d1.dict_label = d2.dict_label;
"

# 强制刷新浏览器: Ctrl + Shift + R
```

### 创建时间为空

```bash
# 检查并修复默认值
mysql -uruoyi -p'ruoyi123' ry_vue -e "
ALTER TABLE mvp5_full_validation 
MODIFY create_time DATETIME DEFAULT CURRENT_TIMESTAMP;
"
```

### 前端缓存问题

```bash
# 重启前端
cd ../ruoyi/ruoyi-frontend
pkill -f vite
npm run dev
```

---

## 总结

| 方式 | 适用场景 | 命令 |
|-----|---------|------|
| **一键脚本** | 完整部署测试 | `./mvp5-test-steps.sh` |
| **手动分步** | 学习/调试 | 按上面步骤执行 |
| **快速部署** | 迭代开发 | `./quick-deploy.sh configs/schemas/test-mvp5.yaml` |
