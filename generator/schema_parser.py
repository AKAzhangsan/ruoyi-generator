#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
表结构定义解析器 - 从YAML生成DDL和完整配置
"""

import yaml
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field


@dataclass
class Column:
    """字段定义"""
    # 基础属性
    name: str
    comment: str = ""
    type: str = "varchar"
    length: Optional[int] = None
    precision: Optional[int] = None
    scale: Optional[int] = None
    is_nullable: bool = True
    default: Any = None
    is_pk: bool = False
    is_auto_increment: bool = False

    # BaseEntity字段（create_by, create_time, update_by, update_time）
    is_super_column: bool = False

    # Java类型（可覆盖自动推断）
    java_type: Optional[str] = None

    # 查询配置
    query: bool = False
    query_type: str = "EQ"  # EQ, NE, GT, GE, LT, LE, LIKE, BETWEEN

    # 表单配置
    is_insert: bool = True
    is_edit: bool = True
    is_list: bool = True
    is_required: bool = False

    # 组件配置
    component: str = "Input"  # Input, Textarea, Select, Radio, Checkbox, DatePicker, InputNumber, Switch, ImageUpload, FileUpload, Editor
    dict_type: Optional[str] = None
    date_format: Optional[str] = None

    # MVP3: 上传组件和编辑器配置
    limit: Optional[int] = None  # 上传数量限制
    file_size: Optional[int] = None  # 文件大小限制(MB)
    file_type: Optional[List[str]] = None  # 文件类型
    height: Optional[int] = None  # 编辑器高度


@dataclass
class DictDataItem:
    """字典数据项定义"""
    label: str
    value: str
    sort: int = 1
    is_default: str = 'N'
    list_class: str = ''  # primary/success/warning/danger
    status: str = '0'


@dataclass
class DictItem:
    """字典定义"""
    dict_type: str
    dict_name: str = ""
    sort: int = 1
    data: List[DictDataItem] = field(default_factory=list)  # 字典数据项


@dataclass
class GenConfig:
    """生成配置"""
    tpl_web_type: str = "element-plus"  # element-plus, ant-design
    function_name: str = ""  # 功能名称
    business_name: str = "info"  # 业务名称
    class_name: str = ""  # 实体类名
    package_name: str = "com.ruoyi.system"  # 包名
    author: str = "ruoyi"  # 作者
    sort: int = 1  # 菜单排序号


@dataclass
class TreeConfig:
    """树表专用配置"""
    tree_code: str = "id"           # 节点ID字段（通常是主键）
    tree_parent_code: str = "parent_id"  # 父节点ID字段
    tree_name: str = ""             # 树节点显示名称字段


@dataclass
class SubTableConfig:
    """主子表专用配置 - 子表配置"""
    table_name: str = ""            # 子表名
    table_comment: str = ""         # 子表注释
    fk_column: str = ""             # 外键字段名（关联主表）
    columns: List[Column] = field(default_factory=list)  # 子表字段列表



@dataclass
class SubTableConfig:
    """主子表 - 子表配置"""
    table_name: str = ""
    table_comment: str = ""
    fk_column: str = ""          # 外键字段名（关联主表主键）
    columns: List[Column] = field(default_factory=list)

@dataclass
class TableSchema:
    """表结构定义"""
    table_name: str = ""
    table_comment: str = ""
    module: str = "system"
    business: str = "info"
    tpl_type: str = "crud"  # crud=单表, tree=树表, sub=主子表
    tree_config: Optional[TreeConfig] = None  # 树表专用配置
    sub_table: Optional[SubTableConfig] = None  # 主子表配置
    sub_table: Optional[SubTableConfig] = None  # 主子表专用配置 - 子表配置
    columns: List[Column] = field(default_factory=list)
    dicts: List[DictItem] = field(default_factory=list)
    gen_config: GenConfig = field(default_factory=GenConfig)


class SchemaParser:
    """表结构解析器"""
    
    # 类型映射：YAML类型 -> MySQL类型
    TYPE_MAPPING = {
        'bigint': 'BIGINT',
        'int': 'INT',
        'integer': 'INT',
        'tinyint': 'TINYINT',
        'smallint': 'SMALLINT',
        'varchar': 'VARCHAR',
        'char': 'CHAR',
        'text': 'TEXT',
        'longtext': 'LONGTEXT',
        'decimal': 'DECIMAL',
        'datetime': 'DATETIME',
        'timestamp': 'TIMESTAMP',
        'date': 'DATE',
        'time': 'TIME',
        'blob': 'BLOB',
        'float': 'FLOAT',
        'double': 'DOUBLE',
    }
    
    # Java类型映射
    MYSQL_TO_JAVA = {
        'bigint': 'Long',
        'int': 'Integer',
        'tinyint': 'Integer',
        'smallint': 'Integer',
        'varchar': 'String',
        'char': 'String',
        'text': 'String',
        'longtext': 'String',
        'decimal': 'BigDecimal',
        'float': 'Float',
        'double': 'Double',
        'datetime': 'Date',
        'timestamp': 'Date',
        'date': 'Date',
        'blob': 'byte[]',
    }
    
    # 组件类型映射
    COMPONENT_MAPPING = {
        'varchar': 'Input',
        'char': 'Input',
        'text': 'Textarea',
        'longtext': 'Textarea',
        'int': 'InputNumber',
        'bigint': 'InputNumber',
        'decimal': 'InputNumber',
        'float': 'InputNumber',
        'double': 'InputNumber',
        'tinyint': 'InputNumber',  # MVP2: Boolean 可用 tinyint(1)
        'datetime': 'DatePicker',
        'timestamp': 'DatePicker',
        'date': 'DatePicker',
        'blob': 'Input',
    }
    
    # 日期格式映射（Element Plus 兼容格式）
    DATE_FORMAT_MAPPING = {
        'date': 'YYYY-MM-DD',  # Element Plus 3.x 使用大写
        'datetime': 'YYYY-MM-DD HH:mm:ss',
        'timestamp': 'YYYY-MM-DD HH:mm:ss',
    }

    # BaseEntity字段（不参与insert/update）
    BASE_ENTITY_COLUMNS = ['create_by', 'create_time', 'update_by', 'update_time']

    # TreeEntity额外字段（树表模式下，这些字段由TreeEntity基类提供）
    TREE_ENTITY_COLUMNS = ['parent_id', 'ancestors', 'order_num']

    def parse_yaml(self, yaml_path: str) -> List[TableSchema]:
        """解析YAML文件，支持两种格式:
        格式1: tables列表格式（用于表结构定义）
        格式2: 扁平格式（用于配置文件）
        """
        with open(yaml_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
        
        tables = []
        
        # 格式1: tables列表格式
        if 'tables' in data:
            for table_data in data.get('tables', []):
                table = self._parse_table_data(table_data)
                tables.append(table)
        
        # 格式2: 扁平格式（配置文件）
        elif 'table_name' in data:
            table = self._parse_table_data(data)
            tables.append(table)
        
        return tables
    
    def _parse_table_data(self, table_data: dict) -> TableSchema:
        """解析单个表数据"""
        table = TableSchema()
        table.table_name = table_data['table_name']
        table.table_comment = table_data.get('table_comment', '')
        table.module = table_data.get('module', 'system')
        
        # 解析模板类型：crud=单表, tree=树表, sub=主子表
        table.tpl_type = table_data.get('tpl_type', 'crud')
        
        # 解析树表配置
        if table.tpl_type == 'tree':
            tree_data = table_data.get('tree_config', {})
            table.tree_config = TreeConfig(
                tree_code=tree_data.get('tree_code', 'id'),
                tree_parent_code=tree_data.get('tree_parent_code', 'parent_id'),
                tree_name=tree_data.get('tree_name', '')
            )

        # 解析主子表配置
        if table.tpl_type == 'sub':
            sub_data = table_data.get('sub_table', {})
            if sub_data:
                sub_columns = []
                for col_data in sub_data.get('columns', []):
                    is_query = col_data.get('is_query', col_data.get('query', False))
                    column = Column(
                        name=col_data['name'],
                        comment=col_data.get('comment', ''),
                        type=col_data.get('type', 'varchar'),
                        length=col_data.get('length'),
                        precision=col_data.get('precision'),
                        scale=col_data.get('scale'),
                        is_nullable=col_data.get('is_nullable', True),
                        default=col_data.get('default'),
                        is_pk=col_data.get('is_pk', False),
                        is_auto_increment=col_data.get('is_auto_increment', False),
                        is_super_column=col_data['name'] in self.BASE_ENTITY_COLUMNS,
                        java_type=col_data.get('java_type'),
                        query=is_query,
                        query_type=col_data.get('query_type', 'EQ'),
                        is_insert=col_data.get('is_insert', True),
                        is_edit=col_data.get('is_edit', True),
                        is_list=col_data.get('is_list', True),
                        is_required=col_data.get('is_required', False),
                        component=col_data.get('component', 'Input'),
                        dict_type=col_data.get('dict_type'),
                        date_format=col_data.get('date_format'),
                        limit=col_data.get('limit'),
                        file_size=col_data.get('file_size'),
                        file_type=col_data.get('file_type'),
                        height=col_data.get('height')
                    )
                    sub_columns.append(column)

                table.sub_table = SubTableConfig(
                    table_name=sub_data.get('table_name', ''),
                    table_comment=sub_data.get('table_comment', ''),
                    fk_column=sub_data.get('fk_column', ''),
                    columns=sub_columns
                )
        

        # 解析主子表配置
        if table.tpl_type == 'sub':
            sub_data = table_data.get('sub_table', {})
            if sub_data:
                sub_columns = []
                for col_data in sub_data.get('columns', []):
                    is_query = col_data.get('is_query', col_data.get('query', False))
                    col = Column(
                        name=col_data['name'],
                        comment=col_data.get('comment', ''),
                        type=col_data.get('type', 'varchar'),
                        length=col_data.get('length'),
                        precision=col_data.get('precision'),
                        scale=col_data.get('scale'),
                        is_nullable=col_data.get('is_nullable', True),
                        default=col_data.get('default'),
                        is_pk=col_data.get('is_pk', False),
                        is_auto_increment=col_data.get('is_auto_increment', False),
                        is_super_column=col_data['name'] in self.BASE_ENTITY_COLUMNS,
                        java_type=col_data.get('java_type'),
                        query=is_query,
                        query_type=col_data.get('query_type', 'EQ'),
                        is_insert=col_data.get('is_insert', True),
                        is_edit=col_data.get('is_edit', True),
                        is_list=col_data.get('is_list', True),
                        is_required=col_data.get('is_required', False),
                        component=col_data.get('component', self.COMPONENT_MAPPING.get(col_data.get('type', 'varchar'), 'Input')),
                        dict_type=col_data.get('dict_type'),
                        date_format=col_data.get('date_format', self.DATE_FORMAT_MAPPING.get(col_data.get('type', ''), None)),
                    )
                    if not col.java_type:
                        col.java_type = self.MYSQL_TO_JAVA.get(col.type, 'String')
                    sub_columns.append(col)
                
                table.sub_table = SubTableConfig(
                    table_name=sub_data.get('table_name', ''),
                    table_comment=sub_data.get('table_comment', ''),
                    fk_column=sub_data.get('fk_column', ''),
                    columns=sub_columns,
                )

        # 智能推断 business 名称，避免使用通用的 "info"
        # 优先使用用户指定的值，其次从表名推断
        if 'business' in table_data:
            table.business = table_data['business']
        else:
            # 从表名推断: product_info -> product_info (或 productInfo)
            # 避免使用 info/manage 等通用名称
            table.business = self._to_business_name(table.table_name)
        
        # 解析生成配置
        gen_config_data = table_data.get('gen_config', {})
        table.gen_config = GenConfig(
            tpl_web_type=gen_config_data.get('tpl_web_type', 'element-plus'),
            function_name=gen_config_data.get('function_name', table.table_comment or table.table_name),
            business_name=gen_config_data.get('business_name', table.business),
            class_name=gen_config_data.get('class_name', self._to_class_name(table.table_name)),
            package_name=gen_config_data.get('package_name', 'com.ruoyi.system'),
            author=gen_config_data.get('author', 'ruoyi'),
            sort=table_data.get('sort', 1)  # 读取排序号
        )
        
        # 解析字典配置
        for dict_data in table_data.get('dicts', []):
            # 解析字典数据项
            data_items = []
            for i, d in enumerate(dict_data.get('data', []), 1):
                data_items.append(DictDataItem(
                    label=d.get('label', ''),
                    value=str(d.get('value', '')),
                    sort=d.get('sort', i),
                    is_default=d.get('is_default', 'N'),
                    list_class=d.get('list_class', ''),
                    status=d.get('status', '0')
                ))
            
            table.dicts.append(DictItem(
                dict_type=dict_data.get('dict_type', ''),
                dict_name=dict_data.get('dict_name', ''),
                sort=dict_data.get('sort', 1),
                data=data_items
            ))
        
        # 解析字段配置
        for col_data in table_data.get('columns', []):
            # 支持 is_query 和 query 两种写法
            is_query = col_data.get('is_query', col_data.get('query', False))
            
            # BaseEntity字段识别（树表模式下还包含TreeEntity字段）
            is_super = col_data['name'] in self.BASE_ENTITY_COLUMNS
            if table.tpl_type == 'tree' and col_data['name'] in self.TREE_ENTITY_COLUMNS:
                is_super = True
            
            column = Column(
                name=col_data['name'],
                comment=col_data.get('comment', ''),
                type=col_data.get('type', 'varchar'),
                length=col_data.get('length'),
                precision=col_data.get('precision'),
                scale=col_data.get('scale'),
                is_nullable=col_data.get('is_nullable', True),
                default=col_data.get('default'),
                is_pk=col_data.get('is_pk', False),
                is_auto_increment=col_data.get('is_auto_increment', False),

                # BaseEntity/TreeEntity字段识别
                is_super_column=is_super,

                # Java类型（可覆盖自动推断）
                java_type=col_data.get('java_type'),

                # 查询配置（支持 is_query 和 query）
                query=is_query,
                query_type=col_data.get('query_type', 'EQ'),

                # 表单配置
                is_insert=col_data.get('is_insert', True),
                is_edit=col_data.get('is_edit', True),
                is_list=col_data.get('is_list', True),
                is_required=col_data.get('is_required', False),

                # 组件配置
                component=col_data.get('component', 'Input'),
                dict_type=col_data.get('dict_type'),
                date_format=col_data.get('date_format') if col_data.get('date_format') else None,
                # MVP3: 上传组件和编辑器配置
                limit=col_data.get('limit'),
                file_size=col_data.get('file_size'),
                file_type=col_data.get('file_type'),
                height=col_data.get('height')
            )
            table.columns.append(column)
        
        return table
    
    def _to_class_name(self, table_name: str) -> str:
        """将表名转换为类名"""
        # 移除前缀，如 sys_, t_, 
        prefixes = ['sys_', 't_', 'tb_', 'table_']
        name = table_name
        for prefix in prefixes:
            if name.startswith(prefix):
                name = name[len(prefix):]
                break
        
        # 下划线转驼峰
        parts = name.split('_')
        return ''.join(p.capitalize() for p in parts if p)
    
    def _to_business_name(self, table_name: str) -> str:
        """从表名生成唯一的 business 名称
        
        避免使用 info/manage/detail 等通用名称
        示例:
            product_info -> product_info
            mvp1_test -> mvp1_test
            sys_user -> user
        """
        # 移除前缀
        prefixes = ['sys_', 't_', 'tb_', 'table_']
        name = table_name
        for prefix in prefixes:
            if name.startswith(prefix):
                name = name[len(prefix):]
                break
        
        # 如果移除前缀后只剩一个单词，直接使用表名
        parts = name.split('_')
        if len(parts) <= 1:
            return name
        
        # 避免使用最后部分如果是通用名称
        common_names = {'info', 'manage', 'detail', 'list', 'data', 'master', 'main'}
        if parts[-1] in common_names and len(parts) > 1:
            # 使用完整表名（下划线替换为驼峰或保持原样）
            # 返回: product_info (适合 URL path)
            return '_'.join(parts)
        
        return '_'.join(parts)
    
    def generate_ddl(self, table: TableSchema) -> str:
        """生成CREATE TABLE语句（主子表模式下同时生成子表DDL）"""
        ddl = self._generate_single_ddl(table)

        # 主子表模式：追加子表DDL
        if table.tpl_type == 'sub' and table.sub_table:
            sub_ddl = self._generate_sub_ddl(table.sub_table, table.table_name)
            ddl += "\n" + sub_ddl

        return ddl

    def _generate_single_ddl(self, table: TableSchema) -> str:
        """生成单个表的DDL"""
        lines = [f"CREATE TABLE IF NOT EXISTS `{table.table_name}` ("]

        column_defs = []
        pk_columns = []

        for col in table.columns:
            # 列名和类型
            col_name = col.name
            col_type = self.TYPE_MAPPING.get(col.type, 'VARCHAR')

            # 长度
            if col.length and col_type in ['VARCHAR', 'CHAR']:
                col_type += f"({col.length})"
            elif col.precision is not None and col.scale is not None and col_type == 'DECIMAL':
                col_type += f"({col.precision},{col.scale})"

            # 是否可空（主键必须是NOT NULL）
            if col.is_pk:
                nullable = "NOT NULL"
            else:
                nullable = "NULL" if col.is_nullable else "NOT NULL"

            # 默认值
            default = ""
            if col.default is not None:
                if isinstance(col.default, str):
                    default = f" DEFAULT '{col.default}'"
                else:
                    default = f" DEFAULT {col.default}"

            # 自增
            auto_inc = " AUTO_INCREMENT" if col.is_auto_increment else ""

            # 注释
            comment = f" COMMENT '{col.comment}'"

            column_defs.append(f"  `{col_name}` {col_type} {nullable}{default}{auto_inc}{comment}")

            # 记录主键
            if col.is_pk:
                pk_columns.append(col_name)

        # 所有字段定义后加逗号
        column_defs = [c + "," for c in column_defs]
        lines.extend(column_defs)

        # 主键
        if pk_columns:
            pk_line = f"  PRIMARY KEY ({', '.join([f'`{c}`' for c in pk_columns])})"
            lines.append(pk_line)

        # 移除最后一个逗号
        if lines and lines[-1].endswith(','):
            lines[-1] = lines[-1][:-1]

        lines.append(f") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='{table.table_comment}';\n")

        main_ddl = '\n'.join(lines)
        
        # 主子表: 追加子表DDL
        if table.tpl_type == 'sub' and table.sub_table:
            sub = table.sub_table
            sub_lines = [f"CREATE TABLE IF NOT EXISTS `{sub.table_name}` ("]
            sub_col_defs = []
            sub_pks = []
            for col in sub.columns:
                col_type = self.TYPE_MAPPING.get(col.type, 'VARCHAR')
                if col.length and col_type in ['VARCHAR', 'CHAR']:
                    col_type += f"({col.length})"
                elif col.precision is not None and col.scale is not None and col_type == 'DECIMAL':
                    col_type += f"({col.precision},{col.scale})"
                nullable = "NOT NULL" if col.is_pk else ("NULL" if col.is_nullable else "NOT NULL")
                default = ""
                if col.default is not None:
                    default = f" DEFAULT '{col.default}'" if isinstance(col.default, str) else f" DEFAULT {col.default}"
                auto_inc = " AUTO_INCREMENT" if col.is_auto_increment else ""
                comment = f" COMMENT '{col.comment}'"
                sub_col_defs.append(f"  `{col.name}` {col_type} {nullable}{default}{auto_inc}{comment}")
                if col.is_pk:
                    sub_pks.append(col.name)
            sub_col_defs = [c + "," for c in sub_col_defs]
            sub_lines.extend(sub_col_defs)
            if sub_pks:
                sub_lines.append(f"  PRIMARY KEY ({', '.join([f'`{c}`' for c in sub_pks])}),")
            # 外键索引
            if sub.fk_column:
                sub_lines.append(f"  KEY `idx_{sub.fk_column}` (`{sub.fk_column}`)")
            if sub_lines[-1].endswith(','):
                sub_lines[-1] = sub_lines[-1][:-1]
            sub_lines.append(f") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='{sub.table_comment}';\n")
            main_ddl += '\n\n' + '\n'.join(sub_lines)
        
        return main_ddl

    def _generate_sub_ddl(self, sub_table: SubTableConfig, main_table_name: str) -> str:
        """生成子表DDL"""
        lines = [f"CREATE TABLE IF NOT EXISTS `{sub_table.table_name}` ("]

        column_defs = []
        pk_columns = []
        fk_column = sub_table.fk_column

        for col in sub_table.columns:
            # 列名和类型
            col_name = col.name
            col_type = self.TYPE_MAPPING.get(col.type, 'VARCHAR')

            # 长度
            if col.length and col_type in ['VARCHAR', 'CHAR']:
                col_type += f"({col.length})"
            elif col.precision is not None and col.scale is not None and col_type == 'DECIMAL':
                col_type += f"({col.precision},{col.scale})"

            # 是否可空（主键必须是NOT NULL，外键也NOT NULL）
            if col.is_pk or col.name == fk_column:
                nullable = "NOT NULL"
            else:
                nullable = "NULL" if col.is_nullable else "NOT NULL"

            # 默认值
            default = ""
            if col.default is not None:
                if isinstance(col.default, str):
                    default = f" DEFAULT '{col.default}'"
                else:
                    default = f" DEFAULT {col.default}"

            # 自增
            auto_inc = " AUTO_INCREMENT" if col.is_auto_increment else ""

            # 注释
            comment = f" COMMENT '{col.comment}'"

            column_defs.append(f"  `{col_name}` {col_type} {nullable}{default}{auto_inc}{comment}")

            # 记录主键
            if col.is_pk:
                pk_columns.append(col_name)

        # 所有字段定义后加逗号
        column_defs = [c + "," for c in column_defs]
        lines.extend(column_defs)

        # 主键
        if pk_columns:
            pk_line = f"  PRIMARY KEY ({', '.join([f'`{c}`' for c in pk_columns])}),"
            lines.append(pk_line)

        # 外键索引
        if fk_column:
            idx_name = f"idx_{sub_table.table_name}_{fk_column}"
            idx_line = f"  KEY `{idx_name}` (`{fk_column}`)"
            lines.append(idx_line)

        # 移除最后一个逗号
        if lines and lines[-1].endswith(','):
            lines[-1] = lines[-1][:-1]

        lines.append(f") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='{sub_table.table_comment}';\n")

        return '\n'.join(lines)
    
    def generate_field_info(self, table: TableSchema) -> Dict[str, Any]:
        """生成字段信息摘要（用于调试/展示）"""
        return {
            'table_name': table.table_name,
            'function_name': table.gen_config.function_name,
            'tpl_web_type': table.gen_config.tpl_web_type,
            'dicts': [
                {'dict_type': d.dict_type, 'dict_name': d.dict_name, 'sort': d.sort}
                for d in table.dicts
            ],
            'columns': [
                {
                    'name': c.name,
                    'component': c.component,
                    'query': c.query,
                    'query_type': c.query_type if c.query else None,
                    'dict_type': c.dict_type,
                    'is_list': c.is_list,
                    'is_edit': c.is_edit
                }
                for c in table.columns
            ]
        }
    
    def generate_all_ddl(self, yaml_path: str) -> Dict[str, str]:
        """生成所有表的DDL"""
        tables = self.parse_yaml(yaml_path)
        ddls = {}
        for table in tables:
            ddls[table.table_name] = self.generate_ddl(table)
        return ddls

    def generate_config(self, table: TableSchema) -> str:
        """根据表结构生成完整配置文件（带默认值）
        
        Args:
            table: 表结构定义
            
        Returns:
            YAML格式的配置字符串
        """
        lines = []
        lines.append(f"table_name: {table.table_name}")
        lines.append(f"table_comment: {table.table_comment}")
        lines.append(f"module: {table.module}")
        # 智能生成 business 名称，避免使用通用名称如 info
        lines.append(f"business: {table.business}  # ⚠️ 建议修改为唯一的业务名，如: {table.table_name.replace('_', '')}")
        lines.append(f"function_name: {table.gen_config.function_name}")
        lines.append(f"sort: 1  # 菜单排序号")

        # 树表/主子表配置输出
        if table.tpl_type != "crud":
            lines.append(f"tpl_type: {table.tpl_type}")
        if table.tree_config:
            lines.append("tree_config:")
            lines.append(f"  tree_code: {table.tree_config.tree_code}")
            lines.append(f"  tree_parent_code: {table.tree_config.tree_parent_code}")
            lines.append(f"  tree_name: {table.tree_config.tree_name}")

        # 主子表配置输出
        if table.sub_table:
            lines.append("sub_table:")
            lines.append(f"  table_name: {table.sub_table.table_name}")
            lines.append(f"  table_comment: {table.sub_table.table_comment}")
            lines.append(f"  fk_column: {table.sub_table.fk_column}")
            lines.append("  columns:")
            for col in table.sub_table.columns:
                lines.append(f"    - name: {col.name}")
                lines.append(f"      comment: {col.comment}")
                lines.append(f"      type: {col.type}")
                if col.length:
                    lines.append(f"      length: {col.length}")
                if col.precision is not None:
                    lines.append(f"      precision: {col.precision}")
                if col.scale is not None:
                    lines.append(f"      scale: {col.scale}")
                if col.is_pk:
                    lines.append(f"      is_pk: true")
                if col.is_auto_increment:
                    lines.append(f"      is_auto_increment: true")
                if not col.is_nullable:
                    lines.append(f"      is_nullable: false")
                if col.default is not None:
                    if isinstance(col.default, str):
                        lines.append(f"      default: '{col.default}'")
                    else:
                        lines.append(f"      default: {col.default}")
                # 主子表：子表字段简化输出（默认使用Input/InputNumber/DatePicker）
                java_type = col.java_type if col.java_type else self.MYSQL_TO_JAVA.get(col.type, 'String')
                component = col.component if col.component else self.COMPONENT_MAPPING.get(col.type, 'Input')
                lines.append(f"      java_type: {java_type}")
                lines.append(f"      component: {component}")
                if col.dict_type:
                    lines.append(f"      dict_type: {col.dict_type}")
                if col.date_format:
                    lines.append(f"      date_format: {col.date_format}")
                lines.append("")

        lines.append("")
        lines.append("columns:")
        
        for col in table.columns:
            lines.append(f"  - name: {col.name}")
            lines.append(f"    comment: {col.comment}")
            lines.append(f"    type: {col.type}")
            
            if col.length:
                lines.append(f"    length: {col.length}")
            if col.precision is not None:
                lines.append(f"    precision: {col.precision}")
            if col.scale is not None:
                lines.append(f"    scale: {col.scale}")
            
            # 基础属性
            if col.is_pk:
                lines.append(f"    is_pk: true")
            if col.is_auto_increment:
                lines.append(f"    is_auto_increment: true")
            if not col.is_nullable:
                lines.append(f"    is_nullable: false")
            if col.default is not None:
                if isinstance(col.default, str):
                    lines.append(f"    default: '{col.default}'")
                else:
                    lines.append(f"    default: {col.default}")
            
            # 推断默认值（带注释说明）
            # 优先使用用户已设置的值，未设置时才推断
            is_insert = col.is_insert if col.is_insert is not None else True
            is_edit = col.is_edit if col.is_edit is not None else not col.is_pk
            is_list = col.is_list if col.is_list is not None else (col.type not in ['text', 'longtext', 'blob'])
            
            # MVP2: 数字类型默认开启查询并使用 BETWEEN
            numeric_types = ['int', 'bigint', 'decimal', 'float', 'double', 'tinyint']
            if col.type in numeric_types:
                is_query_default = True
                query_type_default = 'BETWEEN'  # 数字类型使用范围查询
            elif col.type in ['varchar', 'char']:
                is_query_default = True
                query_type_default = 'LIKE'
            else:
                is_query_default = False
                query_type_default = 'EQ'
            
            is_query = col.query if col.query is not None else is_query_default
            query_type = col.query_type if col.query_type is not None else query_type_default
            
            is_required = col.is_required if col.is_required is not None else (not col.is_nullable and col.default is None and not col.is_pk)
            
            # 优先使用用户配置的java_type，否则根据类型推断
            java_type = col.java_type if col.java_type is not None else self.MYSQL_TO_JAVA.get(col.type, 'String')
            component = col.component if col.component is not None else self.COMPONENT_MAPPING.get(col.type, 'Input')
            date_format = col.date_format if col.date_format else self.DATE_FORMAT_MAPPING.get(col.type)
            
            lines.append(f"    is_insert: {str(is_insert).lower()}  # 是否插入字段")
            lines.append(f"    is_edit: {str(is_edit).lower()}  # 是否编辑字段")
            lines.append(f"    is_list: {str(is_list).lower()}  # 是否列表显示")
            lines.append(f"    is_query: {str(is_query).lower()}  # 是否查询条件")
            lines.append(f"    is_required: {str(is_required).lower()}  # 是否必填")
            lines.append(f"    query_type: {query_type}  # 查询方式: EQ/NE/GT/GE/LT/LE/LIKE/BETWEEN")
            lines.append(f"    java_type: {java_type}  # Java类型")
            lines.append(f"    component: {component}  # 组件类型")
            
            # MVP3: 输出 dict_type
            if col.dict_type:
                lines.append(f"    dict_type: {col.dict_type}  # 字典类型")
            
            if date_format:
                # 保持 Day.js 格式 (YYYY-MM-DD HH:mm:ss)
                lines.append(f"    date_format: {date_format}  # 日期格式")
            
            # MVP3: 上传组件和编辑器配置
            if col.component in ['ImageUpload', 'FileUpload']:
                if col.limit:
                    lines.append(f"    limit: {col.limit}  # 数量限制")
                if col.file_size:
                    lines.append(f"    file_size: {col.file_size}  # 大小限制(MB)")
                if col.file_type:
                    lines.append(f"    file_type: {col.file_type}  # 文件类型")
            if col.component == 'Editor' and col.height:
                lines.append(f"    height: {col.height}  # 编辑器高度")
            
            lines.append("")
        
        # 添加字典配置
        if table.dicts:
            lines.append("dicts:")
            for dict_item in table.dicts:
                lines.append(f"  - dict_type: {dict_item.dict_type}")
                lines.append(f"    dict_name: {dict_item.dict_name}")
                lines.append(f"    sort: {dict_item.sort}")
                if dict_item.data:
                    lines.append("    data:")
                    for d in dict_item.data:
                        lines.append(f"      - label: {d.label}")
                        lines.append(f"        value: '{d.value}'")
                        lines.append(f"        sort: {d.sort}")
                        lines.append(f"        is_default: {d.is_default}")
                        if d.list_class:
                            lines.append(f"        list_class: {d.list_class}")
                lines.append("")
        
        return '\n'.join(lines)
    
    def generate_config_from_db(self, table_name: str, db_reader) -> str:
        """从数据库表结构生成配置文件
        
        Args:
            table_name: 数据库表名
            db_reader: 数据库读取器实例
            
        Returns:
            YAML格式的配置字符串
        """
        from .db_reader import TableInfo
        
        with db_reader:
            table_info = db_reader.get_table_info(table_name)
        
        # 转换为 TableSchema
        table = TableSchema()
        table.table_name = table_info.table_name
        table.table_comment = table_info.table_comment
        table.module = table_info.module_name or 'system'
        table.business = table_info.business_name or 'info'
        table.gen_config.function_name = table_info.function_name or table_info.table_comment
        
        for col_info in table_info.columns:
            col = Column(
                name=col_info.column_name,
                comment=col_info.column_comment,
                type=col_info.data_type,
                length=col_info.character_maximum_length,
                precision=col_info.numeric_precision,
                scale=col_info.numeric_scale,
                is_nullable=col_info.is_nullable == 'YES',
                default=col_info.column_default,
                is_pk=col_info.is_pk,
                is_auto_increment=col_info.is_increment
            )
            table.columns.append(col)
        
        return self.generate_config(table)
    
    def generate_dict_configs(self, table: TableSchema) -> List[Dict[str, Any]]:
        """生成字典配置列表（用于 DictManager）
        
        Args:
            table: 表结构定义
            
        Returns:
            字典配置列表
        """
        dict_configs = []
        for dict_item in table.dicts:
            dict_data = {
                'dict_type': dict_item.dict_type,
                'dict_name': dict_item.dict_name,
                'source_table': table.table_name,
                'data': [
                    {
                        'label': d.label,
                        'value': d.value,
                        'sort': d.sort,
                        'is_default': d.is_default,
                        'list_class': d.list_class,
                        'status': d.status
                    }
                    for d in dict_item.data
                ]
            }
            dict_configs.append(dict_data)
        return dict_configs


if __name__ == '__main__':
    parser = SchemaParser()
    
    # 测试
    if __import__('os').path.exists('TEMPLATE.yaml'):
        tables = parser.parse_yaml('TEMPLATE.yaml')
        print(f"解析到 {len(tables)} 个表")
        
        for table in tables:
            print(f"\n{'='*60}")
            print(f"表: {table.table_name}")
            print(f"功能名: {table.gen_config.function_name}")
            print(f"模板类型: {table.gen_config.tpl_web_type}")
            print(f"字典: {[(d.dict_type, d.sort) for d in table.dicts]}")
            print(f"\nDDL:")
            ddl = parser.generate_ddl(table)
            print(ddl[:800] + "..." if len(ddl) > 800 else ddl)
            
            print(f"\n字段配置:")
            for col in table.columns:
                print(f"  - {col.name}: component={col.component}, query={col.query}, dict={col.dict_type}")
