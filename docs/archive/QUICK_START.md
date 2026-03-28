# 🎉 代码生成器使用总结

## 📦 已交付的工具和文档

### 核心脚本
| 脚本 | 功能 | 使用示例 |
|-----|------|---------|
| `quick-deploy.sh` | 一键部署 | `./quick-deploy.sh configs/schemas/my_table.yaml` |
| `check-dicts.sh` | 查看系统字典 | `./check-dicts.sh` 或 `./check-dicts.sh status` |

### 文档
| 文档 | 内容 | 重要性 |
|-----|------|--------|
| `docs/COMPONENT_GUIDE.md` | 9种组件详细用法 + 字典选择指南 | ⭐⭐⭐ 必读 |
| `docs/USAGE_GUIDE.md` | 常见问题 + 调试技巧 | ⭐⭐ 推荐 |
| `docs/MVP4_SUMMARY.md` | 问题记录和优化经验 | ⭐ 参考 |
| `configs/schemas/TEMPLATE.yaml` | 可直接复制的完整配置模板 | ⭐⭐⭐ 必读 |

---

## 🚀 标准工作流程

### Step 1: 检查系统字典（重要！）

在创建新字典前，先查看系统已有哪些字典：

```bash
# 查看所有系统字典
./check-dicts.sh

# 搜索包含 "status" 的字典
./check-dicts.sh status
```

**常用系统字典**（可直接使用）：
- `sys_normal_disable` - 正常/停用
- `sys_yes_no` - 是/否
- `sys_user_sex` - 男/女/未知
- `sys_show_hide` - 显示/隐藏

**原则**：含义匹配的优先用系统字典，不匹配才新建（加前缀如 `sys_crm_`）

---

### Step 2: 选择组件类型

根据场景选择组件：

| 场景 | 推荐组件 | 示例 |
|-----|---------|------|
| 短文本输入 | Input | 名称、标题 |
| 长文本/地址 | Textarea | 地址、描述 |
| 2-5个选项 | Radio | 状态、是否 |
| 5个以上选项 | Select | 分类、类型 |
| 多选 | Checkbox | 标签、特性 |
| 整数/小数 | InputNumber | 数量、金额 |
| 纯日期 | DatePicker | 出生日期、签约日 |
| 日期时间 | DatePicker | 截止时间、创建时间 |
| 单图 | ImageUpload | 头像、封面 |
| 多图 | ImageUpload | 图集、相册 |
| 文件 | FileUpload | 附件、文档 |
| 富文本 | Editor | 文章内容 |

详细配置查看：[组件使用详解](docs/COMPONENT_GUIDE.md)

---

### Step 3: 编写YAML配置

```bash
# 复制模板
cp configs/schemas/TEMPLATE.yaml configs/schemas/my_table.yaml

# 编辑配置
vim configs/schemas/my_table.yaml
```

**关键注意点**：
1. ✅ 先检查系统字典，避免重复创建
2. ✅ 日期格式严格匹配：`YYYY-MM-DD` 或 `YYYY-MM-DD HH:mm:ss`
3. ✅ Checkbox字段用 `varchar`，长度要足够
4. ✅ 字典类型加前缀，避免冲突

---

### Step 4: 部署

```bash
# 方式1: 一键部署（推荐）
./quick-deploy.sh configs/schemas/my_table.yaml

# 方式2: 分步执行
python3 main_allinone.py --schema configs/schemas/my_table.yaml --step=config
python3 main_allinone.py --schema configs/generated/my_table-config.yaml --step=generate
./scripts/deploy.sh my_table true
```

---

### Step 5: 重启测试

```bash
# 编译后端
cd ../ruoyi/ruoyi-backend
mvn package -DskipTests -pl ruoyi-system,ruoyi-admin -am -q

# 重启后端
pkill -f ruoyi-admin
cd ruoyi-admin/target
java -jar ruoyi-admin.jar
```

---

## ⚠️ 常见错误预防

### 错误1: Unknown column 'xxx'
**原因**: 数据库表和代码字段不一致
**预防**: 修改YAML后删除表重新部署

### 错误2: Checkbox无法保存
**原因**: 数据库字段类型不对
**预防**: Checkbox用 `varchar`，确保长度足够（如200）

### 错误3: 日期显示为 00:00:00
**原因**: 日期格式配置错误
**预防**: 
- 纯日期：`date_format: YYYY-MM-DD`
- 日期时间：`date_format: YYYY-MM-DD HH:mm:ss`（HH大写）

### 错误4: 字典重复
**原因**: 没检查系统已有字典
**预防**: 先用 `./check-dicts.sh` 查看，优先使用系统字典

---

## 📋 配置检查清单

创建新表前，打勾确认：

- [ ] 用 `./check-dicts.sh` 检查过系统字典
- [ ] 主键 `id` 已定义
- [ ] `create_time` 已定义（用于列表和查询）
- [ ] Checkbox字段用 `varchar`，长度≥200
- [ ] 日期格式严格匹配（注意HH大写）
- [ ] 字典类型有前缀（如 `sys_crm_`）
- [ ] 表名、字段名使用下划线命名

---

## 🔧 调试命令

```bash
# 查看生成的SQL
cat output/my_table/main/resources/mapper/my_module/MyTableMapper.xml

# 查看数据库表结构
mysql -uroot -p -e "DESCRIBE ry-vue.my_table;"

# 查看后端日志
tail -f /tmp/ruoyi.log

# 查看前端生成的代码
cat ruoyi-frontend/src/views/my_module/my_table/index.vue
```

---

## 💡 经验总结

### MVP4教会我们的事：

1. **先查字典，后创建**
   - 系统已有 `sys_normal_disable`、`sys_yes_no` 等常用字典
   - 新建字典要加前缀，避免冲突

2. **简单直接**
   - 学习原生RuoYi的简单处理方式
   - 不过度设计，保持代码清晰

3. **格式统一**
   - 日期格式前后端保持一致
   - `YYYY-MM-DD` ≠ `YYYY-MM-DD HH:mm:ss`

4. **测试覆盖**
   - 所有组件类型都应测试
   - 特别验证新增、修改、回显功能

---

## 📞 快速参考

```bash
# 查字典
./check-dicts.sh

# 部署
./quick-deploy.sh configs/schemas/my_table.yaml

# 重启后端
cd ../ruoyi/ruoyi-backend/ruoyi-admin/target && java -jar ruoyi-admin.jar

# 重启前端
cd ../ruoyi/ruoyi-frontend && npm run dev
```

---

**现在代码生成器已稳定可用！** 🎉

有问题先查：
1. [组件使用详解](docs/COMPONENT_GUIDE.md)
2. [使用指南](docs/USAGE_GUIDE.md)
3. [MVP4经验](docs/MVP4_SUMMARY.md)
