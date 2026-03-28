# RuoYi Generator - 会话总结
# 日期: 2025-03-19

## ✅ 已完成工作

### 1. 项目整理
- 重构目录结构: configs/schemas/, configs/generated/, scripts/
- 创建通用脚本: scripts/cleanup.sh, scripts/deploy.sh（参数化）
- 更新 README.md 文档

### 2. MVP1 实现 (基础组件)
- ✅ Input - 文本输入
- ✅ Textarea - 多行文本
- ✅ DatePicker - 日期/时间选择
- ✅ 查询方式: EQ, LIKE
- ✅ 字段配置: is_insert, is_edit, is_list, is_query, is_required
- ✅ 日期格式修复 (YYYY-MM-DD / yyyy-MM-dd 匹配)

### 3. MVP2 实现 (数字类型)
- ✅ InputNumber - 数字输入框
- ✅ BETWEEN 范围查询 (Start-End 双输入框)
- ✅ 精度控制 (scale 自动设置 precision)
- ✅ 支持类型: int, bigint, decimal, float, double
- ✅ 智能推断: 数字类型默认使用 BETWEEN 查询

### 4. Bug 修复
- 日期格式不匹配导致解析错误
- business 名称冲突 (info → mvp1_test)
- 菜单排序号重复问题
- 清理脚本误删其他模块代码

### 5. 配置文件优化
- 自动生成配置时添加排序号
- 智能推断 business 名称（避免通用名称）
- 数字类型默认开启 BETWEEN 查询

## 📝 待测试项目

### MVP2 测试清单
- [ ] InputNumber 组件显示正常
- [ ] 价格字段精度为 2 位小数
- [ ] BETWEEN 范围查询表单
- [ ] 范围查询功能是否正常
- [ ] 新增/编辑数字字段保存

## 🎯 后续计划

### MVP3 (待实现)
- [ ] Select - 下拉选择框
- [ ] Radio - 单选框组 (如 status 字段)
- [ ] Checkbox - 多选框
- [ ] ImageUpload - 图片上传
- [ ] FileUpload - 文件上传
- [ ] Editor - 富文本编辑器
- [ ] 字典数据支持 (sys_dict_type/sys_dict_data)

## 💡 关键决策

1. **business 命名**: 使用完整表名避免冲突 (如 mvp1_test)
2. **日期格式**: Vue 用 YYYY-MM-DD, Java 用 yyyy-MM-dd
3. **部署路径**: Controller → ruoyi-admin, 其他 → ruoyi-system
4. **代码生成**: 每个表独立输出目录 (output/{table_name}/)

## 🐛 已知问题
- 无

## 📁 重要文件位置
- 表结构定义: configs/schemas/
- 生成配置: configs/generated/
- 部署脚本: scripts/cleanup.sh, scripts/deploy.sh
- 代码输出: output/{table_name}/

## 🔧 使用命令
```bash
# 生成配置
python3 main_allinone.py --schema configs/schemas/test-mvp2.yaml --step=config

# 生成代码
python3 main_allinone.py --schema configs/generated/mvp2_test-config.yaml --step=generate

# 部署
./scripts/cleanup.sh mvp2_test && ./scripts/deploy.sh mvp2_test
```
