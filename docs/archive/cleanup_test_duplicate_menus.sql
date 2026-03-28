-- 安全清理test模块重复菜单 - 只删除重复的test菜单，保留系统菜单
-- 用法: mysql -u ruoyi -p ruoyi_vue < cleanup_test_duplicate_menus.sql

-- 1. 先查看test模块有哪些重复的菜单
SELECT 
    perms,
    COUNT(*) as count,
    GROUP_CONCAT(menu_id ORDER BY menu_id) as ids,
    GROUP_CONCAT(menu_name ORDER BY menu_id SEPARATOR ' | ') as names
FROM sys_menu 
WHERE perms LIKE 'test:%'
GROUP BY perms 
HAVING count > 1;

-- 2. 删除test模块重复的菜单（保留menu_id最小的）
DELETE m1 FROM sys_menu m1
INNER JOIN sys_menu m2 
WHERE m1.menu_id > m2.menu_id 
  AND m1.perms = m2.perms
  AND m1.perms LIKE 'test:%';

-- 3. 验证结果
SELECT perms, menu_name, menu_id 
FROM sys_menu 
WHERE perms LIKE 'test:%' 
ORDER BY perms, menu_id;
