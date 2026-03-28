#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动部署器 - 一键部署到若依项目
"""

import os
import shutil
import subprocess
from typing import List, Tuple


class RuoYiDeployer:
    """若依项目部署器"""
    
    def __init__(self, 
                 ruoyi_backend_path: str = '~/ruoyi/ruoyi-backend',
                 ruoyi_frontend_path: str = '~/ruoyi/ruoyi-frontend',
                 mysql_host: str = 'localhost',
                 mysql_user: str = 'ruoyi',
                 mysql_password: str = 'ruoyi123',
                 mysql_database: str = 'ry_vue'):
        self.backend_path = os.path.expanduser(ruoyi_backend_path)
        self.frontend_path = os.path.expanduser(ruoyi_frontend_path)
        self.mysql_config = {
            'host': mysql_host,
            'user': mysql_user,
            'password': mysql_password,
            'database': mysql_database
        }
    
    def deploy(self, output_dir: str, table_names: List[str]) -> Tuple[bool, List[str]]:
        """
        部署代码到若依项目
        
        Returns:
            (success, logs)
        """
        logs = []
        
        # 1. 复制后端代码
        logs.append("📦 部署后端代码...")
        java_src = os.path.join(output_dir, 'main', 'java')
        resources_src = os.path.join(output_dir, 'main', 'resources')
        
        if os.path.exists(java_src):
            java_dst = os.path.join(self.backend_path, 'ruoyi-system', 'src', 'main', 'java')
            self._copy_tree(java_src, java_dst)
            logs.append(f"  ✓ Java代码已复制到: {java_dst}")
        
        if os.path.exists(resources_src):
            resources_dst = os.path.join(self.backend_path, 'ruoyi-system', 'src', 'main', 'resources')
            self._copy_tree(resources_src, resources_dst)
            logs.append(f"  ✓ 资源文件已复制到: {resources_dst}")
        
        # 2. 复制前端代码
        logs.append("📦 部署前端代码...")
        vue_src = os.path.join(output_dir, 'vue')
        if os.path.exists(vue_src):
            vue_dst = os.path.join(self.frontend_path, 'src')
            self._copy_tree(vue_src, vue_dst)
            logs.append(f"  ✓ Vue代码已复制到: {vue_dst}")
        
        # 3. 执行菜单SQL
        logs.append("🗄️  执行菜单SQL...")
        sql_dir = os.path.join(output_dir, 'sql')
        if os.path.exists(sql_dir):
            for sql_file in os.listdir(sql_dir):
                if sql_file.endswith('_menu.sql'):
                    sql_path = os.path.join(sql_dir, sql_file)
                    success = self._execute_sql(sql_path)
                    if success:
                        logs.append(f"  ✓ SQL已执行: {sql_file}")
                    else:
                        logs.append(f"  ❌ SQL执行失败: {sql_file}")
        
        return True, logs
    
    def rebuild_and_restart(self) -> Tuple[bool, str]:
        """重新编译并重启服务"""
        logs = []
        
        # 1. 编译后端
        logs.append("🔨 编译后端...")
        compile_cmd = f"cd {self.backend_path} && mvn clean package -DskipTests -q"
        result = subprocess.run(compile_cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            logs.append("  ✓ 后端编译成功")
        else:
            logs.append(f"  ❌ 后端编译失败: {result.stderr}")
            return False, '\n'.join(logs)
        
        # 2. 停止服务（如果提供脚本）
        ruoyi_base = os.path.dirname(self.backend_path)
        stop_script = os.path.join(ruoyi_base, 'stop.sh')
        if os.path.exists(stop_script):
            logs.append("🛑 停止服务...")
            subprocess.run(f"{stop_script}", shell=True, capture_output=True)
            logs.append("  ✓ 服务已停止")
        
        # 3. 启动服务
        start_script = os.path.join(ruoyi_base, 'start.sh')
        if os.path.exists(start_script):
            logs.append("🚀 启动服务...")
            # 后台启动
            subprocess.Popen(f"{start_script}", shell=True, 
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            logs.append("  ✓ 服务已启动")
        
        return True, '\n'.join(logs)
    
    def _copy_tree(self, src: str, dst: str):
        """复制目录树"""
        if not os.path.exists(dst):
            os.makedirs(dst)
        
        for item in os.listdir(src):
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            
            if os.path.isdir(s):
                self._copy_tree(s, d)
            else:
                shutil.copy2(s, d)
    
    def _execute_sql(self, sql_file: str) -> bool:
        """执行SQL文件"""
        try:
            cmd = f"mysql -h {self.mysql_config['host']} " \
                  f"-u {self.mysql_config['user']} " \
                  f"-p{self.mysql_config['password']} " \
                  f"{self.mysql_config['database']} < {sql_file}"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.returncode == 0
        except Exception as e:
            print(f"SQL执行错误: {e}")
            return False


if __name__ == '__main__':
    deployer = RuoYiDeployer()
    success, logs = deployer.deploy('./output', ['customer_info'])
    print('\n'.join(logs))
