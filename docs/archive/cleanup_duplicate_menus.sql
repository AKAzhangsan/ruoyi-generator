-- 清理重复菜单数据 SQL
-- 用法: mysql -u ruoyi -p ruoyi_vue < cleanup_duplicate_menus.sql

-- 1. 查看重复的菜单（按权限标识分组）
SELECT 
    perms,
    COUNT(*) as count,
    GROUP_CONCAT(menu_id ORDER BY menu_id) as ids
FROM sys_menu 
WHERE perms IS NOT NULL AND perms != ''
GROUP BY perms 
HAVING count > 1;

-- 2. 删除重复的菜单数据（保留每个 perms 中 menu_id 最小的一条）
DELETE m1 FROM sys_menu m1
INNER JOIN sys_menu m2 
WHERE m1.menu_id > m2.menu_id 
  AND m1.perms = m2.perms
  AND m1.perms IS NOT NULL 
  AND m1.perms != '';

-- 3. 验证清理结果
SELECT perms, COUNT(*) as count FROM sys_menu WHERE perms LIKE 'test:%' GROUP BY perms;
