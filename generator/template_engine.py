#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
若依代码生成器 - 模板引擎
"""

import os
import re
from datetime import datetime
from jinja2 import Environment, FileSystemLoader, BaseLoader
from jinja2.exceptions import TemplateNotFound


class RuoYiTemplateEngine:
    """若依模板引擎 - 完美复刻若依原生输出"""
    
    def __init__(self, template_path: str = './templates'):
        self.template_path = template_path
        self.env = Environment(
            loader=FileSystemLoader(template_path),
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=True,
        )
        self._register_filters()
        
    def _register_filters(self):
        """注册自定义过滤器"""
        # 下划线转驼峰（首字母小写）
        self.env.filters['camel_case'] = self._to_camel_case
        # 下划线转驼峰（首字母大写）
        self.env.filters['pascal_case'] = self._to_pascal_case
        # 首字母小写
        self.env.filters['uncapitalize'] = lambda s: s[0].lower() + s[1:] if s else s
        # 首字母大写
        self.env.filters['capitalize'] = lambda s: s[0].upper() + s[1:] if s else s
        # 提取字典选项
        self.env.filters['dict_options'] = self._extract_dict_options
        
    def render(self, template_name: str, context: dict) -> str:
        """渲染模板"""
        template = self.env.get_template(template_name)
        return template.render(**context)
    
    def render_string(self, template_string: str, context: dict) -> str:
        """渲染字符串模板"""
        from jinja2 import Template
        template = Template(template_string)
        return template.render(**context)
    
    @staticmethod
    def _to_camel_case(snake_str: str) -> str:
        """下划线转驼峰（首字母小写）"""
        if not snake_str:
            return ''
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])
    
    @staticmethod
    def _to_pascal_case(snake_str: str) -> str:
        """下划线转驼峰（首字母大写）"""
        if not snake_str:
            return ''
        components = snake_str.split('_')
        return ''.join(x.title() for x in components)
    
    @staticmethod
    def _extract_dict_options(comment: str) -> str:
        """从注释中提取字典选项，如：状态（0正常 1停用）-> 0=正常,1=停用"""
        match = re.search(r'[（(]([\d\w]+[^）)]+)[）)]', comment)
        if match:
            content = match.group(1)
            # 解析格式：0正常 1停用 或 0=正常,1=停用
            pairs = []
            for part in content.split():
                if '=' in part:
                    k, v = part.split('=', 1)
                    pairs.append(f"{k}={v}")
                elif len(part) >= 2 and part[0].isdigit():
                    pairs.append(f"{part[0]}={part[1:]}")
            return ','.join(pairs)
        return ''


class CodeFileWriter:
    """代码文件写入器"""
    
    def __init__(self, base_path: str):
        self.base_path = base_path
        
    def write(self, relative_path: str, content: str):
        """写入文件"""
        full_path = os.path.join(self.base_path, relative_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
        return full_path


if __name__ == '__main__':
    # 测试
    engine = RuoYiTemplateEngine()
    
    # 测试过滤器
    print(engine._to_camel_case('user_name'))  # userName
    print(engine._to_pascal_case('user_name'))  # UserName
    print(engine._extract_dict_options('状态（0正常 1停用）'))  # 0=正常,1=停用
