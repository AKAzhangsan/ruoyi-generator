#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
字典管理器 - 处理字典的查询、对比、生成
"""

import os
import yaml
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, field


@dataclass
class DictItem:
    """字典数据项"""
    label: str
    value: str
    sort: int = 1
    is_default: str = 'N'
    list_class: str = ''  # primary/success/warning/danger
    status: str = '0'


@dataclass
class DictConfig:
    """字典配置"""
    dict_type: str
    dict_name: str
    source_table: str = ''  # 来源表
    data: List[DictItem] = field(default_factory=list)
    generated_at: str = ''


class DictManager:
    """字典管理器"""
    
    def __init__(self, db_config: Dict[str, Any] = None):
        self.db_config = db_config or {}
        self.db_connection = None
    
    def _get_connection(self):
        """获取数据库连接（延迟加载）"""
        if self.db_connection is None:
            import pymysql
            self.db_connection = pymysql.connect(
                host=self.db_config.get('host', 'localhost'),
                port=self.db_config.get('port', 3306),
                user=self.db_config.get('user', 'ruoyi'),
                password=self.db_config.get('password', 'ruoyi123'),
                database=self.db_config.get('database', 'ry_vue'),
                charset=self.db_config.get('charset', 'utf8mb4')
            )
        return self.db_connection
    
    def close(self):
        """关闭数据库连接"""
        if self.db_connection:
            self.db_connection.close()
            self.db_connection = None
    
    def check_dict_exists(self, dict_type: str) -> Tuple[bool, Optional[Dict]]:
        """
        检查字典是否存在于数据库
        
        Returns:
            (exists, dict_info)
        """
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT dict_id, dict_name, status FROM sys_dict_type WHERE dict_type = %s",
                    (dict_type,)
                )
                result = cursor.fetchone()
                if result:
                    return True, {
                        'dict_id': result[0],
                        'dict_name': result[1],
                        'status': result[2]
                    }
                return False, None
        except Exception as e:
            print(f"⚠️  检查字典存在性失败: {e}")
            return False, None
    
    def get_dict_data_from_db(self, dict_type: str) -> List[Dict]:
        """从数据库获取字典数据项"""
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    """SELECT dict_label, dict_value, dict_sort, is_default, list_class, status 
                       FROM sys_dict_data 
                       WHERE dict_type = %s AND status = '0'
                       ORDER BY dict_sort""",
                    (dict_type,)
                )
                results = cursor.fetchall()
                return [
                    {
                        'label': r[0],
                        'value': r[1],
                        'sort': r[2],
                        'is_default': r[3],
                        'list_class': r[4],
                        'status': r[5]
                    }
                    for r in results
                ]
        except Exception as e:
            print(f"⚠️  获取字典数据失败: {e}")
            return []
    
    def compare_dict_data(self, dict_type: str, config_data: List[DictItem]) -> Dict[str, Any]:
        """
        对比配置数据与数据库数据
        
        Returns:
            {
                'status': 'identical' | 'different' | 'missing' | 'db_empty',
                'db_count': int,
                'config_count': int,
                'diff_items': [...]  # 差异项
            }
        """
        exists, dict_info = self.check_dict_exists(dict_type)
        
        if not exists:
            return {
                'status': 'missing',
                'db_count': 0,
                'config_count': len(config_data),
                'diff_items': []
            }
        
        db_data = self.get_dict_data_from_db(dict_type)
        
        if not db_data:
            return {
                'status': 'db_empty',
                'db_count': 0,
                'config_count': len(config_data),
                'diff_items': []
            }
        
        # 对比数据项
        db_values = {d['value']: d for d in db_data}
        config_values = {d.value: d for d in config_data}
        
        diff_items = []
        
        # 检查配置中有但数据库没有的
        for value, item in config_values.items():
            if value not in db_values:
                diff_items.append({
                    'type': 'new',
                    'value': value,
                    'label': item.label
                })
        
        # 检查数据库中有但配置中没有的
        for value, item in db_values.items():
            if value not in config_values:
                diff_items.append({
                    'type': 'removed',
                    'value': value,
                    'label': item['label']
                })
        
        # 检查标签变更
        for value in set(db_values.keys()) & set(config_values.keys()):
            db_item = db_values[value]
            cfg_item = config_values[value]
            if db_item['label'] != cfg_item.label:
                diff_items.append({
                    'type': 'modified',
                    'value': value,
                    'db_label': db_item['label'],
                    'config_label': cfg_item.label
                })
        
        status = 'different' if diff_items else 'identical'
        
        return {
            'status': status,
            'db_count': len(db_data),
            'config_count': len(config_data),
            'diff_items': diff_items
        }
    
    def generate_dict_config(self, dict_data: Dict, source_table: str) -> DictConfig:
        """从 schema 数据生成 DictConfig"""
        items = []
        for i, d in enumerate(dict_data.get('data', []), 1):
            items.append(DictItem(
                label=d.get('label', ''),
                value=str(d.get('value', '')),  # 确保是字符串
                sort=d.get('sort', i),
                is_default=d.get('is_default', 'N'),
                list_class=d.get('list_class', ''),
                status=d.get('status', '0')
            ))
        
        from datetime import datetime
        return DictConfig(
            dict_type=dict_data['dict_type'],
            dict_name=dict_data.get('dict_name', dict_data['dict_type']),
            source_table=source_table,
            data=items,
            generated_at=datetime.now().isoformat()
        )
    
    def save_dict_config(self, dict_config: DictConfig, output_dir: str) -> str:
        """保存字典配置到文件"""
        os.makedirs(output_dir, exist_ok=True)
        
        file_path = os.path.join(output_dir, f"{dict_config.dict_type}.yaml")
        
        data = {
            'dict_type': dict_config.dict_type,
            'dict_name': dict_config.dict_name,
            'source_table': dict_config.source_table,
            'generated_at': dict_config.generated_at,
            'data': [
                {
                    'label': item.label,
                    'value': item.value,
                    'sort': item.sort,
                    'is_default': item.is_default,
                    'list_class': item.list_class,
                    'status': item.status
                }
                for item in dict_config.data
            ]
        }
        
        with open(file_path, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False)
        
        return file_path
    
    def load_dict_config(self, file_path: str) -> Optional[DictConfig]:
        """从文件加载字典配置"""
        if not os.path.exists(file_path):
            return None
        
        with open(file_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
        
        items = []
        for d in data.get('data', []):
            items.append(DictItem(
                label=d.get('label', ''),
                value=str(d.get('value', '')),
                sort=d.get('sort', 1),
                is_default=d.get('is_default', 'N'),
                list_class=d.get('list_class', ''),
                status=d.get('status', '0')
            ))
        
        return DictConfig(
            dict_type=data['dict_type'],
            dict_name=data.get('dict_name', data['dict_type']),
            source_table=data.get('source_table', ''),
            data=items,
            generated_at=data.get('generated_at', '')
        )
    
    def generate_dict_sql(self, dict_config: DictConfig, strategy: str = 'merge') -> str:
        """
        生成字典 SQL
        
        Args:
            strategy: 'skip' | 'merge' | 'replace'
        """
        lines = []
        
        # 字典类型 SQL
        if strategy == 'skip':
            lines.append(f"-- 策略: skip（如果存在则跳过）")
            lines.append(f"INSERT IGNORE INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)")
            lines.append(f"VALUES ('{dict_config.dict_name}', '{dict_config.dict_type}', '0', 'admin', NOW(), '');")
        elif strategy == 'merge':
            lines.append(f"-- 策略: merge（合并，不删除已有数据）")
            lines.append(f"INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)")
            lines.append(f"VALUES ('{dict_config.dict_name}', '{dict_config.dict_type}', '0', 'admin', NOW(), '')")
            lines.append(f"ON DUPLICATE KEY UPDATE dict_name = VALUES(dict_name), status = '0';")
        else:  # replace
            lines.append(f"-- 策略: replace（完全替换）")
            lines.append(f"DELETE FROM sys_dict_type WHERE dict_type = '{dict_config.dict_type}';")
            lines.append(f"INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)")
            lines.append(f"VALUES ('{dict_config.dict_name}', '{dict_config.dict_type}', '0', 'admin', NOW(), '');")
        
        lines.append("")
        
        # 字典数据 SQL
        if strategy == 'replace':
            lines.append(f"DELETE FROM sys_dict_data WHERE dict_type = '{dict_config.dict_type}';")
        
        for item in dict_config.data:
            if strategy == 'skip':
                lines.append(f"INSERT IGNORE INTO sys_dict_data (dict_label, dict_value, dict_type, dict_sort, is_default, status, create_by, create_time, list_class)")
            else:
                lines.append(f"INSERT INTO sys_dict_data (dict_label, dict_value, dict_type, dict_sort, is_default, status, create_by, create_time, list_class)")
            
            lines.append(f"VALUES ('{item.label}', '{item.value}', '{dict_config.dict_type}', {item.sort}, '{item.is_default}', '{item.status}', 'admin', NOW(), '{item.list_class}');")
        
        return '\n'.join(lines)
    
    def print_dict_status(self, dict_type: str, comparison: Dict):
        """打印字典状态信息"""
        status_map = {
            'missing': '❌ 数据库不存在（新字典）',
            'db_empty': '⚠️  字典存在但无数据',
            'identical': '✅ 数据一致',
            'different': '⚠️  数据有差异'
        }
        
        print(f"   - {dict_type}: {status_map.get(comparison['status'], comparison['status'])}")
        
        if comparison['diff_items']:
            for item in comparison['diff_items'][:3]:  # 只显示前3个差异
                if item['type'] == 'new':
                    print(f"     + 新增: {item['label']} ({item['value']})")
                elif item['type'] == 'removed':
                    print(f"     - 删除: {item['label']} ({item['value']})")
                elif item['type'] == 'modified':
                    print(f"     ~ 修改: {item['db_label']} -> {item['config_label']}")
            
            if len(comparison['diff_items']) > 3:
                print(f"     ... 还有 {len(comparison['diff_items']) - 3} 项差异")


if __name__ == '__main__':
    # 测试
    manager = DictManager()
    
    # 测试检查字典
    exists, info = manager.check_dict_exists('sys_normal_disable')
    print(f"sys_normal_disable exists: {exists}")
    if info:
        print(f"  Info: {info}")
    
    # 测试获取字典数据
    data = manager.get_dict_data_from_db('sys_normal_disable')
    print(f"  Data count: {len(data)}")
    for d in data[:2]:
        print(f"    - {d['label']}: {d['value']}")
    
    manager.close()
