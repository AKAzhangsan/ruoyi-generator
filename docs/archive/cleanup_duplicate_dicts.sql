-- 清理重复字典数据 SQL
-- 用法: mysql -u ruoyi -p ruoyi_vue < cleanup_duplicate_dicts.sql

-- 1. 先查看有哪些字典类型有重复数据
SELECT 
    dict_type,
    dict_value,
    COUNT(*) as count,
    GROUP_CONCAT(dict_code ORDER BY dict_code) as ids
FROM sys_dict_data 
GROUP BY dict_type, dict_value 
HAVING count > 1;

-- 2. 删除重复的字典数据（保留每个 dict_type + dict_value 组合中 dict_code 最小的一条）
DELETE d1 FROM sys_dict_data d1
INNER JOIN sys_dict_data d2 
WHERE d1.dict_code > d2.dict_code 
  AND d1.dict_type = d2.dict_type 
  AND d1.dict_value = d2.dict_value;

-- 3. 验证清理结果
SELECT dict_type, COUNT(*) as count FROM sys_dict_data GROUP BY dict_type;
