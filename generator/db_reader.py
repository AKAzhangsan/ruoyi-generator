#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
若依代码生成器 - 数据库读取模块
完美兼容若依原生生成器
"""

import pymysql
import re
from typing import Dict, List, Any, Optional


class ColumnInfo:
    """字段信息"""
    def __init__(self):
        self.column_name: str = ""              # 数据库字段名
        self.data_type: str = ""               # 数据库类型
        self.column_comment: str = ""          # 字段注释
        self.is_nullable: str = "YES"          # 是否可空
        self.column_default: Optional[str] = None  # 默认值
        self.character_maximum_length: Optional[int] = None  # 字符长度
        self.numeric_precision: Optional[int] = None         # 数值精度
        self.numeric_scale: Optional[int] = None             # 小数位
        self.is_pk: bool = False               # 是否主键
        self.is_increment: bool = False        # 是否自增
        
        # Java相关
        self.java_field: str = ""              # Java字段名
        self.java_type: str = ""               # Java类型
        self.jdbc_type: str = ""               # JDBC类型
        self.cap_java_field: str = ""          # 首字母大写的Java字段名
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            'column_name': self.column_name,
            'data_type': self.data_type,
            'column_comment': self.column_comment,
            'is_nullable': self.is_nullable,
            'column_default': self.column_default,
            'character_maximum_length': self.character_maximum_length,
            'numeric_precision': self.numeric_precision,
            'numeric_scale': self.numeric_scale,
            'is_pk': self.is_pk,
            'is_increment': self.is_increment,
            'java_field': self.java_field,
            'java_type': self.java_type,
            'jdbc_type': self.jdbc_type,
            'cap_java_field': self.cap_java_field,
        }


class TableInfo:
    """表信息"""
    def __init__(self):
        self.table_name: str = ""              # 表名
        self.table_comment: str = ""           # 表注释
        self.class_name: str = ""              # 实体类名
        self.classname: str = ""               # 首字母小写的类名
        self.module_name: str = ""             # 模块名
        self.business_name: str = ""           # 业务名
        self.function_name: str = ""           # 功能名
        self.columns: List[ColumnInfo] = []    # 字段列表
        self.pk_column: Optional[ColumnInfo] = None  # 主键字段
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            'table_name': self.table_name,
            'table_comment': self.table_comment,
            'class_name': self.class_name,
            'classname': self.classname,
            'module_name': self.module_name,
            'business_name': self.business_name,
            'function_name': self.function_name,
            'columns': [c.to_dict() for c in self.columns],
            'pk_column': self.pk_column.to_dict() if self.pk_column else None,
        }


class DatabaseReader:
    """数据库读取器"""
    
    # 类型映射
    MYSQL_TO_JAVA = {
        'bigint': 'Long',
        'int': 'Integer',
        'tinyint': 'Integer',
        'smallint': 'Integer',
        'mediumint': 'Integer',
        'varchar': 'String',
        'char': 'String',
        'text': 'String',
        'longtext': 'String',
        'decimal': 'BigDecimal',
        'numeric': 'BigDecimal',
        'float': 'Float',
        'double': 'Double',
        'datetime': 'Date',
        'timestamp': 'Date',
        'date': 'Date',
        'time': 'Date',
        'blob': 'byte[]',
        'longblob': 'byte[]',
    }
    
    MYSQL_TO_JDBC = {
        'bigint': 'BIGINT',
        'int': 'INTEGER',
        'tinyint': 'TINYINT',
        'smallint': 'SMALLINT',
        'varchar': 'VARCHAR',
        'char': 'CHAR',
        'text': 'LONGVARCHAR',
        'decimal': 'DECIMAL',
        'datetime': 'TIMESTAMP',
        'timestamp': 'TIMESTAMP',
        'date': 'DATE',
    }
    
    def __init__(self, host: str, port: int, database: str, 
                 user: str, password: str, charset: str = 'utf8mb4'):
        self.config = {
            'host': host,
            'port': port,
            'database': database,
            'user': user,
            'password': password,
            'charset': charset,
            'cursorclass': pymysql.cursors.DictCursor
        }
        self.conn = None
        
    def connect(self):
        """连接数据库"""
        self.conn = pymysql.connect(**self.config)
        
    def close(self):
        """关闭连接"""
        if self.conn:
            self.conn.close()
            
    def __enter__(self):
        self.connect()
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        
    def get_table_info(self, table_name: str) -> TableInfo:
        """获取表信息"""
        table_info = TableInfo()
        table_info.table_name = table_name
        
        # 获取表注释
        table_info.table_comment = self._get_table_comment(table_name)
        
        # 获取主键信息
        pk_columns = self._get_primary_keys(table_name)
        
        # 获取字段信息
        with self.conn.cursor() as cursor:
            sql = """
                SELECT 
                    COLUMN_NAME,
                    DATA_TYPE,
                    COLUMN_COMMENT,
                    IS_NULLABLE,
                    COLUMN_DEFAULT,
                    CHARACTER_MAXIMUM_LENGTH,
                    NUMERIC_PRECISION,
                    NUMERIC_SCALE,
                    EXTRA
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
                ORDER BY ORDINAL_POSITION
            """
            cursor.execute(sql, (self.config['database'], table_name))
            rows = cursor.fetchall()
            
            for row in rows:
                col = ColumnInfo()
                col.column_name = row['COLUMN_NAME']
                col.data_type = row['DATA_TYPE'].lower()
                col.column_comment = row['COLUMN_COMMENT'] or ''
                col.is_nullable = row['IS_NULLABLE']
                col.column_default = row['COLUMN_DEFAULT']
                col.character_maximum_length = row['CHARACTER_MAXIMUM_LENGTH']
                col.numeric_precision = row['NUMERIC_PRECISION']
                col.numeric_scale = row['NUMERIC_SCALE']
                
                # 判断是否主键
                col.is_pk = row['COLUMN_NAME'] in pk_columns
                
                # 判断是否自增
                col.is_increment = 'auto_increment' in (row['EXTRA'] or '').lower()
                
                # 转换Java相关名称
                col.java_field = self._to_camel_case(col.column_name)
                col.cap_java_field = col.java_field[0].upper() + col.java_field[1:]
                col.java_type = self.MYSQL_TO_JAVA.get(col.data_type, 'String')
                col.jdbc_type = self.MYSQL_TO_JDBC.get(col.data_type, 'VARCHAR')
                
                table_info.columns.append(col)
                
                # 记录主键字段
                if col.is_pk:
                    table_info.pk_column = col
                    
        # 如果没有找到主键，使用第一个字段
        if not table_info.pk_column and table_info.columns:
            table_info.pk_column = table_info.columns[0]
            
        return table_info
    
    def _get_table_comment(self, table_name: str) -> str:
        """获取表注释"""
        with self.conn.cursor() as cursor:
            sql = """
                SELECT TABLE_COMMENT 
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
            """
            cursor.execute(sql, (self.config['database'], table_name))
            row = cursor.fetchone()
            return row['TABLE_COMMENT'] if row else ''
    
    def _get_primary_keys(self, table_name: str) -> List[str]:
        """获取主键列表"""
        with self.conn.cursor() as cursor:
            sql = """
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = %s 
                    AND TABLE_NAME = %s
                    AND CONSTRAINT_NAME = 'PRIMARY'
                ORDER BY ORDINAL_POSITION
            """
            cursor.execute(sql, (self.config['database'], table_name))
            rows = cursor.fetchall()
            return [row['COLUMN_NAME'] for row in rows]
    
    @staticmethod
    def _to_camel_case(snake_str: str) -> str:
        """下划线转驼峰"""
        components = snake_str.split('_')
        # 第一个单词小写，后面的首字母大写
        return components[0] + ''.join(x.title() for x in components[1:])


if __name__ == '__main__':
    # 测试
    reader = DatabaseReader('localhost', 3306, 'ry_vue', 'ruoyi', 'ruoyi123')
    with reader:
        info = reader.get_table_info('sys_user')
        print(f"表名: {info.table_name}")
        print(f"注释: {info.table_comment}")
        print(f"字段数: {len(info.columns)}")
        for col in info.columns[:3]:
            print(f"  {col.column_name} -> {col.java_field} ({col.java_type})")
